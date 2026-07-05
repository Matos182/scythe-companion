// SPDX-License-Identifier: MIT

import { describe, it, expect, beforeEach } from 'vitest';
import { RoomStore } from '../src/roomStore.js';

/**
 * Presence & rejoin unit tests (T2.3).
 *
 * Tests the RoomStore methods that support presence tracking and rejoin:
 * markConnected, rejoin, findPlayer, isCurrentTurnPlayer, transferCreator.
 * Also verifies that serialize() now includes the `connected` field.
 */

describe('RoomStore presence & rejoin (T2.3)', () => {
  let store;

  beforeEach(() => {
    store = new RoomStore();
  });

  function makeStartedRoom() {
    const { room, playerId } = store.create({
      nickname: 'Alice', playerfaction: 'Crimea', playermat: '1', timer: 300,
    });
    store.join(room._id, {
      nickname: 'Bob', playerfaction: 'Saxony', playermat: '2',
    });
    store.startGame(room._id);
    return { room, playerId };
  }

  describe('findPlayer', () => {
    it('finds a player by playerId', () => {
      const { room, playerId } = makeStartedRoom();
      const player = store.findPlayer(room._id, playerId);
      expect(player).toBeDefined();
      expect(player.nickname).toBe('Alice');
    });

    it('returns undefined for non-existent room', () => {
      expect(store.findPlayer('NOPE', 'nope')).toBeUndefined();
    });

    it('returns undefined for non-existent player', () => {
      const { room } = makeStartedRoom();
      expect(store.findPlayer(room._id, 'nope')).toBeUndefined();
    });
  });

  describe('markConnected', () => {
    it('sets connected to false on disconnect', () => {
      const { room, playerId } = makeStartedRoom();
      store.markConnected(room._id, playerId, false);
      expect(store.findPlayer(room._id, playerId).connected).toBe(false);
    });

    it('sets connected to true on reconnect', () => {
      const { room, playerId } = makeStartedRoom();
      store.markConnected(room._id, playerId, false);
      store.markConnected(room._id, playerId, true, 'new-socket-id');
      const player = store.findPlayer(room._id, playerId);
      expect(player.connected).toBe(true);
      expect(player.socketID).toBe('new-socket-id');
    });

    it('returns undefined for non-existent room/player', () => {
      expect(store.markConnected('NOPE', 'nope', false)).toBeUndefined();
    });
  });

  describe('rejoin', () => {
    it('remaps socketID and marks connected', () => {
      const { room, playerId } = makeStartedRoom();
      // Simulate disconnect
      store.markConnected(room._id, playerId, false);
      expect(store.findPlayer(room._id, playerId).connected).toBe(false);

      // Rejoin
      const rejoined = store.rejoin(room._id, playerId, 'new-socket-id');
      expect(rejoined).not.toBeNull();
      const player = store.findPlayer(room._id, playerId);
      expect(player.socketID).toBe('new-socket-id');
      expect(player.connected).toBe(true);
    });

    it('returns null for non-existent room', () => {
      expect(store.rejoin('NOPE', 'nope', 'socket')).toBeNull();
    });

    it('returns null for non-existent player', () => {
      const { room } = makeStartedRoom();
      expect(store.rejoin(room._id, 'nope', 'socket')).toBeNull();
    });

    it('preserves other player state (seat kept)', () => {
      const { room, playerId } = makeStartedRoom();
      // Bob's state
      const bob = room.players[1];
      bob.remainingSec = 42;

      store.markConnected(room._id, playerId, false);
      store.rejoin(room._id, playerId, 'new-socket');

      // Bob's remainingSec is unchanged
      expect(store.get(room._id).players[1].remainingSec).toBe(42);
    });
  });

  describe('isCurrentTurnPlayer', () => {
    it('returns true for the current turn player', () => {
      const { room, playerId } = makeStartedRoom();
      expect(store.isCurrentTurnPlayer(room._id, playerId)).toBe(true);
    });

    it('returns false for a non-current player', () => {
      const { room } = makeStartedRoom();
      const bobId = room.players[1]._id;
      expect(store.isCurrentTurnPlayer(room._id, bobId)).toBe(false);
    });

    it('returns false for non-existent room', () => {
      expect(store.isCurrentTurnPlayer('NOPE', 'nope')).toBe(false);
    });
  });

  describe('transferCreator', () => {
    it('returns existing creator if still connected', () => {
      const { room } = makeStartedRoom();
      const creator = store.transferCreator(room._id);
      expect(creator.nickname).toBe('Alice');
    });

    it('transfers to first connected player when creator disconnects', () => {
      const { room, playerId } = makeStartedRoom();
      store.markConnected(room._id, playerId, false);
      const newCreator = store.transferCreator(room._id);
      expect(newCreator.nickname).toBe('Bob');
    });

    it('returns the old creator if no connected players remain', () => {
      const { room } = makeStartedRoom();
      // Disconnect all players
      for (const p of room.players) {
        store.markConnected(room._id, p._id, false);
      }
      const creator = store.transferCreator(room._id);
      // No transfer — creator stays as Alice (disconnected)
      expect(creator.nickname).toBe('Alice');
    });

    it('returns undefined for non-existent room', () => {
      expect(store.transferCreator('NOPE')).toBeUndefined();
    });
  });

  describe('serialize includes connected', () => {
    it('includes connected on players', () => {
      const { room } = makeStartedRoom();
      const wire = RoomStore.serialize(room);
      expect(wire.players[0]).toHaveProperty('connected');
      expect(wire.players[0].connected).toBe(true);
      expect(wire.players[1]).toHaveProperty('connected');
      expect(wire.players[1].connected).toBe(true);
    });

    it('includes connected on turn and creator', () => {
      const { room } = makeStartedRoom();
      const wire = RoomStore.serialize(room);
      expect(wire.turn).toHaveProperty('connected');
      expect(wire.creator).toHaveProperty('connected');
    });

    it('reflects disconnected state on the wire', () => {
      const { room, playerId } = makeStartedRoom();
      store.markConnected(room._id, playerId, false);
      const wire = RoomStore.serialize(store.get(room._id));
      expect(wire.players[0].connected).toBe(false);
      expect(wire.turn.connected).toBe(false);
    });
  });
});
