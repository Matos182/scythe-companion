// SPDX-License-Identifier: MIT

import { describe, it, expect, beforeAll, afterAll, afterEach } from 'vitest';
import { once } from 'node:events';
import http from 'node:http';
import { Server } from 'socket.io';
import { io as Client } from 'socket.io-client';
import { RoomStore } from '../src/roomStore.js';
import { registerHandlers, shutdownTimers } from '../src/handlers.js';

/**
 * Room-action authorization tests (T4.7c, DECISIONS R2).
 *
 * Before T4.7c any socket could drive any room: startGame / turn /
 * pause / resume trusted the payload's roomId blindly.  Now a socket
 * must be SEATED in the room it targets (server-stamped
 * socket.data.roomCode, not the client claim), and `turn` additionally
 * requires turn ownership.
 *
 * Covered here:
 *  1. non-member startGame → AUTH_NOT_IN_ROOM, room untouched
 *  2. seated member acting on a DIFFERENT room → AUTH_NOT_IN_ROOM
 *  3. member, wrong-turn TURN → STATE_NOT_YOUR_TURN
 *  4. correct-turn TURN passes (happy path intact)
 *  5. non-member pause → AUTH_NOT_IN_ROOM, room not paused
 *  6. non-member resume → AUTH_NOT_IN_ROOM, room stays paused
 */

const testPort = 3995;
let httpServer;
let io;
let store;

/** Live clients, disconnected after each test. */
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

/** Connect a client and wait for the connection to be established. */
async function connect() {
  const client = Client(`http://localhost:${testPort}`, {
    transports: ['websocket'],
  });
  clients.push(client);
  await once(client, 'connect');
  return client;
}

/** Create a room; resolves with the wire room. */
async function createRoom(client, over = {}) {
  const success = once(client, 'createRoomSuccess');
  client.emit('createRoom', {
    nickname: 'Alice',
    playerfaction: 'Crimea',
    playermat: '1',
    timer: 300,
    ...over,
  });
  const [room] = await success;
  return room;
}

/** Join a room; resolves with the wire room. */
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

/** Emit an action and resolve with the error envelope it triggers. */
async function emitExpectingError(client, event, payload) {
  const error = once(client, 'errorOccurred');
  client.emit(event, payload);
  const [envelope] = await error;
  return envelope;
}

/**
 * Set up a started 2-player game.  Alice (Crimea, mat 1) is the
 * creator and — per the faction wheel — the first turn player.
 */
async function startedGame() {
  const alice = await connect();
  const bob = await connect();
  const room = await createRoom(alice);
  await joinRoom(bob, room._id);
  const update = once(bob, 'updateRoom');
  alice.emit('startGame', { roomId: room._id });
  const [started] = await update;
  expect(started.isJoin).toBe(false);
  expect(started.turn.nickname).toBe('Alice');
  return { alice, bob, roomCode: room._id };
}

describe('room-action authorization (T4.7c)', () => {
  it('rejects startGame from a socket that never joined the room', async () => {
    const alice = await connect();
    const bob = await connect();
    const stranger = await connect();
    const room = await createRoom(alice);
    await joinRoom(bob, room._id);

    const err = await emitExpectingError(stranger, 'startGame', { roomId: room._id });
    expect(err.code).toBe('AUTH_NOT_IN_ROOM');

    // Room untouched — still open, game not started.
    expect(store.get(room._id).isJoin).toBe(true);
  });

  it('rejects a seated member acting on a DIFFERENT room', async () => {
    const alice = await connect();
    const carol = await connect();
    const roomA = await createRoom(alice);
    const roomB = await createRoom(carol, {
      nickname: 'Carol', playerfaction: 'Polania', playermat: '3',
    });
    expect(roomB._id).not.toBe(roomA._id);

    // Alice is seated in room A; targeting room B must fail even
    // though she is a legitimate player somewhere.
    const err = await emitExpectingError(alice, 'startGame', { roomId: roomB._id });
    expect(err.code).toBe('AUTH_NOT_IN_ROOM');
    expect(store.get(roomB._id).isJoin).toBe(true);
  });

  it('rejects TURN from a member when it is not their turn', async () => {
    const { bob, roomCode } = await startedGame();

    const err = await emitExpectingError(bob, 'turn', { roomId: roomCode });
    expect(err.code).toBe('STATE_NOT_YOUR_TURN');

    // Still Alice's turn.
    expect(store.get(roomCode).turn.nickname).toBe('Alice');
  });

  it('lets the current turn player pass (happy path intact)', async () => {
    const { alice, bob, roomCode } = await startedGame();

    const newTurn = once(bob, 'newTurn');
    alice.emit('turn', { roomId: roomCode });
    const [room] = await newTurn;
    expect(room.turn.nickname).toBe('Bob');
  });

  it('rejects pause from a non-member and leaves the timer running', async () => {
    const { roomCode } = await startedGame();
    const stranger = await connect();

    const err = await emitExpectingError(stranger, 'pause', { roomId: roomCode });
    expect(err.code).toBe('AUTH_NOT_IN_ROOM');
    expect(store.get(roomCode).isPaused).toBe(false);
  });

  it('rejects resume from a non-member and keeps the game paused', async () => {
    const { alice, bob, roomCode } = await startedGame();

    // A member pauses legitimately first.
    const pausedUpdate = once(bob, 'updateRoom');
    alice.emit('pause', { roomId: roomCode });
    const [paused] = await pausedUpdate;
    expect(paused.isPaused).toBe(true);

    const stranger = await connect();
    const err = await emitExpectingError(stranger, 'toContinue', { roomId: roomCode });
    expect(err.code).toBe('AUTH_NOT_IN_ROOM');
    expect(store.get(roomCode).isPaused).toBe(true);
  });
});
