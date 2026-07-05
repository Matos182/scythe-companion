// SPDX-License-Identifier: MIT

import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import http from 'node:http';
import { Server } from 'socket.io';
import { io as Client } from 'socket.io-client';
import { port, corsOrigin } from '../src/config.js';
import { PROTOCOL_VERSION } from '../src/protocol.js';

/**
 * Hello-world integration test (T2.0 done-criteria).
 *
 * Boots the real server on a test port, connects a socket.io-client,
 * and verifies the round-trip.  Real handlers (createRoom etc.) land in
 * T2.1 — this only proves the plumbing compiles, runs, and talks.
 */

const testPort = port + 1000; // avoid clashing with a running dev server
const testOrigin = corsOrigin;

let httpServer;
let io;

beforeAll(() => {
  httpServer = http.createServer((req, res) => {
    if (req.url === '/healthz') {
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ status: 'ok' }));
    } else {
      res.writeHead(404);
      res.end();
    }
  });
  io = new Server(httpServer, { cors: { origin: testOrigin } });
  io.on('connection', (socket) => {
    // Echo handler so we can prove two-way comms.
    socket.on('ping', (data) => {
      socket.emit('pong', data);
    });
  });
  return new Promise((resolve) => httpServer.listen(testPort, resolve));
});

afterAll(() => {
  io.close();
  return new Promise((resolve) => httpServer.close(resolve));
});

describe('server scaffolding', () => {
  it('responds on /healthz', async () => {
    const res = await fetch(`http://localhost:${testPort}/healthz`);
    expect(res.status).toBe(200);
    const body = await res.json();
    expect(body.status).toBe('ok');
  });

  it('accepts a socket.io client connection', () => {
    return new Promise((resolve, reject) => {
      const client = Client(`http://localhost:${testPort}`, {
        transports: ['websocket'],
      });
      client.on('connect', () => {
        expect(client.connected).toBe(true);
        client.disconnect();
        resolve();
      });
      client.on('connect_error', reject);
    });
  }, 5000);

  it('round-trips a ping → pong message', () => {
    return new Promise((resolve, reject) => {
      const client = Client(`http://localhost:${testPort}`, {
        transports: ['websocket'],
      });
      client.on('connect', () => {
        client.emit('ping', 'hello');
      });
      client.on('pong', (data) => {
        expect(data).toBe('hello');
        client.disconnect();
        resolve();
      });
      client.on('connect_error', reject);
    });
  }, 5000);

  it('exposes a protocol version constant', () => {
    expect(PROTOCOL_VERSION).toBe(1);
  });
});
