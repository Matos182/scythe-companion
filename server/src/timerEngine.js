// SPDX-License-Identifier: MIT

/**
 * Timer engine (fixes A1/A2/A6).
 *
 * One authoritative timer per room, owned by a module-level
 * `Map<roomCode, TimerHandle>` — never a per-connection variable (A1).
 * The engine decrements `remainingSec` in memory via the RoomStore and
 * broadcasts a `tick` event every second — no DB round-trip per tick (A2).
 *
 * The `start` method always clears any existing interval for the room
 * before creating a new one, guaranteeing ≤ 1 interval per room by
 * construction.  `pause` clears the interval and sets `isPaused`.  `resume`
 * re-creates it.  `stop` clears and removes the room from the map entirely.
 *
 * When `remainingSec` hits 0, the engine auto-passes the turn via
 * `store.passTurn` and broadcasts a `newTurn` event, then continues ticking
 * for the next player.
 */

import { RoomStore } from './roomStore.js';

const TICK_MS = 1000;

/**
 * @typedef {Object} TimerHandle
 * @property {ReturnType<typeof setInterval>} interval  — the 1s interval
 * @property {boolean} paused                            — is the timer paused?
 */

/** @type {Map<string, TimerHandle>} */
const timers = new Map();

/**
 * Clear the interval for a room and remove it from the map.
 * @param {string} roomCode
 */
function clear(roomCode) {
  const handle = timers.get(roomCode);
  if (handle) {
    clearInterval(handle.interval);
    timers.delete(roomCode);
  }
}

/**
 * Start (or restart) the 1s tick loop for a room.  Always clears any
 * existing interval first — guarantees ≤ 1 interval per room (A1).
 *
 * On each tick: decrement the current player's remainingSec via the store.
 * If remaining hits 0, auto-pass the turn and broadcast `newTurn`.
 * Otherwise broadcast `tick { roomCode, playerId, remainingSec }`.
 *
 * @param {import('socket.io').Server} io
 * @param {import('./roomStore.js').RoomStore} store
 * @param {string} roomCode
 */
function start(io, store, roomCode) {
  // Always clear before starting — this is the A1 fix: no orphaned intervals.
  clear(roomCode);

  const room = store.get(roomCode);
  if (!room) return;

  const interval = setInterval(() => {
    const currentRoom = store.get(roomCode);
    if (!currentRoom || currentRoom.isPaused) {
      // Room deleted or paused — stop ticking.
      clear(roomCode);
      return;
    }

    const remaining = store.decrementTimer(roomCode);

    if (remaining === null) {
      // Room or player gone — clean up.
      clear(roomCode);
      return;
    }

    if (remaining <= 0) {
      // Time's up — auto-pass the turn.
      const updated = store.passTurn(roomCode);
      if (!updated) {
        clear(roomCode);
        return;
      }
      io.to(roomCode).emit('newTurn', RoomStore.serialize(updated));
    } else {
      // Broadcast tick to the room.
      io.to(roomCode).emit('tick', {
        roomCode,
        playerId: currentRoom.turn._id,
        remainingSec: remaining,
      });
    }
  }, TICK_MS);

  timers.set(roomCode, { interval, paused: false });
}

/**
 * Pause the timer for a room: clear the interval, mark paused.
 * The RoomStore's isPaused flag is the source of truth for the wire state.
 *
 * @param {import('./roomStore.js').RoomStore} store
 * @param {string} roomCode
 */
function pause(store, roomCode) {
  const handle = timers.get(roomCode);
  if (handle) {
    clearInterval(handle.interval);
    handle.paused = true;
  }
  store.setPaused(roomCode, true);
}

/**
 * Resume the timer for a room: re-create the interval.
 *
 * @param {import('socket.io').Server} io
 * @param {import('./roomStore.js').RoomStore} store
 * @param {string} roomCode
 */
function resume(io, store, roomCode) {
  store.setPaused(roomCode, false);
  start(io, store, roomCode);
}

/**
 * Stop and remove the timer for a room entirely (room deleted, game over).
 * @param {string} roomCode
 */
function stop(roomCode) {
  clear(roomCode);
}

/**
 * Does a room currently have an active (non-paused) timer?
 * @param {string} roomCode
 * @returns {boolean}
 */
function isActive(roomCode) {
  const handle = timers.get(roomCode);
  return !!handle && !handle.paused;
}

/**
 * Does a room have any timer entry (active or paused)?
 * @param {string} roomCode
 * @returns {boolean}
 */
function has(roomCode) {
  return timers.has(roomCode);
}

/**
 * Stop all timers (for graceful shutdown / test teardown).
 */
function stopAll() {
  for (const roomCode of timers.keys()) {
    clear(roomCode);
  }
}

export { start, pause, resume, stop, stopAll, isActive, has };
