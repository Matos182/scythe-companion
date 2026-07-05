// SPDX-License-Identifier: MIT

import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import http from 'node:http';
import { Server } from 'socket.io';
import { io as Client } from 'socket.io-client';
import { RoomStore } from '../src/roomStore.js';
import { registerHandlers } from '../src/handlers.js';

/**
 * Integration test (T2.1 done-criteria):
 * 3 fake clients create/join/start and receive identical room state.
 *
 * Client 1: createRoom (Crimea, mat 1)
 * Client 2: joinRoom (Saxony, mat 2)
 * Client 3: joinRoom (Polania, mat 3)
 * Client 1: startGame
 * → all 3 receive updateRoom with the same player order
 */

const testPort = 3991;
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
  io.close();
  store.stopSweeper();
  return new Promise((resolve) => httpServer.close(resolve));
});

function createClient() {
  return Client(`http://localhost:${testPort}`, {
    transports: ['websocket'],
  });
}

describe('integration: create → join → start', () => {
  it('3 clients create/join/start and receive identical room state', () => {
    return new Promise((resolve, reject) => {
      const client1 = createClient();
      const client2 = createClient();
      const client3 = createClient();

      const states = { c1: null, c2: null, c3: null };
      let roomCode = null;
      let startCount = 0;

      const timeout = setTimeout(() => {
        reject(new Error('Integration test timeout'));
      }, 5000);

      function checkDone() {
        if (states.c1 && states.c2 && states.c3 && startCount >= 3) {
          clearTimeout(timeout);
          // All 3 clients should have the same player order
          expect(states.c1.players.map((p) => p.playerfaction))
            .toEqual(['Crimea', 'Saxony', 'Polania']);
          expect(states.c2.players.map((p) => p.playerfaction))
            .toEqual(['Crimea', 'Saxony', 'Polania']);
          expect(states.c3.players.map((p) => p.playerfaction))
            .toEqual(['Crimea', 'Saxony', 'Polania']);

          // Room should be closed
          expect(states.c1.isJoin).toBe(false);

          // Turn should be the first player (Crimea, mat 1)
          expect(states.c1.turn.playerfaction).toBe('Crimea');

          client1.disconnect();
          client2.disconnect();
          client3.disconnect();
          resolve();
        }
      }

      // Client 1 listens for createRoomSuccess
      client1.on('createRoomSuccess', (room) => {
        roomCode = room._id;
        expect(room.players).toHaveLength(1);

        // Now client 2 joins
        client2.emit('joinRoom', {
          nickname: 'Bob',
          roomId: roomCode,
          playerfaction: 'Saxony',
          playermat: '2',
        });
      });

      // Client 2 listens for joinRoomSuccess
      client2.on('joinRoomSuccess', (room) => {
        expect(room.players).toHaveLength(2);

        // Now client 3 joins
        client3.emit('joinRoom', {
          nickname: 'Carol',
          roomId: roomCode,
          playerfaction: 'Polania',
          playermat: '3',
        });
      });

      // Client 3 listens for joinRoomSuccess
      client3.on('joinRoomSuccess', (room) => {
        expect(room.players).toHaveLength(3);

        // Client 1 starts the game
        client1.emit('startGame', { roomId: roomCode });
      });

      // All clients listen for updateRoom (sent on startGame)
      client1.on('updateRoom', (room) => {
        if (!room.isJoin && room.players.length === 3) {
          states.c1 = room;
          startCount++;
          checkDone();
        }
      });

      client2.on('updateRoom', (room) => {
        if (!room.isJoin && room.players.length === 3) {
          states.c2 = room;
          startCount++;
          checkDone();
        }
      });

      client3.on('updateRoom', (room) => {
        if (!room.isJoin && room.players.length === 3) {
          states.c3 = room;
          startCount++;
          checkDone();
        }
      });

      // Error handler
      [client1, client2, client3].forEach((c) => {
        c.on('errorOccurred', (msg) => {
          clearTimeout(timeout);
          reject(new Error(`Unexpected error: ${msg}`));
        });
        c.on('connect_error', reject);
      });

      // Start the flow: client 1 creates the room
      client1.on('connect', () => {
        client1.emit('createRoom', {
          nickname: 'Alice',
          playerfaction: 'Crimea',
          playermat: '1',
          timer: 300,
        });
      });

      // Connect client 2 and 3 after client 1 connects
      client2.connect();
      client3.connect();
    });
  }, 10000);

  it('rejects join with duplicate faction', () => {
    return new Promise((resolve, reject) => {
      const c1 = createClient();
      const c2 = createClient();
      let roomCode;

      const timeout = setTimeout(() => {
        reject(new Error('timeout'));
      }, 5000);

      c1.on('connect', () => {
        c1.emit('createRoom', {
          nickname: 'Alice',
          playerfaction: 'Crimea',
          playermat: '1',
          timer: 60,
        });
      });

      c1.on('createRoomSuccess', (room) => {
        roomCode = room._id;
        c2.emit('joinRoom', {
          nickname: 'Bob',
          roomId: roomCode,
          playerfaction: 'Crimea', // duplicate faction
          playermat: '2',
        });
      });

      c2.on('errorOccurred', (msg) => {
        clearTimeout(timeout);
        expect(msg).toContain('already picked');
        c1.disconnect();
        c2.disconnect();
        resolve();
      });

      c2.on('connect_error', reject);
      c2.connect();
    });
  }, 8000);

  it('rejects startGame with single player', () => {
    return new Promise((resolve, reject) => {
      const c1 = createClient();

      const timeout = setTimeout(() => {
        reject(new Error('timeout'));
      }, 5000);

      c1.on('connect', () => {
        c1.emit('createRoom', {
          nickname: 'Alice',
          playerfaction: 'Crimea',
          playermat: '1',
          timer: 60,
        });
      });

      c1.on('createRoomSuccess', (room) => {
        c1.emit('startGame', { roomId: room._id });
      });

      c1.on('errorOccurred', (msg) => {
        clearTimeout(timeout);
        expect(msg).toContain('Automa');
        c1.disconnect();
        resolve();
      });

      c1.on('connect_error', reject);
    });
  }, 8000);
});
