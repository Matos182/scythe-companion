// SPDX-License-Identifier: MIT

/**
 * Error code constants for the wire protocol.
 *
 * T2.4 changes `errorOccurred` from a bare string to a structured
 * envelope `{ code, message }`.  The `code` is a machine-readable
 * identifier (stable across versions — clients can switch on it); the
 * `message` is a human-readable English string (suitable for a snackbar).
 *
 * Codes are prefixed by category:
 *  - VAL_*  — input validation (bad payload shape or value)
 *  - AUTH_* — authorisation (not your turn, not in room, etc.)
 *  - STATE_* — room/game state errors (room full, game started, etc.)
 *  - RATE_* — rate limiting
 */

export const ERROR_CODES = Object.freeze({
  // Validation
  VAL_MISSING_NICKNAME: 'VAL_MISSING_NICKNAME',
  VAL_MISSING_ROOM_ID: 'VAL_MISSING_ROOM_ID',
  VAL_MISSING_FIELDS: 'VAL_MISSING_FIELDS',
  VAL_INVALID_TIMER: 'VAL_INVALID_TIMER',
  VAL_INVALID_FACTION: 'VAL_INVALID_FACTION',
  VAL_INVALID_MAT: 'VAL_INVALID_MAT',
  VAL_BAD_PAYLOAD: 'VAL_BAD_PAYLOAD',

  // Authorization (T4.7c)
  AUTH_NOT_IN_ROOM: 'AUTH_NOT_IN_ROOM',

  // State
  STATE_ROOM_NOT_FOUND: 'STATE_ROOM_NOT_FOUND',
  STATE_GAME_IN_PROGRESS: 'STATE_GAME_IN_PROGRESS',
  STATE_FACTION_OR_MAT_TAKEN: 'STATE_FACTION_OR_MAT_TAKEN',
  STATE_SINGLE_PLAYER: 'STATE_SINGLE_PLAYER',
  STATE_NOT_YOUR_TURN: 'STATE_NOT_YOUR_TURN',
  STATE_PASS_FAILED: 'STATE_PASS_FAILED',

  // Rejoin
  REJOIN_NOT_FOUND: 'REJOIN_NOT_FOUND',

  // Rate limit
  RATE_LIMITED: 'RATE_LIMITED',
  RATE_MAX_CONNECTIONS: 'RATE_MAX_CONNECTIONS',

  // Server
  SERVER_MAX_ROOMS: 'SERVER_MAX_ROOMS',
});

/**
 * Build an error envelope for the wire.
 * @param {string} code — one of ERROR_CODES
 * @param {string} message — human-readable
 * @returns {{code: string, message: string}}
 */
export function errorEnvelope(code, message) {
  return { code, message };
}
