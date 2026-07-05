// SPDX-License-Identifier: MIT

import { describe, it, expect } from 'vitest';
import {
  validateCreateRoom,
  validateJoinRoom,
  validateRoomAction,
  validateRejoinRoom,
  _constants,
} from '../src/validation.js';
import { ERROR_CODES } from '../src/errors.js';

/**
 * Payload validation tests (T2.4 done-criteria).
 *
 * Every validator returns { ok: true, data } for valid payloads and
 * { ok: false, code, message } for invalid ones.  Malformed payloads
 * must return an error code — never throw, never crash.
 */

describe('validateCreateRoom', () => {
  const valid = {
    nickname: 'Alice',
    playerfaction: 'Crimea',
    playermat: '1',
    timer: 300,
  };

  it('accepts a valid payload', () => {
    const result = validateCreateRoom(valid);
    expect(result.ok).toBe(true);
    expect(result.data.nickname).toBe('Alice');
    expect(result.data.playerfaction).toBe('Crimea');
    expect(result.data.playermat).toBe('1');
    expect(result.data.timer).toBe(300);
  });

  it('trims whitespace from nickname', () => {
    const result = validateCreateRoom({ ...valid, nickname: '  Alice  ' });
    expect(result.ok).toBe(true);
    expect(result.data.nickname).toBe('Alice');
  });

  it('rejects missing nickname', () => {
    const result = validateCreateRoom({ ...valid, nickname: '' });
    expect(result.ok).toBe(false);
    expect(result.code).toBe(ERROR_CODES.VAL_MISSING_NICKNAME);
  });

  it('rejects whitespace-only nickname', () => {
    const result = validateCreateRoom({ ...valid, nickname: '   ' });
    expect(result.ok).toBe(false);
    expect(result.code).toBe(ERROR_CODES.VAL_MISSING_NICKNAME);
  });

  it('rejects nickname over 30 chars', () => {
    const result = validateCreateRoom({ ...valid, nickname: 'A'.repeat(31) });
    expect(result.ok).toBe(false);
    expect(result.code).toBe(ERROR_CODES.VAL_MISSING_NICKNAME);
  });

  it('rejects invalid faction', () => {
    const result = validateCreateRoom({ ...valid, playerfaction: 'BogusFaction' });
    expect(result.ok).toBe(false);
    expect(result.code).toBe(ERROR_CODES.VAL_INVALID_FACTION);
  });

  it('rejects invalid mat', () => {
    const result = validateCreateRoom({ ...valid, playermat: '99' });
    expect(result.ok).toBe(false);
    expect(result.code).toBe(ERROR_CODES.VAL_INVALID_MAT);
  });

  it('rejects timer below minimum', () => {
    const result = validateCreateRoom({ ...valid, timer: 5 });
    expect(result.ok).toBe(false);
    expect(result.code).toBe(ERROR_CODES.VAL_INVALID_TIMER);
  });

  it('rejects timer above maximum', () => {
    const result = validateCreateRoom({ ...valid, timer: 99999 });
    expect(result.ok).toBe(false);
    expect(result.code).toBe(ERROR_CODES.VAL_INVALID_TIMER);
  });

  it('rejects non-integer timer', () => {
    const result = validateCreateRoom({ ...valid, timer: 300.5 });
    expect(result.ok).toBe(false);
    expect(result.code).toBe(ERROR_CODES.VAL_INVALID_TIMER);
  });

  it('rejects null payload', () => {
    const result = validateCreateRoom(null);
    expect(result.ok).toBe(false);
    expect(result.code).toBe(ERROR_CODES.VAL_BAD_PAYLOAD);
  });

  it('rejects undefined payload', () => {
    const result = validateCreateRoom(undefined);
    expect(result.ok).toBe(false);
    expect(result.code).toBe(ERROR_CODES.VAL_BAD_PAYLOAD);
  });

  it('rejects string payload', () => {
    const result = validateCreateRoom('not an object');
    expect(result.ok).toBe(false);
    expect(result.code).toBe(ERROR_CODES.VAL_BAD_PAYLOAD);
  });

  it('accepts all valid factions', () => {
    for (const faction of _constants.VALID_FACTIONS) {
      const result = validateCreateRoom({ ...valid, playerfaction: faction });
      expect(result.ok).toBe(true);
    }
  });

  it('accepts all valid mats', () => {
    for (const mat of _constants.VALID_MATS) {
      const result = validateCreateRoom({ ...valid, playermat: mat });
      expect(result.ok).toBe(true);
    }
  });
});

describe('validateJoinRoom', () => {
  const valid = {
    nickname: 'Bob',
    roomId: 'AB3KMN',
    playerfaction: 'Saxony',
    playermat: '2',
  };

  it('accepts a valid payload', () => {
    const result = validateJoinRoom(valid);
    expect(result.ok).toBe(true);
    expect(result.data.roomId).toBe('AB3KMN');
  });

  it('rejects missing roomId', () => {
    const result = validateJoinRoom({ ...valid, roomId: '' });
    expect(result.ok).toBe(false);
    expect(result.code).toBe(ERROR_CODES.VAL_MISSING_ROOM_ID);
  });

  it('rejects missing nickname', () => {
    const result = validateJoinRoom({ ...valid, nickname: '' });
    expect(result.ok).toBe(false);
    expect(result.code).toBe(ERROR_CODES.VAL_MISSING_NICKNAME);
  });

  it('rejects invalid faction', () => {
    const result = validateJoinRoom({ ...valid, playerfaction: 'Wrong' });
    expect(result.ok).toBe(false);
    expect(result.code).toBe(ERROR_CODES.VAL_INVALID_FACTION);
  });

  it('rejects null payload', () => {
    const result = validateJoinRoom(null);
    expect(result.ok).toBe(false);
    expect(result.code).toBe(ERROR_CODES.VAL_BAD_PAYLOAD);
  });
});

describe('validateRoomAction (startGame/turn/pause/resume)', () => {
  it('accepts a valid roomId', () => {
    const result = validateRoomAction({ roomId: 'AB3KMN' });
    expect(result.ok).toBe(true);
    expect(result.data.roomId).toBe('AB3KMN');
  });

  it('trims whitespace from roomId', () => {
    const result = validateRoomAction({ roomId: '  AB3KMN  ' });
    expect(result.ok).toBe(true);
    expect(result.data.roomId).toBe('AB3KMN');
  });

  it('rejects missing roomId', () => {
    const result = validateRoomAction({ roomId: '' });
    expect(result.ok).toBe(false);
    expect(result.code).toBe(ERROR_CODES.VAL_MISSING_ROOM_ID);
  });

  it('rejects null payload', () => {
    const result = validateRoomAction(null);
    expect(result.ok).toBe(false);
    expect(result.code).toBe(ERROR_CODES.VAL_BAD_PAYLOAD);
  });

  it('rejects undefined payload', () => {
    const result = validateRoomAction(undefined);
    expect(result.ok).toBe(false);
    expect(result.code).toBe(ERROR_CODES.VAL_BAD_PAYLOAD);
  });

  it('rejects a number', () => {
    const result = validateRoomAction(42);
    expect(result.ok).toBe(false);
    expect(result.code).toBe(ERROR_CODES.VAL_BAD_PAYLOAD);
  });
});

describe('validateRejoinRoom', () => {
  it('accepts valid roomCode + playerId', () => {
    const result = validateRejoinRoom({
      roomCode: 'AB3KMN',
      playerId: '550e8400-e29b-41d4-a716-446655440000',
    });
    expect(result.ok).toBe(true);
    expect(result.data.roomCode).toBe('AB3KMN');
  });

  it('rejects missing roomCode', () => {
    const result = validateRejoinRoom({ roomCode: '', playerId: 'uuid' });
    expect(result.ok).toBe(false);
    expect(result.code).toBe(ERROR_CODES.VAL_MISSING_FIELDS);
  });

  it('rejects missing playerId', () => {
    const result = validateRejoinRoom({ roomCode: 'AB3KMN', playerId: '' });
    expect(result.ok).toBe(false);
    expect(result.code).toBe(ERROR_CODES.VAL_MISSING_FIELDS);
  });

  it('rejects null payload', () => {
    const result = validateRejoinRoom(null);
    expect(result.ok).toBe(false);
    expect(result.code).toBe(ERROR_CODES.VAL_BAD_PAYLOAD);
  });
});
