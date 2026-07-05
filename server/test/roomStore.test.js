// SPDX-License-Identifier: MIT

import { describe, it, expect, beforeEach } from 'vitest';
import { RoomStore } from '../src/roomStore.js';

describe('RoomStore', () => {
  let store;

  beforeEach(() => {
    store = new RoomStore();
  });

  describe('create', () => {
    it('creates a room with a 6-char code and one player', () => {
      const { room, playerId } = store.create({
        nickname: 'Alice',
        playerfaction: 'Crimea',
        playermat: '1',
        timer: 300,
      });
      expect(room._id).toHaveLength(6);
      expect(room._id).toMatch(/^[ABCDEFGHJKMNPQRSTUVWXYZ23456789]{6}$/);
      expect(room.players).toHaveLength(1);
      expect(room.players[0].nickname).toBe('Alice');
      expect(room.players[0]._id).toBe(playerId);
      expect(room.isJoin).toBe(true);
      expect(room.turnIndex).toBe(0);
      expect(room.totalTurns).toBe(1);
      expect(room.isPaused).toBe(false);
      expect(room.turn).toBe(room.players[0]);
      expect(room.creator).toBe(room.players[0]);
    });

    it('generates unique playerIds', () => {
      const { playerId: id1 } = store.create({
        nickname: 'A', playerfaction: 'Crimea', playermat: '1', timer: 60,
      });
      const { playerId: id2 } = store.create({
        nickname: 'B', playerfaction: 'Saxony', playermat: '2', timer: 60,
      });
      expect(id1).not.toBe(id2);
    });

    it('generates unique room codes', () => {
      const { room: r1 } = store.create({
        nickname: 'A', playerfaction: 'Crimea', playermat: '1', timer: 60,
      });
      const { room: r2 } = store.create({
        nickname: 'B', playerfaction: 'Saxony', playermat: '2', timer: 60,
      });
      expect(r1._id).not.toBe(r2._id);
    });
  });

  describe('join', () => {
    it('adds a player to an existing room', () => {
      const { room } = store.create({
        nickname: 'A', playerfaction: 'Crimea', playermat: '1', timer: 120,
      });
      const result = store.join(room._id, {
        nickname: 'B', playerfaction: 'Saxony', playermat: '2',
      });
      expect(result).not.toBeNull();
      expect(result.room.players).toHaveLength(2);
      expect(result.room.players[1].nickname).toBe('B');
      expect(result.playerId).toBeDefined();
    });

    it('inherits timer from the first player', () => {
      const { room } = store.create({
        nickname: 'A', playerfaction: 'Crimea', playermat: '1', timer: 180,
      });
      const result = store.join(room._id, {
        nickname: 'B', playerfaction: 'Saxony', playermat: '2',
      });
      expect(result.room.players[1].timer).toBe(180);
    });

    it('returns null for non-existent room', () => {
      const result = store.join('NOTREAL', {
        nickname: 'B', playerfaction: 'Saxony', playermat: '2',
      });
      expect(result).toBeNull();
    });

    it('returns null if faction already picked', () => {
      const { room } = store.create({
        nickname: 'A', playerfaction: 'Crimea', playermat: '1', timer: 60,
      });
      const result = store.join(room._id, {
        nickname: 'B', playerfaction: 'Crimea', playermat: '2',
      });
      expect(result).toBeNull();
    });

    it('returns null if mat already picked', () => {
      const { room } = store.create({
        nickname: 'A', playerfaction: 'Crimea', playermat: '1', timer: 60,
      });
      const result = store.join(room._id, {
        nickname: 'B', playerfaction: 'Saxony', playermat: '1',
      });
      expect(result).toBeNull();
    });

    it('auto-closes room and runs faction wheel at 7 players', () => {
      const { room } = store.create({
        nickname: 'A', playerfaction: 'Crimea', playermat: '1', timer: 60,
      });
      const factions = ['Saxony', 'Polania', 'Albion', 'Nordic', 'Rusviet', 'Togawa'];
      const mats = ['2', '3', '4', '5', '2A', '3A'];
      for (let i = 0; i < 6; i++) {
        store.join(room._id, {
          nickname: `P${i}`, playerfaction: factions[i], playermat: mats[i],
        });
      }
      const finalRoom = store.get(room._id);
      expect(finalRoom.players).toHaveLength(7);
      expect(finalRoom.isJoin).toBe(false);
      // After reorder, first player should be Crimea (mat 1, faction index 0)
      expect(finalRoom.players[0].playerfaction).toBe('Crimea');
      expect(finalRoom.turn).toBe(finalRoom.players[0]);
    });
  });

  describe('startGame', () => {
    it('reorders players and sets first turn', () => {
      const { room } = store.create({
        nickname: 'A', playerfaction: 'Rusviet', playermat: '2', timer: 60,
      });
      store.join(room._id, {
        nickname: 'B', playerfaction: 'Crimea', playermat: '1',
      });
      const started = store.startGame(room._id);
      expect(started).not.toBeNull();
      expect(started.isJoin).toBe(false);
      // Mat 1 (Crimea) should be first after reorder
      expect(started.players[0].playerfaction).toBe('Crimea');
      expect(started.turn).toBe(started.players[0]);
    });

    it('returns null for single-player room', () => {
      const { room } = store.create({
        nickname: 'A', playerfaction: 'Crimea', playermat: '1', timer: 60,
      });
      expect(store.startGame(room._id)).toBeNull();
    });

    it('returns null for non-existent room', () => {
      expect(store.startGame('NOPE')).toBeNull();
    });
  });

  describe('get / delete', () => {
    it('get returns undefined for unknown code', () => {
      expect(store.get('NOPE')).toBeUndefined();
    });

    it('delete removes a room', () => {
      const { room } = store.create({
        nickname: 'A', playerfaction: 'Crimea', playermat: '1', timer: 60,
      });
      expect(store.get(room._id)).toBeDefined();
      store.delete(room._id);
      expect(store.get(room._id)).toBeUndefined();
    });
  });

  describe('findByPlayerId', () => {
    it('finds the room a player is in', () => {
      const { room, playerId } = store.create({
        nickname: 'A', playerfaction: 'Crimea', playermat: '1', timer: 60,
      });
      const found = store.findByPlayerId(playerId);
      expect(found._id).toBe(room._id);
    });

    it('returns undefined for unknown playerId', () => {
      expect(store.findByPlayerId('nope')).toBeUndefined();
    });
  });

  describe('serialize', () => {
    it('produces the wire format the Dart client expects', () => {
      const { room } = store.create({
        nickname: 'Alice', playerfaction: 'Crimea', playermat: '1', timer: 300,
      });
      const wire = RoomStore.serialize(room);
      expect(wire).toHaveProperty('_id');
      expect(wire).toHaveProperty('isJoin');
      expect(wire).toHaveProperty('turnIndex');
      expect(wire).toHaveProperty('totalTurns');
      expect(wire).toHaveProperty('isPaused');
      expect(wire).toHaveProperty('players');
      expect(wire).toHaveProperty('turn');
      expect(wire).toHaveProperty('creator');
      expect(wire).not.toHaveProperty('lastActivity');
      expect(wire.players[0]).not.toHaveProperty('connected');
      expect(wire.players[0]).toHaveProperty('_id');
      expect(wire.players[0]).toHaveProperty('nickname');
      expect(wire.players[0]).toHaveProperty('socketID');
      expect(wire.players[0]).toHaveProperty('playerfaction');
      expect(wire.players[0]).toHaveProperty('playermat');
      expect(wire.players[0]).toHaveProperty('timer');
    });
  });

  describe('TTL sweeper', () => {
    it('startSweeper does not crash', () => {
      store.startSweeper();
      store.stopSweeper();
    });
  });
});
