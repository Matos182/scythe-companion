// SPDX-License-Identifier: MIT

import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import http from 'node:http';
import { Server } from 'socket.io';
import { io as Client } from 'socket.io-client';
import express from 'express';
import { RoomStore } from '../src/roomStore.js';
import { registerHandlers, shutdownTimers } from '../src/handlers.js';
import { PROTOCOL_VERSION } from '../src/protocol.js';
import * as timerEngine from '../src/timerEngine.js';
import { maxRooms } from '../src/config.js';

/**
 * Hardening integration tests (T2.4 done-criteria):
 * Malformed payloads return error envelopes, never crash the server.
 * Also verifies the /healthz expansion (room count, uptime, activeTimers).
 */

const testPort = 3994;
let httpServer;
let io;
let store;
const startedAt = Date.now();

beforeAll(() => {
  const app = express();
  app.disable('x-powered-by');
  app.get('/healthz', (_req, res) => {
    res.json({
      status: 'ok',
      protocolVersion: PROTOCOL_VERSION,
      uptime: Math.floor((Date.now() - startedAt) / 1000),
      rooms: store ? store.rooms.size : 0,
      activeTimers: timerEngine.activeCount(),
      maxRooms,
    });
  });
  httpServer = http.createServer(app);
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

describe('hardening: malformed payloads', () => {
  it('createRoom with null payload returns error envelope, does not crash', () => {
    return new Promise((resolve, reject) => {
      const c = createClient();
      const timeout = setTimeout(() => reject(new Error('timeout')), 5000);

      c.on('connect', () => {
        c.emit('createRoom', null);
      });

      c.on('errorOccurred', (err) => {
        clearTimeout(timeout);
        expect(err).toHaveProperty('code');
        expect(err).toHaveProperty('message');
        expect(err.code).toBe('VAL_BAD_PAYLOAD');
        c.disconnect();
        resolve();
      });

      c.on('connect_error', reject);
    });
  }, 8000);

  it('createRoom with invalid faction returns error envelope', () => {
    return new Promise((resolve, reject) => {
      const c = createClient();
      const timeout = setTimeout(() => reject(new Error('timeout')), 5000);

      c.on('connect', () => {
        c.emit('createRoom', {
          nickname: 'Alice',
          playerfaction: 'BogusFaction',
          playermat: '1',
          timer: 300,
        });
      });

      c.on('errorOccurred', (err) => {
        clearTimeout(timeout);
        expect(err.code).toBe('VAL_INVALID_FACTION');
        c.disconnect();
        resolve();
      });

      c.on('connect_error', reject);
    });
  }, 8000);

  it('joinRoom with missing roomId returns error envelope', () => {
    return new Promise((resolve, reject) => {
      const c = createClient();
      const timeout = setTimeout(() => reject(new Error('timeout')), 5000);

      c.on('connect', () => {
        c.emit('joinRoom', {
          nickname: 'Bob',
          roomId: '',
          playerfaction: 'Saxony',
          playermat: '2',
        });
      });

      c.on('errorOccurred', (err) => {
        clearTimeout(timeout);
        expect(err.code).toBe('VAL_MISSING_ROOM_ID');
        c.disconnect();
        resolve();
      });

      c.on('connect_error', reject);
    });
  }, 8000);

  it('startGame with undefined payload returns error envelope', () => {
    return new Promise((resolve, reject) => {
      const c = createClient();
      const timeout = setTimeout(() => reject(new Error('timeout')), 5000);

      c.on('connect', () => {
        c.emit('startGame', undefined);
      });

      c.on('errorOccurred', (err) => {
        clearTimeout(timeout);
        expect(err.code).toBe('VAL_BAD_PAYLOAD');
        c.disconnect();
        resolve();
      });

      c.on('connect_error', reject);
    });
  }, 8000);

  it('server survives malformed payloads and handles a valid request after', () => {
    return new Promise((resolve, reject) => {
      const c = createClient();
      const timeout = setTimeout(() => reject(new Error('timeout')), 8000);
      let gotError = false;

      c.on('connect', () => {
        // Send garbage first.
        c.emit('createRoom', { totallyWrong: true });
      });

      c.on('errorOccurred', (err) => {
        expect(err).toHaveProperty('code');
        expect(err).toHaveProperty('message');
        gotError = true;

        // Now send a valid request — server should still work.
        c.emit('createRoom', {
          nickname: 'Alice',
          playerfaction: 'Crimea',
          playermat: '1',
          timer: 300,
        });
      });

      c.on('createRoomSuccess', (room) => {
        clearTimeout(timeout);
        expect(gotError).toBe(true);
        expect(room.players).toHaveLength(1);
        expect(room.players[0].nickname).toBe('Alice');
        c.disconnect();
        resolve();
      });

      c.on('connect_error', reject);
    });
  }, 12000);
});

describe('hardening: /healthz expansion', () => {
  it('returns uptime, rooms, activeTimers, and protocolVersion', async () => {
    const res = await fetch(`http://localhost:${testPort}/healthz`);
    expect(res.status).toBe(200);
    const body = await res.json();
    expect(body.status).toBe('ok');
    expect(body).toHaveProperty('uptime');
    expect(body).toHaveProperty('rooms');
    expect(body).toHaveProperty('activeTimers');
    expect(body).toHaveProperty('protocolVersion');
    expect(body).toHaveProperty('maxRooms');
    expect(typeof body.uptime).toBe('number');
    expect(body.uptime).toBeGreaterThanOrEqual(0);
    expect(res.headers.get('x-powered-by')).toBeNull();
  });
});
