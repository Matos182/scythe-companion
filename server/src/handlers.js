// SPDX-License-Identifier: MIT

/**
 * Socket event handlers for the Scythe companion server.
 *
 * Ports createRoom / joinRoom / startGame from the old `index.js` but
 * uses the in-memory RoomStore (D2) instead of MongoDB.  Timer/turn/
 * pause/resume handlers are wired to the timerEngine (T2.2).
 * Presence/rejoin handlers wired in T2.3.
 *
 * T2.4 hardening: every event validates its payload via validation.js,
 * errors are sent as structured envelopes `{ code, message }`, rate
 * limiting is enforced at connection time, and structured logging
 * replaces console.log.
 *
 * T4.7c authorization: start/turn/pause/resume require the sender
 * to be seated in the room they target (socket.data.roomCode), and
 * `turn` additionally requires turn ownership (STATE_NOT_YOUR_TURN).
 * startGame and removePlayer are also creator-only (AUTH_NOT_CREATOR).
 */

import { RoomStore } from './roomStore.js';
import * as timerEngine from './timerEngine.js';
import {
  CREATE_ROOM,
  JOIN_ROOM,
  START_GAME,
  TURN,
  PAUSE,
  RESUME,
  REJOIN_ROOM,
  REMOVE_PLAYER,
  COMBAT,
  CREATE_ROOM_SUCCESS,
  JOIN_ROOM_SUCCESS,
  UPDATE_ROOM,
  NEW_TURN,
  ERROR_OCCURRED,
} from './protocol.js';
import { ERROR_CODES, errorEnvelope } from './errors.js';
import {
  validateCreateRoom,
  validateJoinRoom,
  validateRoomAction,
  validateRejoinRoom,
} from './validation.js';
import { allowConnection, releaseConnection, clientIp } from './rateLimit.js';
import logger from './logger.js';

/**
 * T4.7c — Room-action authorization (DECISIONS R2).
 *
 * The server stamps `socket.data.roomCode`/`playerId` at create/join/
 * rejoin; the payload's `roomId` is only a claim.  A socket may act
 * only on the room it is seated in — anything else gets
 * AUTH_NOT_IN_ROOM and a warn log.  The check runs BEFORE the room
 * lookup on purpose: a stranger probing guessed codes must not learn
 * which codes exist (the response is identical either way).
 *
 * @param {import('socket.io').Socket} socket
 * @param {string} roomId — roomId claimed by the client payload
 * @returns {boolean} true when the socket is seated in roomId
 */
function requireRoomMembership(socket, roomId) {
  if (socket.data.roomCode === roomId) return true;
  logger.warn({
    socketId: socket.id,
    roomId,
    seatedRoom: socket.data.roomCode ?? null,
  }, 'room action rejected: sender not seated in room');
  socket.emit(ERROR_OCCURRED, errorEnvelope(
    ERROR_CODES.AUTH_NOT_IN_ROOM,
    'You are not a player in that room.',
  ));
  return false;
}

/**
 * Creator-only actions (startGame, removePlayer). Trusts
 * socket.data.playerId stamped at create/join/rejoin, not a client claim.
 *
 * @param {import('socket.io').Socket} socket
 * @param {{ _id: string, creator: { _id: string } }} room
 * @param {string} message — human-readable AUTH_NOT_CREATOR text
 * @returns {boolean} true when the socket is the room creator
 */
function requireCreator(socket, room, message) {
  if (room.creator._id === socket.data.playerId) return true;
  logger.warn({
    socketId: socket.id,
    roomId: room._id,
    playerId: socket.data.playerId,
  }, 'action rejected: sender is not the room creator');
  socket.emit(ERROR_OCCURRED, errorEnvelope(
    ERROR_CODES.AUTH_NOT_CREATOR,
    message,
  ));
  return false;
}

/**
 * Register all socket handlers on an io instance.
 *
 * @param {import('socket.io').Server} io
 * @param {RoomStore} store
 * @param {{maxRooms?: number}} [options]
 */
export function registerHandlers(io, store, options = {}) {
  const maxRooms = options.maxRooms ?? Number(process.env.MAX_ROOMS ?? 100);

  // ── Connection-rate middleware (per-IP token bucket + concurrent cap) ──
  io.use((socket, next) => {
    const ip = clientIp(socket);
    const result = allowConnection(ip);
    if (!result.allowed) {
      // Reject the connection — the client gets a connect_error.
      next(new Error(result.envelope.message));
      return;
    }
    // Track the IP on the socket so we can release on disconnect.
    socket.data._ip = ip;
    next();
  });

  io.on('connection', (socket) => {
    logger.info({ socketId: socket.id, ip: socket.data._ip }, 'client connected');

    // ── createRoom ───────────────────────────────────────────────
    socket.on(CREATE_ROOM, (payload) => {
      const validation = validateCreateRoom(payload);
      if (!validation.ok) {
        socket.emit(ERROR_OCCURRED, errorEnvelope(validation.code, validation.message));
        return;
      }
      const { nickname, playerfaction, playermat, timer } = validation.data;

      // Server-level room cap (prevents room-spam).
      if (store.rooms.size >= maxRooms) {
        socket.emit(ERROR_OCCURRED, errorEnvelope(
          ERROR_CODES.SERVER_MAX_ROOMS,
          'Server is full. Please try again later.',
        ));
        return;
      }

      const { room, playerId } = store.create({
        nickname,
        playerfaction,
        playermat,
        timer,
      });

      // Write the socket ID back to the player (T2.3 — was '' in T2.1).
      store.markConnected(room._id, playerId, true, socket.id);

      socket.data.playerId = playerId;
      socket.data.roomCode = room._id;

      socket.join(room._id);
      io.to(room._id).emit(CREATE_ROOM_SUCCESS, RoomStore.serialize(room));
      logger.info({ roomCode: room._id, playerId }, 'room created');
    });

    // ── joinRoom ─────────────────────────────────────────────────
    socket.on(JOIN_ROOM, (payload) => {
      const validation = validateJoinRoom(payload);
      if (!validation.ok) {
        socket.emit(ERROR_OCCURRED, errorEnvelope(validation.code, validation.message));
        return;
      }
      const { nickname, roomId, playerfaction, playermat } = validation.data;

      const room = store.get(roomId);
      if (!room) {
        socket.emit(ERROR_OCCURRED, errorEnvelope(
          ERROR_CODES.STATE_ROOM_NOT_FOUND,
          'Room not found.',
        ));
        return;
      }

      if (!room.isJoin) {
        socket.emit(ERROR_OCCURRED, errorEnvelope(
          ERROR_CODES.STATE_GAME_IN_PROGRESS,
          'This game is in progress, try another room',
        ));
        return;
      }

      const result = store.join(roomId, { nickname, playerfaction, playermat });
      if (!result) {
        socket.emit(ERROR_OCCURRED, errorEnvelope(
          ERROR_CODES.STATE_FACTION_OR_MAT_TAKEN,
          'Player faction or player mat is already picked in this room.',
        ));
        return;
      }

      // Write the socket ID back to the player (T2.3 — was '' in T2.1).
      store.markConnected(roomId, result.playerId, true, socket.id);

      socket.data.playerId = result.playerId;
      socket.data.roomCode = roomId;

      socket.join(roomId);
      io.to(roomId).emit(UPDATE_ROOM, RoomStore.serialize(result.room));
      socket.emit(JOIN_ROOM_SUCCESS, RoomStore.serialize(result.room));
      logger.info({ roomCode: roomId, playerId: result.playerId }, 'player joined');
    });

    // ── startGame ────────────────────────────────────────────────
    socket.on(START_GAME, (payload) => {
      const validation = validateRoomAction(payload);
      if (!validation.ok) {
        socket.emit(ERROR_OCCURRED, errorEnvelope(validation.code, validation.message));
        return;
      }
      const { roomId } = validation.data;

      if (!requireRoomMembership(socket, roomId)) return;

      const room = store.get(roomId);
      if (!room) {
        socket.emit(ERROR_OCCURRED, errorEnvelope(
          ERROR_CODES.STATE_ROOM_NOT_FOUND,
          'Room not found.',
        ));
        return;
      }

      if (!requireCreator(socket, room, 'Only the room creator can start the game.')) {
        return;
      }

      if (room.players.length < 2) {
        socket.emit(ERROR_OCCURRED, errorEnvelope(
          ERROR_CODES.STATE_SINGLE_PLAYER,
          "You aren't playing with Automa!!",
        ));
        return;
      }

      const started = store.startGame(roomId);
      store.touch(roomId);
      io.to(roomId).emit(UPDATE_ROOM, RoomStore.serialize(started));

      timerEngine.start(io, store, roomId);
      logger.info({ roomCode: roomId }, 'game started');
    });

    // ── turn (pass) ──────────────────────────────────────────────
    socket.on(TURN, (payload) => {
      const validation = validateRoomAction(payload);
      if (!validation.ok) {
        socket.emit(ERROR_OCCURRED, errorEnvelope(validation.code, validation.message));
        return;
      }
      const { roomId } = validation.data;

      if (!requireRoomMembership(socket, roomId)) return;

      const room = store.get(roomId);
      if (!room) {
        socket.emit(ERROR_OCCURRED, errorEnvelope(
          ERROR_CODES.STATE_ROOM_NOT_FOUND,
          'Room not found.',
        ));
        return;
      }

      // Turn-ownership (T4.7c): only the current turn player may pass.
      // The honest client already gates the button on isMyTurn; this is
      // the authoritative check.  (DECISIONS R2 parked the "creator can
      // pass for an absent player" affordance — current-turn-only.)
      if (!store.isCurrentTurnPlayer(roomId, socket.data.playerId)) {
        socket.emit(ERROR_OCCURRED, errorEnvelope(
          ERROR_CODES.STATE_NOT_YOUR_TURN,
          "It's not your turn.",
        ));
        return;
      }

      const updated = store.passTurn(roomId);
      if (!updated) {
        socket.emit(ERROR_OCCURRED, errorEnvelope(
          ERROR_CODES.STATE_PASS_FAILED,
          'Could not pass turn.',
        ));
        return;
      }

      io.to(roomId).emit(NEW_TURN, RoomStore.serialize(updated));
      timerEngine.start(io, store, roomId);
    });

    // ── pause ────────────────────────────────────────────────────
    socket.on(PAUSE, (payload) => {
      const validation = validateRoomAction(payload);
      if (!validation.ok) {
        socket.emit(ERROR_OCCURRED, errorEnvelope(validation.code, validation.message));
        return;
      }
      const { roomId } = validation.data;

      if (!requireRoomMembership(socket, roomId)) return;

      const room = store.get(roomId);
      if (!room) {
        socket.emit(ERROR_OCCURRED, errorEnvelope(
          ERROR_CODES.STATE_ROOM_NOT_FOUND,
          'Room not found.',
        ));
        return;
      }

      timerEngine.pause(store, roomId);
      const updated = store.get(roomId);
      io.to(roomId).emit(UPDATE_ROOM, RoomStore.serialize(updated));
    });

    // ── combat (T5.7) ────────────────────────────────────────────
    //
    // Table fight: current-turn player pauses the clock with a distinct
    // reason so every client can show the combat overlay. Resume uses
    // the existing toContinue path and clears pauseReason. Additive —
    // protocolVersion stays 1.
    socket.on(COMBAT, (payload) => {
      const validation = validateRoomAction(payload);
      if (!validation.ok) {
        socket.emit(ERROR_OCCURRED, errorEnvelope(validation.code, validation.message));
        return;
      }
      const { roomId } = validation.data;

      if (!requireRoomMembership(socket, roomId)) return;

      const room = store.get(roomId);
      if (!room) {
        socket.emit(ERROR_OCCURRED, errorEnvelope(
          ERROR_CODES.STATE_ROOM_NOT_FOUND,
          'Room not found.',
        ));
        return;
      }

      if (room.isJoin) {
        socket.emit(ERROR_OCCURRED, errorEnvelope(
          ERROR_CODES.VAL_BAD_PAYLOAD,
          'The game has not started.',
        ));
        return;
      }

      if (!store.isCurrentTurnPlayer(roomId, socket.data.playerId)) {
        socket.emit(ERROR_OCCURRED, errorEnvelope(
          ERROR_CODES.STATE_NOT_YOUR_TURN,
          "It's not your turn.",
        ));
        return;
      }

      timerEngine.pause(store, roomId);
      store.setPauseReason(roomId, 'combat');
      const updated = store.get(roomId);
      io.to(roomId).emit(UPDATE_ROOM, RoomStore.serialize(updated));
    });

    // ── toContinue (resume) ──────────────────────────────────────
    socket.on(RESUME, (payload) => {
      const validation = validateRoomAction(payload);
      if (!validation.ok) {
        socket.emit(ERROR_OCCURRED, errorEnvelope(validation.code, validation.message));
        return;
      }
      const { roomId } = validation.data;

      if (!requireRoomMembership(socket, roomId)) return;

      const room = store.get(roomId);
      if (!room) {
        socket.emit(ERROR_OCCURRED, errorEnvelope(
          ERROR_CODES.STATE_ROOM_NOT_FOUND,
          'Room not found.',
        ));
        return;
      }

      timerEngine.resume(io, store, roomId);
      const updated = store.get(roomId);
      io.to(roomId).emit(UPDATE_ROOM, RoomStore.serialize(updated));
    });

    // ── rejoinRoom ──────────────────────────────────────────────
    //
    // Reconnect a previously-seated player to their room using their
    // persistent playerId (D4).  Remaps the socket ID, marks them
    // connected, and sends the full room state.  If the timer was
    // auto-paused on their disconnect and it's still their turn, the
    // timer is resumed.
    socket.on(REJOIN_ROOM, (payload) => {
      const validation = validateRejoinRoom(payload);
      if (!validation.ok) {
        socket.emit(ERROR_OCCURRED, errorEnvelope(validation.code, validation.message));
        return;
      }
      const { roomCode, playerId } = validation.data;

      const room = store.rejoin(roomCode, playerId, socket.id);
      if (!room) {
        socket.emit(ERROR_OCCURRED, errorEnvelope(
          ERROR_CODES.REJOIN_NOT_FOUND,
          'Room or player not found.',
        ));
        return;
      }

      socket.data.playerId = playerId;
      socket.data.roomCode = roomCode;

      socket.join(roomCode);

      // If the timer was auto-paused because this player disconnected
      // during their turn, resume it before broadcasting so the state
      // reflects the resumed timer in a single update. Combat pauses
      // must NOT auto-resume — a fighter who backgrounds the app
      // should not silently unpause the fight (T5.7).
      if (
        room.isPaused
        && store.isCurrentTurnPlayer(roomCode, playerId)
        && room.pauseReason !== 'combat'
      ) {
        timerEngine.resume(io, store, roomCode);
      }

      const wire = RoomStore.serialize(store.get(roomCode));
      socket.emit(JOIN_ROOM_SUCCESS, wire);
      io.to(roomCode).emit(UPDATE_ROOM, wire);

      logger.info({ roomCode, playerId }, 'player rejoined');
    });

    // ── removePlayer (T5.4 creator seat management) ─────────────
    //
    // A disconnected player strands their faction/mat seat: nobody can
    // pick it and the absent player may never return.  The creator may
    // remove a DISCONNECTED player, freeing the seat for a fresh join.
    // Removing a connected player is rejected — a bad network for a few
    // seconds must not eject someone mid-game.
    socket.on(REMOVE_PLAYER, (payload) => {
      const validation = validateRoomAction(payload);
      if (!validation.ok) {
        socket.emit(ERROR_OCCURRED, errorEnvelope(validation.code, validation.message));
        return;
      }
      const { roomId } = validation.data;
      const targetPlayerId = typeof payload?.playerId === 'string'
        ? payload.playerId.trim()
        : '';

      if (!requireRoomMembership(socket, roomId)) return;

      const room = store.get(roomId);
      if (!room) {
        socket.emit(ERROR_OCCURRED, errorEnvelope(
          ERROR_CODES.STATE_ROOM_NOT_FOUND,
          'Room not found.',
        ));
        return;
      }

      if (!requireCreator(socket, room, 'Only the room creator can remove players.')) {
        return;
      }

      if (!targetPlayerId) {
        socket.emit(ERROR_OCCURRED, errorEnvelope(
          ERROR_CODES.VAL_MISSING_FIELDS,
          'Player to remove is required.',
        ));
        return;
      }

      const target = room.players.find((p) => p._id === targetPlayerId);
      if (!target) {
        socket.emit(ERROR_OCCURRED, errorEnvelope(
          ERROR_CODES.STATE_ROOM_NOT_FOUND,
          'That player is not in the room.',
        ));
        return;
      }

      if (target.connected) {
        socket.emit(ERROR_OCCURRED, errorEnvelope(
          ERROR_CODES.STATE_PLAYER_CONNECTED,
          "That player is still connected — you can only remove players who've left.",
        ));
        return;
      }

      const wasTurnPlayer = room.turn && room.turn._id === targetPlayerId;
      const updated = store.removePlayer(roomId, targetPlayerId);
      if (!updated) {
        // Room emptied out and was dropped; nothing to broadcast.
        logger.info({ roomCode: roomId, removedPlayerId: targetPlayerId }, 'player removed; room empty');
        return;
      }

      const wire = RoomStore.serialize(updated);
      io.to(roomId).emit(UPDATE_ROOM, wire);
      if (wasTurnPlayer) {
        io.to(roomId).emit(NEW_TURN, wire);
        // Restart the clock for the new turn player.
        timerEngine.start(io, store, roomId);
      }
      logger.info({ roomCode: roomId, removedPlayerId: targetPlayerId }, 'player removed');
    });

    // ── disconnect ──────────────────────────────────────────────
    //
    // Mark the player disconnected, keep their seat (A3 fix — the old
    // server had no disconnect handler and the rejoin branch was dead
    // code).  If it was their turn, auto-pause the timer so the game
    // doesn't burn their time while they're away.  Broadcast the
    // updated presence to the room.
    socket.on('disconnect', () => {
      logger.info({ socketId: socket.id }, 'client disconnected');

      // Release the rate-limit connection slot.
      if (socket.data._ip) {
        releaseConnection(socket.data._ip);
      }

      const { playerId, roomCode } = socket.data;
      if (!playerId || !roomCode) return;

      const room = store.get(roomCode);
      if (!room) return;

      store.markConnected(roomCode, playerId, false);

      const noPlayersConnected = room.players.every((player) => !player.connected);
      if (noPlayersConnected) {
        // Stop empty rooms from auto-passing forever. A returning turn owner
        // auto-resumes in rejoinRoom; other returners resume manually.
        timerEngine.pause(store, roomCode);
      }

      // Auto-pause if it was the disconnecting player's turn.
      const wasCurrentTurn = store.isCurrentTurnPlayer(roomCode, playerId);
      if (wasCurrentTurn && !room.isPaused) {
        timerEngine.pause(store, roomCode);
      }

      // Transfer creator if the creator disconnected.
      store.transferCreator(roomCode);

      io.to(roomCode).emit(UPDATE_ROOM, RoomStore.serialize(store.get(roomCode)));
    });
  });
}

/**
 * Stop all timers (for graceful shutdown / test teardown).
 */
export function shutdownTimers() {
  timerEngine.stopAll();
}
