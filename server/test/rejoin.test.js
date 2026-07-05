// SPDX-License-Identifier: MIT

import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import http from 'node:http';
import { Server } from 'socket.io';
import { io as Client } from 'socket.io-client';
import { RoomStore } from '../src/roomStore.js';
import { registerHandlers, shutdownTimers } from '../src/handlers.js';

/**
 * Integration test (T2.3 done-criteria):
 * Client drops, reconnects with same playerId, receives full state;
 * timer auto-paused on disconnect, resumed on rejoin.
 *
 * Flow:
 * 1. Alice creates, Bob joins, game starts (Alice's turn)
 * 2. Alice disconnects → auto-pause (her turn), broadcast presence
 * 3. Bob sees Alice disconnected + isPaused
 * 4. Alice reconnects via rejoinRoom → timer resumes, presence restored
 * 5. Bob sees Alice reconnected + !isPaused
 */

const testPort = 3993;
let httpServer;
let io;
let store;

beforeAll(() => {
  httpServer = http.createServer();
  io = new Server(httpServer, { cors: { origin: '*' } });
  store = new RoomStore();
  registerHandlers(io, store);
  return new Promise((resolve) => httpServer.listen(testPort, resolve));
});

afterAll(() => {
  shutdownTimers();
  store.stopSweeper();
  io.close();
  return new Promise((resolve) => httpServer.close(resolve));
});

function createClient() {
  return Client(`http://localhost:${testPort}`, {
    transports: ['websocket'],
  });
}

describe('integration: disconnect → rejoin', () => {
  it('client drops, reconnects with same playerId, timer auto-pauses and resumes', () => {
    return new Promise((resolve, reject) => {
      const alice = createClient();
      const bob = createClient();
      let alicePlayerId = null;
      let roomCode = null;
      let phase = 'setup';

      const timeout = setTimeout(() => {
        reject(new Error(`Integration test timeout in phase: ${phase}`));
      }, 8000);

      // ── Alice creates the room ──
      alice.on('connect', () => {
        alice.emit('createRoom', {
          nickname: 'Alice',
          playerfaction: 'Crimea',
          playermat: '1',
          timer: 300,
        });
      });

      alice.on('createRoomSuccess', (room) => {
        alicePlayerId = room.players[0]._id;
        roomCode = room._id;
        // Alice's socketID should be set (T2.3 fix — was '' in T2.1)
        expect(room.players[0].socketID).not.toBe('');
        bob.emit('joinRoom', {
          nickname: 'Bob',
          roomId: roomCode,
          playerfaction: 'Saxony',
          playermat: '2',
        });
      });

      bob.on('joinRoomSuccess', (room) => {
        // Bob's socketID should also be set (T2.3 fix)
        expect(room.players[1].socketID).not.toBe('');
        // Start the game — Alice's turn (mat 1, Crimea)
        alice.emit('startGame', { roomId: roomCode });
      });

      // Wait for the game to start, then disconnect Alice
      bob.on('updateRoom', (room) => {
        if (phase === 'setup' && !room.isJoin && room.players.length === 2) {
          phase = 'alice-disconnected';
          // Verify it's Alice's turn
          expect(room.turn.nickname).toBe('Alice');
          // Verify both connected
          expect(room.players[0].connected).toBe(true);
          expect(room.players[1].connected).toBe(true);
          // Disconnect Alice
          alice.disconnect();
        } else if (phase === 'alice-disconnected' && room.isPaused) {
          // Alice disconnected → auto-paused + presence broadcast
          phase = 'alice-rejoined';
          expect(room.isPaused).toBe(true);
          expect(room.players[0].connected).toBe(false); // Alice
          expect(room.players[1].connected).toBe(true);  // Bob
          // Creator should transfer to Bob
          expect(room.creator.nickname).toBe('Bob');

          // Now Alice rejoins with a new connection
          const aliceRejoined = createClient();
          aliceRejoined.on('connect', () => {
            aliceRejoined.emit('rejoinRoom', {
              roomCode,
              playerId: alicePlayerId,
            });
          });

          aliceRejoined.on('joinRoomSuccess', (room) => {
            // Alice should be back, connected, timer resumed
            expect(room.players[0].connected).toBe(true);
            expect(room.isPaused).toBe(false);
            // It's still Alice's turn
            expect(room.turn.nickname).toBe('Alice');
            // Creator transferred back to Alice? No — Bob was transferred
            // when Alice disconnected. Creator stays with Bob unless we
            // transfer back. That's fine — creator handover is one-way.
            clearTimeout(timeout);
            aliceRejoined.disconnect();
            bob.disconnect();
            resolve();
          });

          aliceRejoined.on('errorOccurred', (msg) => {
            clearTimeout(timeout);
            reject(new Error(`Rejoin error: ${msg}`));
          });
        }
      });

      alice.on('errorOccurred', (msg) => {
        clearTimeout(timeout);
        reject(new Error(`Alice error: ${msg}`));
      });
      bob.on('errorOccurred', (msg) => {
        clearTimeout(timeout);
        reject(new Error(`Bob error: ${msg}`));
      });
      bob.on('connect_error', reject);

      bob.connect();
    });
  }, 12000);

  it('rejoin rejects unknown playerId', () => {
    return new Promise((resolve, reject) => {
      const c = createClient();
      let roomCode;

      const timeout = setTimeout(() => reject(new Error('timeout')), 5000);

      c.on('connect', () => {
        c.emit('createRoom', {
          nickname: 'Alice', playerfaction: 'Crimea', playermat: '1', timer: 60,
        });
      });

      c.on('createRoomSuccess', (room) => {
        roomCode = room._id;
        c.emit('rejoinRoom', { roomCode, playerId: 'fake-player-id' });
      });

      c.on('errorOccurred', (msg) => {
        clearTimeout(timeout);
        expect(msg).toContain('not found');
        c.disconnect();
        resolve();
      });
    });
  }, 8000);
});
