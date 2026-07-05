// SPDX-License-Identifier: MIT

/**
 * HTTP + Socket.io entry point (new server, T2.0+).
 *
 * The old `server/index.js` (MongoDB + socket.io v2) was deleted in T2.1
 * — the new server is now authoritative for createRoom/joinRoom/startGame.
 * Timer/turn/pause/resume handlers land in T2.2.
 */

import 'dotenv/config';
import express from 'express';
import http from 'node:http';
import { Server } from 'socket.io';
import { port, corsOrigin } from './config.js';
import { RoomStore } from './roomStore.js';
import { registerHandlers, shutdownTimers } from './handlers.js';
import { PROTOCOL_VERSION } from './protocol.js';

const app = express();
app.use(express.json());

// Minimal health endpoint (T2.4 expands with rate-limit / structured logs).
app.get('/healthz', (_req, res) => {
  res.json({ status: 'ok', protocolVersion: PROTOCOL_VERSION });
});

const httpServer = http.createServer(app);

const io = new Server(httpServer, {
  cors: { origin: corsOrigin },
});

// In-memory store (D2) + TTL sweeper.
const store = new RoomStore();
store.startSweeper();

// Register socket handlers.
registerHandlers(io, store);

httpServer.listen(port, () => {
  console.log(`[server] listening on :${port} (CORS origin: ${corsOrigin}, protocol v${PROTOCOL_VERSION})`);
});

// Graceful shutdown: stop all timer intervals + close the sweeper.
process.on('SIGTERM', () => {
  shutdownTimers();
  store.stopSweeper();
  httpServer.close();
});
process.on('SIGINT', () => {
  shutdownTimers();
  store.stopSweeper();
  httpServer.close();
});

export { app, httpServer, io, store };
