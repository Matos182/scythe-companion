// SPDX-License-Identifier: MIT

import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import { RoomStore } from '../src/roomStore.js';
import * as timerEngine from '../src/timerEngine.js';

/**
 * Timer engine tests (T2.2 done-criteria).
 *
 * Uses a mock io object (no real socket.io) + vitest fake timers to prove:
 * 1. No double-interval after rapid pass-pass-pause
 * 2. remainingSec survives pause (not reset)
 * 3. Room deletion kills its timer (no orphaned interval)
 * 4. Auto-pass when remainingSec hits 0
 *
 * Also tests the RoomStore timer methods directly.
 */

/**
 * Minimal mock of socket.io Server — just enough for the timer engine.
 * Tracks all emitted events grouped by roomCode.
 */
function createMockIo() {
  /** @type {Map<string, Array<{event: string, data: any}>>} */
  const emissions = new Map();

  return {
    to(roomCode) {
      return {
        emit(event, data) {
          if (!emissions.has(roomCode)) {
            emissions.set(roomCode, []);
          }
          emissions.get(roomCode).push({ event, data });
        },
      };
    },
    /** Get all emissions for a room */
    getEmissions(roomCode) {
      return emissions.get(roomCode) ?? [];
    },
    /** Get emissions filtered by event name */
    getEmissionsByEvent(roomCode, eventName) {
      return (emissions.get(roomCode) ?? []).filter((e) => e.event === eventName);
    },
    /** Clear all recorded emissions */
    clear() {
      emissions.clear();
    },
  };
}

describe('RoomStore timer methods', () => {
  let store;

  beforeEach(() => {
    store = new RoomStore();
  });

  function createStartedRoom() {
    const { room } = store.create({
      nickname: 'Alice', playerfaction: 'Crimea', playermat: '1', timer: 300,
    });
    store.join(room._id, {
      nickname: 'Bob', playerfaction: 'Saxony', playermat: '2',
    });
    return store.startGame(room._id);
  }

  describe('remainingSec field (A6)', () => {
    it('initializes remainingSec equal to timer on create', () => {
      const { room } = store.create({
        nickname: 'A', playerfaction: 'Crimea', playermat: '1', timer: 120,
      });
      expect(room.players[0].remainingSec).toBe(120);
    });

    it('initializes remainingSec equal to timer on join', () => {
      const { room } = store.create({
        nickname: 'A', playerfaction: 'Crimea', playermat: '1', timer: 90,
      });
      const result = store.join(room._id, {
        nickname: 'B', playerfaction: 'Saxony', playermat: '2',
      });
      expect(result.room.players[1].remainingSec).toBe(90);
    });

    it('resets remainingSec for all players on startGame', () => {
      const { room } = store.create({
        nickname: 'A', playerfaction: 'Crimea', playermat: '1', timer: 60,
      });
      store.join(room._id, {
        nickname: 'B', playerfaction: 'Saxony', playermat: '2',
      });
      // Burn some time on player 1
      room.players[0].remainingSec = 30;
      store.startGame(room._id);
      expect(room.players[0].remainingSec).toBe(60);
      expect(room.players[1].remainingSec).toBe(60);
    });
  });

  describe('decrementTimer', () => {
    it('decrements the current player remainingSec by 1', () => {
      const room = createStartedRoom();
      const before = room.turn.remainingSec;
      store.decrementTimer(room._id);
      expect(room.turn.remainingSec).toBe(before - 1);
    });

    it('returns the new remainingSec', () => {
      const room = createStartedRoom();
      const result = store.decrementTimer(room._id);
      expect(result).toBe(room.turn.remainingSec);
    });

    it('returns null for non-existent room', () => {
      expect(store.decrementTimer('NOPE')).toBeNull();
    });
  });

  describe('passTurn', () => {
    it('advances turnIndex to next player', () => {
      const room = createStartedRoom();
      expect(room.turnIndex).toBe(0);
      store.passTurn(room._id);
      expect(room.turnIndex).toBe(1);
      expect(room.turn.nickname).toBe('Bob');
    });

    it('wraps around and increments totalTurns', () => {
      const room = createStartedRoom();
      store.passTurn(room._id); // 0 → 1
      store.passTurn(room._id); // 1 → 0, totalTurns++
      expect(room.turnIndex).toBe(0);
      expect(room.totalTurns).toBe(2);
    });

    it('resets remainingSec to minTurnSec if below threshold', () => {
      const room = createStartedRoom();
      // Set player 2's remainingSec below minTurnSec (10)
      room.players[1].remainingSec = 5;
      store.passTurn(room._id);
      expect(room.turn.remainingSec).toBe(10);
    });

    it('does not reset remainingSec if above threshold', () => {
      const room = createStartedRoom();
      room.players[1].remainingSec = 250;
      store.passTurn(room._id);
      expect(room.turn.remainingSec).toBe(250);
    });
  });

  describe('setPaused', () => {
    it('sets isPaused on the room', () => {
      const room = createStartedRoom();
      store.setPaused(room._id, true);
      expect(room.isPaused).toBe(true);
      store.setPaused(room._id, false);
      expect(room.isPaused).toBe(false);
    });
  });

  describe('serialize includes remainingSec', () => {
    it('includes remainingSec on players, turn, and creator', () => {
      const room = createStartedRoom();
      const wire = RoomStore.serialize(room);
      expect(wire.players[0]).toHaveProperty('remainingSec');
      expect(wire.players[1]).toHaveProperty('remainingSec');
      expect(wire.turn).toHaveProperty('remainingSec');
      expect(wire.creator).toHaveProperty('remainingSec');
    });
  });
});

describe('timerEngine (fake timers)', () => {
  let store;
  let io;

  beforeEach(() => {
    vi.useFakeTimers();
    store = new RoomStore();
    io = createMockIo();
  });

  afterEach(() => {
    timerEngine.stopAll();
    store.stopSweeper();
    vi.useRealTimers();
  });

  function createStartedRoom(timer = 300) {
    const { room } = store.create({
      nickname: 'Alice', playerfaction: 'Crimea', playermat: '1', timer,
    });
    store.join(room._id, {
      nickname: 'Bob', playerfaction: 'Saxony', playermat: '2',
    });
    store.startGame(room._id);
    return room;
  }

  it('broadcasts tick events every second', () => {
    const room = createStartedRoom(300);

    timerEngine.start(io, store, room._id);

    // Advance 3 seconds
    vi.advanceTimersByTime(3000);

    const ticks = io.getEmissionsByEvent(room._id, 'tick');
    expect(ticks).toHaveLength(3);
    expect(ticks[0].data).toMatchObject({
      roomCode: room._id,
      remainingSec: 299,
    });
    expect(ticks[1].data.remainingSec).toBe(298);
    expect(ticks[2].data.remainingSec).toBe(297);
  });

  it('remainingSec survives pause (not reset)', () => {
    const room = createStartedRoom(300);

    timerEngine.start(io, store, room._id);

    // Tick 5 seconds → remainingSec should be 295
    vi.advanceTimersByTime(5000);
    expect(room.turn.remainingSec).toBe(295);

    // Pause
    timerEngine.pause(store, room._id);
    expect(room.isPaused).toBe(true);

    // Advance 10 seconds while paused — no ticks, remainingSec unchanged
    const ticksBefore = io.getEmissionsByEvent(room._id, 'tick').length;
    vi.advanceTimersByTime(10000);

    expect(room.turn.remainingSec).toBe(295);
    const ticksAfter = io.getEmissionsByEvent(room._id, 'tick').length;
    expect(ticksAfter).toBe(ticksBefore); // no new ticks during pause

    // Resume — ticking continues from 295, not reset to 300
    timerEngine.resume(io, store, room._id);
    vi.advanceTimersByTime(1000);

    expect(room.turn.remainingSec).toBe(294);
  });

  it('no double-interval after rapid pass-pass-pause', () => {
    const room = createStartedRoom(300);

    timerEngine.start(io, store, room._id);

    // Rapid fire: pass, pass, pause — each calls timerEngine.start or pause
    // This simulates what the socket handlers do.
    store.passTurn(room._id);
    timerEngine.start(io, store, room._id); // turn handler calls this

    store.passTurn(room._id);
    timerEngine.start(io, store, room._id); // turn handler calls this

    timerEngine.pause(store, room._id); // pause handler calls this

    // Advance 5 seconds — room is paused, zero ticks expected
    vi.advanceTimersByTime(5000);

    const ticks = io.getEmissionsByEvent(room._id, 'tick');
    expect(ticks).toHaveLength(0);
    expect(room.isPaused).toBe(true);

    // Verify the engine has no active timer for this room
    expect(timerEngine.isActive(room._id)).toBe(false);
  });

  it('room deletion kills its timer (no orphaned interval)', () => {
    const room = createStartedRoom(300);

    timerEngine.start(io, store, room._id);

    // Tick a couple seconds to confirm it's working
    vi.advanceTimersByTime(2000);
    const ticksBefore = io.getEmissionsByEvent(room._id, 'tick').length;
    expect(ticksBefore).toBe(2);

    // Delete the room from the store (simulates TTL sweeper or explicit delete)
    store.delete(room._id);

    // Advance 10 seconds — the next tick should detect the room is gone
    // and clear the interval. No more ticks should fire after that.
    vi.advanceTimersByTime(10000);

    const ticksAfter = io.getEmissionsByEvent(room._id, 'tick').length;
    // At most 1 more tick could fire (the one that detects the room is gone),
    // but definitely not 10.
    expect(ticksAfter).toBeLessThanOrEqual(ticksBefore + 1);

    // The engine should have cleaned up
    expect(timerEngine.has(room._id)).toBe(false);
  });

  it('auto-passes turn when remainingSec reaches 0', () => {
    const room = createStartedRoom(3); // 3-second timer

    timerEngine.start(io, store, room._id);

    // 3 seconds of ticking → timer hits 0 → auto-pass
    vi.advanceTimersByTime(3000);

    // Should have emitted newTurn with the next player (Bob)
    const newTurns = io.getEmissionsByEvent(room._id, 'newTurn');
    expect(newTurns.length).toBeGreaterThanOrEqual(1);
    expect(newTurns[0].data.turn.nickname).toBe('Bob');

    // After auto-pass, the timer should continue ticking for Bob.
    // Bob's remainingSec should be his allowance (300) since passTurn
    // doesn't reset if above minTurnSec.
    vi.advanceTimersByTime(1000);
    const bobTicks = io.getEmissionsByEvent(room._id, 'tick')
      .filter((t) => t.data.playerId === room.players[1]._id);
    expect(bobTicks.length).toBeGreaterThanOrEqual(1);
  });

  it('start called twice does not create duplicate intervals', () => {
    const room = createStartedRoom(300);

    // Call start twice — the second call should clear the first interval
    timerEngine.start(io, store, room._id);
    timerEngine.start(io, store, room._id);

    // Advance 3 seconds — should get exactly 3 ticks, not 6
    vi.advanceTimersByTime(3000);

    const ticks = io.getEmissionsByEvent(room._id, 'tick');
    expect(ticks).toHaveLength(3);
  });

  it('stop removes the timer entirely', () => {
    const room = createStartedRoom(300);

    timerEngine.start(io, store, room._id);
    expect(timerEngine.has(room._id)).toBe(true);

    timerEngine.stop(room._id);
    expect(timerEngine.has(room._id)).toBe(false);

    // Advance time — no ticks should fire
    vi.advanceTimersByTime(5000);
    const ticks = io.getEmissionsByEvent(room._id, 'tick');
    expect(ticks).toHaveLength(0);
  });
});
