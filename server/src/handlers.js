// SPDX-License-Identifier: MIT

/**
 * Socket event handlers for the Scythe companion server.
 *
 * Ports createRoom / joinRoom / startGame from the old `index.js` but
 * uses the in-memory RoomStore (D2) instead of MongoDB.  Timer/turn/
 * pause/resume handlers are wired to the timerEngine (T2.2).
 *
 * Every handler validates input, emits the appropriate wire event
 * (see src/protocol.js), and keeps the old event-name vocabulary so
 * the existing Flutter client keeps working.
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
  CREATE_ROOM_SUCCESS,
  JOIN_ROOM_SUCCESS,
  UPDATE_ROOM,
  NEW_TURN,
  ERROR_OCCURRED,
} from './protocol.js';

/**
 * Register all socket handlers on an io instance.
 *
 * @param {import('socket.io').Server} io
 * @param {RoomStore} store
 */
export function registerHandlers(io, store) {
  io.on('connection', (socket) => {
    console.log(`[server] client connected: ${socket.id}`);

    // ── createRoom ───────────────────────────────────────────────
    socket.on(CREATE_ROOM, ({ nickname, playerfaction, playermat, timer }) => {
      if (!nickname) {
        socket.emit(ERROR_OCCURRED, 'Please enter a valid nickname!');
        return;
      }

      const { room, playerId } = store.create({
        nickname,
        playerfaction,
        playermat,
        timer,
      });

      // Store playerId → socketId mapping for this connection
      socket.data.playerId = playerId;
      socket.data.roomCode = room._id;

      socket.join(room._id);
      io.to(room._id).emit(CREATE_ROOM_SUCCESS, RoomStore.serialize(room));
    });

    // ── joinRoom ─────────────────────────────────────────────────
    socket.on(JOIN_ROOM, ({ nickname, roomId, playerfaction, playermat }) => {
      if (!roomId) {
        socket.emit(ERROR_OCCURRED, 'Please enter a valid Room ID.');
        return;
      }

      const room = store.get(roomId);
      if (!room) {
        socket.emit(ERROR_OCCURRED, 'Room not found.');
        return;
      }

      if (!room.isJoin) {
        socket.emit(ERROR_OCCURRED, 'This game is in progress, try another room');
        return;
      }

      if (!nickname) {
        socket.emit(ERROR_OCCURRED, 'Please enter a valid nickname!');
        return;
      }

      const result = store.join(roomId, { nickname, playerfaction, playermat });
      if (!result) {
        socket.emit(ERROR_OCCURRED, 'Player faction or player mat is already picked in this room.');
        return;
      }

      socket.data.playerId = result.playerId;
      socket.data.roomCode = roomId;

      socket.join(roomId);
      io.to(roomId).emit(UPDATE_ROOM, RoomStore.serialize(result.room));
      socket.emit(JOIN_ROOM_SUCCESS, RoomStore.serialize(result.room));
    });

    // ── startGame ────────────────────────────────────────────────
    socket.on(START_GAME, ({ roomId }) => {
      const room = store.get(roomId);
      if (!room) {
        socket.emit(ERROR_OCCURRED, 'Room not found.');
        return;
      }

      if (room.players.length < 2) {
        socket.emit(ERROR_OCCURRED, "You aren't playing with Automa!!");
        return;
      }

      // Use the return value — startGame mutates in place but returns the
      // same room reference, so this is both safe and explicit (review T2.1).
      const started = store.startGame(roomId);
      store.touch(roomId);
      io.to(roomId).emit(UPDATE_ROOM, RoomStore.serialize(started));

      // Start the 1s tick loop for this room.
      timerEngine.start(io, store, roomId);
      console.log(`[server] game started in room ${roomId}`);
    });

    // ── turn (pass) ──────────────────────────────────────────────
    socket.on(TURN, ({ roomId }) => {
      const room = store.get(roomId);
      if (!room) {
        socket.emit(ERROR_OCCURRED, 'Room not found.');
        return;
      }

      const updated = store.passTurn(roomId);
      if (!updated) {
        socket.emit(ERROR_OCCURRED, 'Could not pass turn.');
        return;
      }

      io.to(roomId).emit(NEW_TURN, RoomStore.serialize(updated));

      // Restart the timer for the next player (clears any existing interval
      // first — guarantees ≤ 1 interval per room, fixing A1).
      timerEngine.start(io, store, roomId);
    });

    // ── pause ────────────────────────────────────────────────────
    socket.on(PAUSE, ({ roomId }) => {
      const room = store.get(roomId);
      if (!room) {
        socket.emit(ERROR_OCCURRED, 'Room not found.');
        return;
      }

      timerEngine.pause(store, roomId);
      const updated = store.get(roomId);
      io.to(roomId).emit(UPDATE_ROOM, RoomStore.serialize(updated));
    });

    // ── toContinue (resume) ──────────────────────────────────────
    socket.on(RESUME, ({ roomId }) => {
      const room = store.get(roomId);
      if (!room) {
        socket.emit(ERROR_OCCURRED, 'Room not found.');
        return;
      }

      timerEngine.resume(io, store, roomId);
      const updated = store.get(roomId);
      io.to(roomId).emit(UPDATE_ROOM, RoomStore.serialize(updated));
    });

    socket.on('disconnect', () => {
      console.log(`[server] client disconnected: ${socket.id}`);
      // T2.3 handles presence/rejoin — seat kept, timer auto-pause policy.
    });
  });
}

/**
 * Stop all timers (for graceful shutdown / test teardown).
 */
export function shutdownTimers() {
  timerEngine.stopAll();
}
