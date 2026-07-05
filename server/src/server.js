// SPDX-License-Identifier: MIT

/**
 * HTTP + Socket.io entry point (new server, T2.0+).
 *
 * The old `server/index.js` (MongoDB + socket.io v2) is kept untouched
 * and runnable via `npm run start:legacy` until T2.3 reaches parity.
 * This file is the authoritative server going forward.
 */

import 'dotenv/config';
import express from 'express';
import http from 'node:http';
import { Server } from 'socket.io';
import { port, corsOrigin } from './config.js';

const app = express();
app.use(express.json());

// Minimal health endpoint (T2.4 expands with rate-limit / structured logs).
app.get('/healthz', (_req, res) => {
  res.json({ status: 'ok' });
});

const httpServer = http.createServer(app);

const io = new Server(httpServer, {
  cors: { origin: corsOrigin },
});

// Placeholder connection handler — real handlers land in T2.1.
io.on('connection', (socket) => {
  console.log(`[server] client connected: ${socket.id}`);
  socket.on('disconnect', () => {
    console.log(`[server] client disconnected: ${socket.id}`);
  });
});

httpServer.listen(port, () => {
  console.log(`[server] listening on :${port} (CORS origin: ${corsOrigin})`);
});

export { app, httpServer, io };
