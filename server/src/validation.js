// SPDX-License-Identifier: MIT

/**
 * Hand-rolled payload validators for every client→server event.
 *
 * Each validator takes the raw `payload` received from the socket and
 * returns either `{ ok: true, data }` (normalised) or
 * `{ ok: false, code, message }` (matching the error envelope in errors.js).
 *
 * Why hand-rolled instead of zod?  At this scale (~7 events, flat
 * payloads) a validation library is a dependency we don't need — the
 * rules are simple enough to read at a glance.  If the protocol grows
 * substantially, swap this module for zod schemas; the handler call
 * sites don't need to change.
 */

import { ERROR_CODES } from './errors.js';

// ── Constants reused across validators ──────────────────────────────

const VALID_FACTIONS = new Set([
  'Crimea', 'Saxony', 'Polania', 'Albion', 'Nordic', 'Rusviet', 'Togawa',
]);

const VALID_MATS = new Set(['1', '2', '2A', '3', '3A', '4', '5']);

const MIN_NICKNAME_LEN = 1;
const MAX_NICKNAME_LEN = 30;
const MIN_TIMER = 10;          // seconds
const MAX_TIMER = 3600;        // 1 hour — beyond this is absurd for a turn
// NOTE (audit F2): a `MAX_ROOMS = 7` used to live here. It was dead code and
// actively misleading — nothing imported it, it meant *players per room*, and
// it collided by name with the real room cap (`config.maxRooms`, default 100,
// from the MAX_ROOMS env var). The genuine 7-player limit is MAX_PLAYERS in
// roomStore.js, which is the module that enforces it.

// ── Helpers ────────────────────────────────────────────────────────

/**
 * @param {unknown} payload
 * @returns {{ok: false, code: string, message: string}}
 */
function badPayload(message) {
  return { ok: false, code: ERROR_CODES.VAL_BAD_PAYLOAD, message };
}

/**
 * @param {unknown} v
 * @returns {boolean}
 */
function isNonEmptyString(v) {
  return typeof v === 'string' && v.trim().length > 0;
}

/**
 * @param {unknown} v
 * @returns {boolean}
 */
function isPositiveInt(v) {
  return Number.isInteger(v) && v > 0;
}

// ── Per-event validators ────────────────────────────────────────────

/**
 * createRoom payload: { nickname, playerfaction, playermat, timer }
 * @param {unknown} payload
 * @returns {{ok: true, data: object} | {ok: false, code: string, message: string}}
 */
export function validateCreateRoom(payload) {
  if (!payload || typeof payload !== 'object') {
    return badPayload('Invalid payload.');
  }
  const { nickname, playerfaction, playermat, timer } = payload;

  if (!isNonEmptyString(nickname) || nickname.trim().length > MAX_NICKNAME_LEN) {
    return {
      ok: false,
      code: ERROR_CODES.VAL_MISSING_NICKNAME,
      message: `Please enter a valid nickname (1–${MAX_NICKNAME_LEN} characters).`,
    };
  }

  if (!VALID_FACTIONS.has(playerfaction)) {
    return {
      ok: false,
      code: ERROR_CODES.VAL_INVALID_FACTION,
      message: `Invalid faction "${playerfaction}".`,
    };
  }

  if (!VALID_MATS.has(playermat)) {
    return {
      ok: false,
      code: ERROR_CODES.VAL_INVALID_MAT,
      message: `Invalid player mat "${playermat}".`,
    };
  }

  if (!isPositiveInt(timer) || timer < MIN_TIMER || timer > MAX_TIMER) {
    return {
      ok: false,
      code: ERROR_CODES.VAL_INVALID_TIMER,
      message: `Timer must be an integer between ${MIN_TIMER} and ${MAX_TIMER}.`,
    };
  }

  return {
    ok: true,
    data: {
      nickname: nickname.trim(),
      playerfaction,
      playermat,
      timer,
    },
  };
}

/**
 * joinRoom payload: { nickname, roomId, playerfaction, playermat }
 * @param {unknown} payload
 * @returns {{ok: true, data: object} | {ok: false, code: string, message: string}}
 */
export function validateJoinRoom(payload) {
  if (!payload || typeof payload !== 'object') {
    return badPayload('Invalid payload.');
  }
  const { nickname, roomId, playerfaction, playermat } = payload;

  if (!isNonEmptyString(roomId)) {
    return {
      ok: false,
      code: ERROR_CODES.VAL_MISSING_ROOM_ID,
      message: 'Please enter a valid Room ID.',
    };
  }

  if (!isNonEmptyString(nickname) || nickname.trim().length > MAX_NICKNAME_LEN) {
    return {
      ok: false,
      code: ERROR_CODES.VAL_MISSING_NICKNAME,
      message: `Please enter a valid nickname (1–${MAX_NICKNAME_LEN} characters).`,
    };
  }

  if (!VALID_FACTIONS.has(playerfaction)) {
    return {
      ok: false,
      code: ERROR_CODES.VAL_INVALID_FACTION,
      message: `Invalid faction "${playerfaction}".`,
    };
  }

  if (!VALID_MATS.has(playermat)) {
    return {
      ok: false,
      code: ERROR_CODES.VAL_INVALID_MAT,
      message: `Invalid player mat "${playermat}".`,
    };
  }

  return {
    ok: true,
    data: {
      nickname: nickname.trim(),
      roomId: roomId.trim(),
      playerfaction,
      playermat,
    },
  };
}

/**
 * startGame / turn / pause / resume payloads: { roomId }
 * All four share the same shape — just a room code.
 * @param {unknown} payload
 * @returns {{ok: true, data: object} | {ok: false, code: string, message: string}}
 */
export function validateRoomAction(payload) {
  if (!payload || typeof payload !== 'object') {
    return badPayload('Invalid payload.');
  }
  const { roomId } = payload;

  if (!isNonEmptyString(roomId)) {
    return {
      ok: false,
      code: ERROR_CODES.VAL_MISSING_ROOM_ID,
      message: 'Room ID is required.',
    };
  }

  return { ok: true, data: { roomId: roomId.trim() } };
}

/**
 * rejoinRoom payload: { roomCode, playerId }
 * @param {unknown} payload
 * @returns {{ok: true, data: object} | {ok: false, code: string, message: string}}
 */
export function validateRejoinRoom(payload) {
  if (!payload || typeof payload !== 'object') {
    return badPayload('Invalid payload.');
  }
  const { roomCode, playerId } = payload;

  if (!isNonEmptyString(roomCode) || !isNonEmptyString(playerId)) {
    return {
      ok: false,
      code: ERROR_CODES.VAL_MISSING_FIELDS,
      message: 'Room code and player ID are required.',
    };
  }

  return {
    ok: true,
    data: {
      roomCode: roomCode.trim(),
      playerId: playerId.trim(),
    },
  };
}

// ── Exports for testing ────────────────────────────────────────────

export const _constants = {
  VALID_FACTIONS,
  VALID_MATS,
  MIN_NICKNAME_LEN,
  MAX_NICKNAME_LEN,
  MIN_TIMER,
  MAX_TIMER,
};
