// SPDX-License-Identifier: MIT

/**
 * In-memory RoomStore (decision D2).
 *
 * Replaces MongoDB/Mongoose entirely.  Rooms are ephemeral (~2 h game
 * sessions); state fits in memory.  A TTL sweeper removes idle rooms.
 *
 * Room codes are 6-char from an unambiguous alphabet (D4) — readable
 * aloud at the table.  playerId is a UUID minted by the server at join,
 * stored client-side in shared_preferences, enabling rejoin in T2.3.
 *
 * The serialized room shape matches the Dart client's `Room.fromJson`
 * (flat: _id, isJoin, turnIndex, totalTurns, isPaused, players[], turn{},
 * creator{}) — this is the adapter seam (02_ARCHITECTURE).
 */

import { randomUUID } from 'node:crypto';
import { reorderPlayers } from './factionWheel.js';
import { roomTtlHours, minTurnSec } from './config.js';

/** Unambiguous alphabet for room codes (no 0/O/1/I/L). */
const ROOM_CODE_ALPHABET = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
const ROOM_CODE_LENGTH = 6;
const MAX_PLAYERS = 7;
const TTL_MS = roomTtlHours * 60 * 60 * 1000;

/**
 * @typedef {Object} Player
 * @property {string} _id          — playerId (UUID)
 * @property {string} nickname
 * @property {string} socketID     — current socket id (updated on rejoin)
 * @property {string} playerfaction
 * @property {string} playermat
 * @property {number} timer        — per-turn allowance in seconds (config, A6)
 * @property {number} remainingSec — live countdown value (A6: distinct from timer)
 * @property {boolean} connected   — presence flag (T2.3)
 */

/**
 * @typedef {Object} Room
 * @property {string} _id         — room code
 * @property {boolean} isJoin
 * @property {number} turnIndex
 * @property {number} totalTurns
 * @property {boolean} isPaused
 * @property {string|null|undefined} pauseReason — 'combat' or omitted/null
 * @property {Player[]} players
 * @property {Player} turn
 * @property {Player} creator
 * @property {number} lastActivity — Date.now() for TTL sweeper
 */

/** @returns {string} 6-char room code */
function generateRoomCode() {
  let code = '';
  for (let i = 0; i < ROOM_CODE_LENGTH; i++) {
    code += ROOM_CODE_ALPHABET[Math.floor(Math.random() * ROOM_CODE_ALPHABET.length)];
  }
  return code;
}

/** @returns {string} UUID v4 */
function generatePlayerId() {
  return randomUUID();
}

export class RoomStore {
  constructor() {
    /** @type {Map<string, Room>} */
    this.rooms = new Map();
    this._sweeperTimer = null;
  }

  /**
   * Create a new room with one player (the creator).
   * @param {{nickname:string, playerfaction:string, playermat:string, timer:number}} opts
   * @returns {{room: Room, playerId: string}}
   */
  create({ nickname, playerfaction, playermat, timer }) {
    const playerId = generatePlayerId();
    const roomCode = this._uniqueRoomCode();

    /** @type {Player} */
    const player = {
      _id: playerId,
      nickname,
      socketID: '',
      playerfaction,
      playermat,
      timer,
      remainingSec: timer,
      connected: true,
    };

    /** @type {Room} */
    const room = {
      _id: roomCode,
      isJoin: true,
      turnIndex: 0,
      totalTurns: 1,
      isPaused: false,
      players: [player],
      turn: player,
      creator: player,
      lastActivity: Date.now(),
    };

    this.rooms.set(roomCode, room);
    return { room, playerId };
  }

  /**
   * Join an existing room.  Returns the updated room + the new player's ID,
   * or null if the room doesn't exist / is full / faction-mat clash.
   *
   * @param {string} roomCode
   * @param {{nickname:string, playerfaction:string, playermat:string}} opts
   * @returns {{room: Room, playerId: string} | null}
   */
  join(roomCode, { nickname, playerfaction, playermat }) {
    const room = this.rooms.get(roomCode);
    if (!room) return null;
    if (!room.isJoin) return null;

    // Faction/mat uniqueness check (preserved from old server)
    const factionTaken = room.players.some((p) => p.playerfaction === playerfaction);
    const matTaken = room.players.some((p) => p.playermat === playermat);
    if (factionTaken || matTaken) return null;

    const playerId = generatePlayerId();
    // Inherit timer from first player (preserved from old server)
    const timer = room.players[0].timer;

    /** @type {Player} */
    const player = {
      _id: playerId,
      nickname,
      socketID: '',
      playerfaction,
      playermat,
      timer,
      remainingSec: timer,
      connected: true,
    };

    room.players.push(player);
    room.lastActivity = Date.now();

    // Auto-close at max players and run faction wheel
    if (room.players.length >= MAX_PLAYERS) {
      room.isJoin = false;
      room.players = reorderPlayers(room.players);
      room.turn = room.players[0];
      room.turnIndex = 0;
    }

    return { room, playerId };
  }

  /**
   * Start the game: close the room, run faction wheel, set first player.
   * Resets remainingSec for the first player (A6).
   * @param {string} roomCode
   * @returns {Room | null}
   */
  startGame(roomCode) {
    const room = this.rooms.get(roomCode);
    if (!room) return null;
    if (room.players.length < 2) return null;

    room.isJoin = false;
    room.players = reorderPlayers(room.players);
    room.turn = room.players[0];
    room.turnIndex = 0;
    room.isPaused = false;
    room.pauseReason = null;
    // Reset remainingSec for all players to their allowance (A6)
    for (const p of room.players) {
      p.remainingSec = p.timer;
    }
    room.lastActivity = Date.now();
    return room;
  }

  /**
   * Advance to the next player's turn.  Wraps around at the end of the
   * player list, incrementing totalTurns.  Resets the next player's
   * remainingSec to at least minTurnSec (preserves the old server's
   * "reset to 10 if < 10" rule, but as explicit config — A6).
   * @param {string} roomCode
   * @returns {Room | null}
   */
  passTurn(roomCode) {
    const room = this.rooms.get(roomCode);
    if (!room) return null;

    if (room.turnIndex < room.players.length - 1) {
      room.turnIndex++;
    } else {
      room.turnIndex = 0;
      room.totalTurns++;
    }
    room.turn = room.players[room.turnIndex];

    // Ensure the next player gets at least minTurnSec (A6).
    if (room.turn.remainingSec < minTurnSec) {
      room.turn.remainingSec = minTurnSec;
    }
    room.isPaused = false;
    room.pauseReason = null;
    room.lastActivity = Date.now();
    return room;
  }

  /**
   * Set the paused state of a room.
   * @param {string} roomCode
   * @param {boolean} paused
   * @returns {Room | null}
   */
  setPaused(roomCode, paused) {
    const room = this.rooms.get(roomCode);
    if (!room) return null;
    room.isPaused = paused;
    if (!paused) {
      room.pauseReason = null;
    }
    room.lastActivity = Date.now();
    return room;
  }

  /**
   * Tag why the room is paused. Ordinary pause/disconnect leave this null.
   * @param {string} roomCode
   * @param {string|null} reason
   * @returns {Room | null}
   */
  setPauseReason(roomCode, reason) {
    const room = this.rooms.get(roomCode);
    if (!room) return null;
    room.pauseReason = reason;
    room.lastActivity = Date.now();
    return room;
  }

  /**
   * Decrement the current player's remainingSec by 1 (called by timerEngine tick).
   * Returns the new remainingSec, or null if room/player not found.
   * @param {string} roomCode
   * @returns {number | null}
   */
  decrementTimer(roomCode) {
    const room = this.rooms.get(roomCode);
    if (!room || !room.turn) return null;
    room.turn.remainingSec--;
    return room.turn.remainingSec;
  }

  /**
   * Get a room by code (without mutating lastActivity).
   * @param {string} roomCode
   * @returns {Room | undefined}
   */
  get(roomCode) {
    return this.rooms.get(roomCode);
  }

  /**
   * Update a room's lastActivity timestamp (call on any player action).
   * @param {string} roomCode
   */
  touch(roomCode) {
    const room = this.rooms.get(roomCode);
    if (room) room.lastActivity = Date.now();
  }

  /**
   * Remove a room from the store.
   * @param {string} roomCode
   */
  delete(roomCode) {
    this.rooms.delete(roomCode);
  }

  /**
   * Find a room by playerId (used by rejoin in T2.3).
   * @param {string} playerId
   * @returns {Room | undefined}
   */
  findByPlayerId(playerId) {
    for (const room of this.rooms.values()) {
      if (room.players.some((p) => p._id === playerId)) {
        return room;
      }
    }
    return undefined;
  }

  /**
   * Find a player in a room by playerId.
   * @param {string} roomCode
   * @param {string} playerId
   * @returns {Player | undefined}
   */
  findPlayer(roomCode, playerId) {
    const room = this.rooms.get(roomCode);
    if (!room) return undefined;
    return room.players.find((p) => p._id === playerId);
  }

  /**
   * Mark a player's presence (connected/disconnected).  Returns the
   * player or undefined if room/player not found.
   * @param {string} roomCode
   * @param {string} playerId
   * @param {boolean} connected
   * @param {string} [socketID] — new socket id (set on reconnect)
   * @returns {Player | undefined}
   */
  markConnected(roomCode, playerId, connected, socketID) {
    const player = this.findPlayer(roomCode, playerId);
    if (!player) return undefined;
    player.connected = connected;
    if (socketID !== undefined) {
      player.socketID = socketID;
    }
    this.touch(roomCode);
    return player;
  }

  /**
   * Rejoin a player to a room: remap socketID, mark connected.
   * Returns the room or null if room/player not found.
   * @param {string} roomCode
   * @param {string} playerId
   * @param {string} socketID
   * @returns {Room | null}
   */
  rejoin(roomCode, playerId, socketID) {
    const room = this.rooms.get(roomCode);
    if (!room) return null;
    const player = room.players.find((p) => p._id === playerId);
    if (!player) return null;
    player.socketID = socketID;
    player.connected = true;
    room.lastActivity = Date.now();
    return room;
  }

  /**
   * Remove a player from a room (T5.4 creator seat management).
   *
   * Frees the removed player's faction/mat seat so a fresh join can take
   * it. Only the handler decides WHO may remove; this method only
   * validates that the target exists.
   *
   * When the removed player was the current turn player, the turn
   * advances to the next player (wrapping, same rule as passTurn) and
   * their allowance is topped up to minTurnSec. The caller restarts the
   * timer engine either way.
   *
   * When the removed player sat *before* the current turn, turnIndex
   * is decremented so it still names the same player after the splice.
   * passTurn() reads turnIndex, not turn._id — leaving it stale skips
   * a player.
   *
   * @param {string} roomCode
   * @param {string} playerId — player to remove
   * @returns {Room | null} updated room, or null when room/player missing
   */
  removePlayer(roomCode, playerId) {
    const room = this.rooms.get(roomCode);
    if (!room) return null;
    const index = room.players.findIndex((p) => p._id === playerId);
    if (index === -1) return null;

    const removedHadTurn = room.turn && room.turn._id === playerId;
    room.players.splice(index, 1);

    if (room.players.length === 0) {
      // Nobody left — drop the room entirely.
      this.rooms.delete(roomCode);
      return null;
    }

    if (removedHadTurn) {
      // Removed player had the turn: move it to the next remaining
      // player (same position wraps to 0). passTurn() would walk from
      // the OLD index, so set the turn explicitly here.
      if (room.turnIndex >= room.players.length) {
        room.turnIndex = 0;
        room.totalTurns++;
      }
      room.turn = room.players[room.turnIndex];
      if (room.turn.remainingSec < minTurnSec) {
        room.turn.remainingSec = minTurnSec;
      }
    } else if (index < room.turnIndex) {
      room.turnIndex -= 1;
      room.turn = room.players[room.turnIndex];
    }

    room.lastActivity = Date.now();
    return room;
  }

  /**
   * Is the given player the current turn player?
   * @param {string} roomCode
   * @param {string} playerId
   * @returns {boolean}
   */
  isCurrentTurnPlayer(roomCode, playerId) {
    const room = this.rooms.get(roomCode);
    if (!room || !room.turn) return false;
    return room.turn._id === playerId;
  }

  /**
   * Transfer creator to the first connected player if the current
   * creator is disconnected.  Returns the new creator or the existing
   * one if no transfer was needed.
   * @param {string} roomCode
   * @returns {Player | undefined}
   */
  transferCreator(roomCode) {
    const room = this.rooms.get(roomCode);
    if (!room) return undefined;
    if (room.creator.connected) return room.creator;
    const next = room.players.find((p) => p.connected);
    if (next) {
      room.creator = next;
      room.lastActivity = Date.now();
    }
    return room.creator;
  }

  /**
   * Serialize a room for the wire (matches Dart client's Room.fromJson).
   * Strips internal fields (lastActivity).  Includes `connected` for
   * presence badges (T2.3).
   * @param {Room} room
   * @returns {object}
   */
  static serialize(room) {
    const wire = {
      _id: room._id,
      isJoin: room.isJoin,
      turnIndex: room.turnIndex,
      totalTurns: room.totalTurns,
      isPaused: room.isPaused,
      players: room.players.map((p) => ({
        _id: p._id,
        nickname: p.nickname,
        socketID: p.socketID,
        playerfaction: p.playerfaction,
        playermat: p.playermat,
        timer: p.timer,
        remainingSec: p.remainingSec,
        connected: p.connected,
      })),
      turn: room.turn ? {
        _id: room.turn._id,
        nickname: room.turn.nickname,
        socketID: room.turn.socketID,
        playerfaction: room.turn.playerfaction,
        playermat: room.turn.playermat,
        timer: room.turn.timer,
        remainingSec: room.turn.remainingSec,
        connected: room.turn.connected,
      } : null,
      creator: room.creator ? {
        _id: room.creator._id,
        nickname: room.creator.nickname,
        socketID: room.creator.socketID,
        playerfaction: room.creator.playerfaction,
        playermat: room.creator.playermat,
        timer: room.creator.timer,
        remainingSec: room.creator.remainingSec,
        connected: room.creator.connected,
      } : null,
    };
    // Additive (T5.7): omit when null so mixed APKs see the old shape.
    if (room.pauseReason) {
      wire.pauseReason = room.pauseReason;
    }
    return wire;
  }

  /** Generate a room code that doesn't collide with existing rooms. */
  _uniqueRoomCode() {
    let code;
    let attempts = 0;
    do {
      code = generateRoomCode();
      attempts++;
    } while (this.rooms.has(code) && attempts < 100);
    return code;
  }

  /**
   * Start the TTL sweeper — removes rooms idle > roomTtlHours.
   * Call once at server boot.  Runs every 5 minutes.
   */
  startSweeper() {
    if (this._sweeperTimer) return;
    this._sweeperTimer = setInterval(() => {
      const now = Date.now();
      for (const [code, room] of this.rooms) {
        if (now - room.lastActivity > TTL_MS) {
          this.rooms.delete(code);
        }
      }
    }, 5 * 60 * 1000);
  }

  /** Stop the sweeper (for tests / graceful shutdown). */
  stopSweeper() {
    if (this._sweeperTimer) {
      clearInterval(this._sweeperTimer);
      this._sweeperTimer = null;
    }
  }
}
