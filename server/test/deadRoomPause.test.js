// SPDX-License-Identifier: MIT

import { afterAll, afterEach, beforeAll, describe, expect, it } from 'vitest';
import { once } from 'node:events';
import http from 'node:http';
import { Server } from 'socket.io';
import { io as Client } from 'socket.io-client';
import { registerHandlers, shutdownTimers } from '../src/handlers.js';
import { RoomStore } from '../src/roomStore.js';
import * as timerEngine from '../src/timerEngine.js';

const testPort = 3996;
let httpServer;
let io;
let store;
const clients = [];

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

afterEach(() => {
  while (clients.length > 0) clients.pop().disconnect();
});

async function connect() {
  const client = Client(`http://localhost:${testPort}`, {
    transports: ['websocket'],
  });
  clients.push(client);
  await once(client, 'connect');
  return client;
}

async function createRoom(client) {
  const success = once(client, 'createRoomSuccess');
  client.emit('createRoom', {
    nickname: 'Alice',
    playerfaction: 'Crimea',
    playermat: '1',
    timer: 300,
  });
  const [room] = await success;
  return room;
}

async function joinRoom(client, roomCode) {
  const success = once(client, 'joinRoomSuccess');
  client.emit('joinRoom', {
    nickname: 'Bob',
    roomId: roomCode,
    playerfaction: 'Saxony',
    playermat: '2',
  });
  await success;
}

async function startedGame() {
  const alice = await connect();
  const bob = await connect();
  const room = await createRoom(alice);
  await joinRoom(bob, room._id);

  const update = once(bob, 'updateRoom');
  alice.emit('startGame', { roomId: room._id });
  const [started] = await update;
  expect(started.turn.nickname).toBe('Alice');
  expect(timerEngine.isActive(room._id)).toBe(true);

  return { alice, bob, roomCode: room._id };
}

async function disconnectFromServer(client) {
  const serverSocket = io.sockets.sockets.get(client.id);
  expect(serverSocket).toBeDefined();
  const disconnected = once(serverSocket, 'disconnect');
  client.disconnect();
  await disconnected;
}

describe('dead-room timer pause (T4.9b)', () => {
  it('pauses after expiry makes a disconnected player the turn owner and the last player leaves', async () => {
    const { alice, bob, roomCode } = await startedGame();

    await disconnectFromServer(bob);
    const room = store.get(roomCode);
    expect(room.isPaused).toBe(false);
    expect(room.players.find((player) => player.nickname === 'Bob').connected).toBe(false);

    room.turn.remainingSec = 1;
    const nextTurn = once(alice, 'newTurn');
    const [updated] = await nextTurn;
    expect(updated.turn.nickname).toBe('Bob');
    expect(timerEngine.isActive(roomCode)).toBe(true);

    await disconnectFromServer(alice);

    expect(room.players.every((player) => !player.connected)).toBe(true);
    expect(room.isPaused).toBe(true);
    expect(timerEngine.isActive(roomCode)).toBe(false);
  }, 5000);

  it('pauses when both players disconnect without a turn change', async () => {
    const { alice, bob, roomCode } = await startedGame();

    await disconnectFromServer(bob);
    expect(store.get(roomCode).isPaused).toBe(false);

    await disconnectFromServer(alice);

    const room = store.get(roomCode);
    expect(room.players.every((player) => !player.connected)).toBe(true);
    expect(room.isPaused).toBe(true);
    expect(timerEngine.isActive(roomCode)).toBe(false);
  });
});
