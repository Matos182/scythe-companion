// SPDX-License-Identifier: MIT

/**
 * HTTP + Socket.io entry point (new server, T2.0+).
 *
 * The old `server/index.js` (MongoDB + socket.io v2) was deleted in T2.1
 * — the new server is now authoritative for createRoom/joinRoom/startGame.
 * Timer/turn/pause/resume handlers land in T2.2.
 *
 * T2.4 hardening: structured logging (pino), expanded /healthz, rate
 * limiting at the connection layer, payload validation on every event.
 */

import 'dotenv/config';
import express from 'express';
import http from 'node:http';
import { Server } from 'socket.io';
import { port, corsOrigin, maxRooms } from './config.js';
import { RoomStore } from './roomStore.js';
import { registerHandlers, shutdownTimers } from './handlers.js';
import { PROTOCOL_VERSION } from './protocol.js';
import * as timerEngine from './timerEngine.js';
import logger from './logger.js';

const app = express();
app.use(express.json());

const startedAt = Date.now();

// ── /healthz — used by Docker healthcheck + reverse proxy ──────────
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

const httpServer = http.createServer(app);

const io = new Server(httpServer, {
  cors: { origin: corsOrigin },
});

// In-memory store (D2) + TTL sweeper.
const store = new RoomStore();
store.startSweeper();

// Register socket handlers (with max-rooms cap).
registerHandlers(io, store, { maxRooms });

httpServer.listen(port, () => {
  logger.info(
    { port, corsOrigin, protocolVersion: PROTOCOL_VERSION, maxRooms },
    'server listening',
  );
});

// Graceful shutdown: stop all timer intervals + close the sweeper.
process.on('SIGTERM', () => {
  logger.info('SIGTERM — shutting down');
  shutdownTimers();
  store.stopSweeper();
  httpServer.close();
});
process.on('SIGINT', () => {
  logger.info('SIGINT — shutting down');
  shutdownTimers();
  store.stopSweeper();
  httpServer.close();
});

export { app, httpServer, io, store };
