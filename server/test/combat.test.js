// SPDX-License-Identifier: MIT

/**
 * T5.7 — Combat pause.
 *
 * Current-turn player starts a table fight: timer pauses, room.pauseReason
 * is 'combat', and rejoin of the fighter must NOT auto-resume (unlike a
 * disconnect pause). Ordinary pause stays reason-less.
 */

import { describe, it, expect, beforeAll, afterAll, afterEach, vi } from 'vitest';
import { once } from 'node:events';
import http from 'node:http';
import { Server } from 'socket.io';
import { io as Client } from 'socket.io-client';
import { RoomStore } from '../src/roomStore.js';
import { registerHandlers, shutdownTimers } from '../src/handlers.js';
import * as timerEngine from '../src/timerEngine.js';

const testPort = 3998;
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

async function createRoom(client, over = {}) {
  const success = once(client, 'createRoomSuccess');
  client.emit('createRoom', {
    nickname: 'Alice',
    playerfaction: 'Crimea',
    playermat: '1',
    timer: 30,
    ...over,
  });
  const [room] = await success;
  return room;
}

async function joinRoom(client, roomId, over = {}) {
  const success = once(client, 'joinRoomSuccess');
  client.emit('joinRoom', {
    nickname: 'Bob',
    roomId,
    playerfaction: 'Saxony',
    playermat: '2',
    ...over,
  });
  const [room] = await success;
  return room;
}

function waitForRoom(client, predicate) {
  return new Promise((resolve) => {
    const onUpdate = (room) => {
      if (predicate(room)) {
        client.off('updateRoom', onUpdate);
        resolve(room);
      }
    };
    client.on('updateRoom', onUpdate);
  });
}

async function startGame(client, roomId) {
  const started = waitForRoom(client, (room) => room.isJoin === false);
  client.emit('startGame', { roomId });
  return started;
}

async function emitExpectingError(client, event, payload) {
  const error = once(client, 'errorOccurred');
  client.emit(event, payload);
  const [envelope] = await error;
  return envelope;
}

async function startedTwoPlayerGame() {
  const alice = await connect();
  const bob = await connect();
  const created = await createRoom(alice);
  await joinRoom(bob, created._id);
  const started = await startGame(alice, created._id);
  return { alice, bob, room: started };
}

describe('T5.7 combat pause', () => {
  it('non-current-turn combat → STATE_NOT_YOUR_TURN, room not combat', async () => {
    const { alice, bob, room } = await startedTwoPlayerGame();
    const err = await emitExpectingError(bob, 'combat', { roomId: room._id });
    expect(err.code).toBe('STATE_NOT_YOUR_TURN');
    const live = store.get(room._id);
    expect(live.pauseReason).not.toBe('combat');
    expect(live.isPaused).toBe(false);
    // Alice never emitted combat; her socket should stay quiet.
    expect(alice.connected).toBe(true);
  });

  it('non-member combat → AUTH_NOT_IN_ROOM', async () => {
    const { room } = await startedTwoPlayerGame();
    const stranger = await connect();
    const err = await emitExpectingError(stranger, 'combat', { roomId: room._id });
    expect(err.code).toBe('AUTH_NOT_IN_ROOM');
    expect(store.get(room._id).pauseReason).not.toBe('combat');
  });

  it('current-turn combat pauses the clock with pauseReason combat', async () => {
    const { alice, room } = await startedTwoPlayerGame();
    const remainingBefore = store.get(room._id).turn.remainingSec;
    expect(timerEngine.isActive(room._id)).toBe(true);

    const combated = waitForRoom(alice, (r) => r.pauseReason === 'combat');
    alice.emit('combat', { roomId: room._id });
    const wire = await combated;

    expect(wire.isPaused).toBe(true);
    expect(wire.pauseReason).toBe('combat');
    expect(timerEngine.isActive(room._id)).toBe(false);
    expect(store.get(room._id).turn.remainingSec).toBe(remainingBefore);

    vi.useFakeTimers();
    vi.advanceTimersByTime(3000);
    expect(store.get(room._id).turn.remainingSec).toBe(remainingBefore);
    vi.useRealTimers();
  });

  it('toContinue from current-turn player clears pauseReason and resumes', async () => {
    const { alice, room } = await startedTwoPlayerGame();
    const combated = waitForRoom(alice, (r) => r.pauseReason === 'combat');
    alice.emit('combat', { roomId: room._id });
    await combated;

    const resumed = waitForRoom(alice, (r) => r.isPaused === false);
    alice.emit('toContinue', { roomId: room._id });
    const wire = await resumed;

    expect(wire.isPaused).toBe(false);
    expect(wire.pauseReason).toBeUndefined();
    expect(store.get(room._id).pauseReason == null).toBe(true);
    expect(timerEngine.isActive(room._id)).toBe(true);
  });

  it('ordinary pause does not set pauseReason to combat', async () => {
    const { alice, room } = await startedTwoPlayerGame();
    const paused = waitForRoom(alice, (r) => r.isPaused === true);
    alice.emit('pause', { roomId: room._id });
    const wire = await paused;

    expect(wire.isPaused).toBe(true);
    expect(wire.pauseReason).toBeUndefined();
    expect(store.get(room._id).pauseReason == null).toBe(true);
  });

  it('rejoin after disconnect pause still auto-resumes', async () => {
    const { alice, bob, room } = await startedTwoPlayerGame();
    const aliceId = room.turn._id;
    expect(room.turn.nickname).toBe('Alice');

    const paused = waitForRoom(bob, (r) => r.isPaused === true);
    alice.disconnect();
    const pausedWire = await paused;
    expect(pausedWire.isPaused).toBe(true);
    expect(pausedWire.pauseReason).toBeUndefined();

    const aliceRejoined = await connect();
    const success = once(aliceRejoined, 'joinRoomSuccess');
    aliceRejoined.emit('rejoinRoom', {
      roomCode: room._id,
      playerId: aliceId,
    });
    const [wire] = await success;
    expect(wire.isPaused).toBe(false);
    expect(wire.pauseReason).toBeUndefined();
    expect(timerEngine.isActive(room._id)).toBe(true);
  });

  it('rejoin after combat pause does not auto-resume', async () => {
    const { alice, bob, room } = await startedTwoPlayerGame();
    const aliceId = room.turn._id;

    const combated = waitForRoom(bob, (r) => r.pauseReason === 'combat');
    alice.emit('combat', { roomId: room._id });
    const combatWire = await combated;
    expect(combatWire.pauseReason).toBe('combat');

    const disconnected = once(bob, 'updateRoom');
    alice.disconnect();
    await disconnected;

    const aliceRejoined = await connect();
    const success = once(aliceRejoined, 'joinRoomSuccess');
    aliceRejoined.emit('rejoinRoom', {
      roomCode: room._id,
      playerId: aliceId,
    });
    const [wire] = await success;
    expect(wire.isPaused).toBe(true);
    expect(wire.pauseReason).toBe('combat');
    expect(timerEngine.isActive(room._id)).toBe(false);
  });
});
