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
import { allowConnection, releaseConnection } from './rateLimit.js';
import logger from './logger.js';

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
    const ip = socket.handshake.address;
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

      const room = store.get(roomId);
      if (!room) {
        socket.emit(ERROR_OCCURRED, errorEnvelope(
          ERROR_CODES.STATE_ROOM_NOT_FOUND,
          'Room not found.',
        ));
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

      const room = store.get(roomId);
      if (!room) {
        socket.emit(ERROR_OCCURRED, errorEnvelope(
          ERROR_CODES.STATE_ROOM_NOT_FOUND,
          'Room not found.',
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

    // ── toContinue (resume) ──────────────────────────────────────
    socket.on(RESUME, (payload) => {
      const validation = validateRoomAction(payload);
      if (!validation.ok) {
        socket.emit(ERROR_OCCURRED, errorEnvelope(validation.code, validation.message));
        return;
      }
      const { roomId } = validation.data;

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
      // reflects the resumed timer in a single update.
      if (room.isPaused && store.isCurrentTurnPlayer(roomCode, playerId)) {
        timerEngine.resume(io, store, roomCode);
      }

      const wire = RoomStore.serialize(store.get(roomCode));
      socket.emit(JOIN_ROOM_SUCCESS, wire);
      io.to(roomCode).emit(UPDATE_ROOM, wire);

      logger.info({ roomCode, playerId }, 'player rejoined');
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
