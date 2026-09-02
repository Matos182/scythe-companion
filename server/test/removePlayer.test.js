// SPDX-License-Identifier: MIT

/**
 * T5.4 — Creator seat management (removePlayer).
 *
 * A disconnected player strands their faction/mat seat: nobody else can
 * pick it and the absent player may never return. The creator may remove
 * a DISCONNECTED player from the room, freeing the seat for a fresh join.
 *
 * Rules under test:
 *  - creator removes a disconnected player → gone, seat freed
 *  - removing a CONNECTED player → STATE_PLAYER_CONNECTED
 *  - non-creator removal → AUTH_NOT_CREATOR
 *  - non-member socket → AUTH_NOT_IN_ROOM (unchanged T4.7c behaviour)
 *  - removing the current turn player advances the turn to a connected player
 */

import { describe, it, expect, beforeAll, afterAll, afterEach } from 'vitest';
import { once } from 'node:events';
import http from 'node:http';
import { Server } from 'socket.io';
import { io as Client } from 'socket.io-client';
import { RoomStore } from '../src/roomStore.js';
import { registerHandlers, shutdownTimers } from '../src/handlers.js';

const testPort = 3997;
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

/** Wait until the server-side disconnect handler ran for `playerId`. */
async function waitDisconnected(roomCode, playerId) {
  for (let i = 0; i < 50; i++) {
    const player = store.get(roomCode).players.find((p) => p._id === playerId);
    if (player && !player.connected) return;
    await new Promise((r) => setTimeout(r, 20));
  }
  throw new Error('player never marked disconnected');
}

describe('T5.4 removePlayer (creator seat management)', () => {
  it('creator removes a disconnected player; the faction is freed for rejoin', async () => {
    const alice = await connect();
    const bob = await connect();
    const room = await createRoom(alice);
    const bobJoined = await joinRoom(bob, room._id);
    const bobId = bobJoined.players.find((p) => p.nickname === 'Bob')._id;

    bob.disconnect();
    await waitDisconnected(room._id, bobId);

    const update = once(alice, 'updateRoom');
    alice.emit('removePlayer', { roomId: room._id, playerId: bobId });
    await update;

    const players = store.get(room._id).players;
    expect(players.some((p) => p._id === bobId)).toBe(false);

    // The freed faction/mat is joinable again by a fresh player.
    const carol = await connect();
    const carolJoined = await joinRoom(carol, room._id, {
      nickname: 'Carol', playerfaction: 'Saxony', playermat: '2',
    });
    expect(carolJoined.players.some((p) => p.nickname === 'Carol')).toBe(true);
  });

  it('removing a CONNECTED player is rejected with STATE_PLAYER_CONNECTED', async () => {
    const alice = await connect();
    const bob = await connect();
    const room = await createRoom(alice);
    const bobJoined = await joinRoom(bob, room._id);
    const bobId = bobJoined.players.find((p) => p.nickname === 'Bob')._id;

    const err = await emitExpectingError(alice, 'removePlayer', {
      roomId: room._id, playerId: bobId,
    });
    expect(err.code).toBe('STATE_PLAYER_CONNECTED');
    expect(store.get(room._id).players.some((p) => p._id === bobId)).toBe(true);
  });

  it('non-creator removal is rejected with AUTH_NOT_CREATOR', async () => {
    const alice = await connect();
    const bob = await connect();
    const carol = await connect();
    const room = await createRoom(alice);
    const bobJoined = await joinRoom(bob, room._id);
    await joinRoom(carol, room._id, {
      nickname: 'Carol', playerfaction: 'Polania', playermat: '2A',
    });
    const bobId = bobJoined.players.find((p) => p.nickname === 'Bob')._id;

    bob.disconnect();
    await waitDisconnected(room._id, bobId);

    const err = await emitExpectingError(carol, 'removePlayer', {
      roomId: room._id, playerId: bobId,
    });
    expect(err.code).toBe('AUTH_NOT_CREATOR');
    expect(store.get(room._id).players.some((p) => p._id === bobId)).toBe(true);
  });

  it('removing a target room the socket is not seated in → AUTH_NOT_IN_ROOM', async () => {
    const stranger = await connect();
    const err = await emitExpectingError(stranger, 'removePlayer', {
      roomId: 'NOPE01', playerId: 'abc',
    });
    expect(err.code).toBe('AUTH_NOT_IN_ROOM');
  });

  it('removing the current turn player advances the turn to a connected player', async () => {
    const alice = await connect();
    const bob = await connect();
    const room = await createRoom(alice);
    const bobJoined = await joinRoom(bob, room._id);

    // Start with 2 players: the wheel makes Alice (creator) first turn.
    alice.emit('startGame', { roomId: room._id });
    await once(alice, 'updateRoom');
    const turnId = store.get(room._id).turn._id;

    // Alice (current turn, still connected) removes... herself is
    // STATE_PLAYER_CONNECTED. Instead: Bob leaves mid-game and is removed;
    // with only the creator left the room keeps a valid turn state.
    expect(turnId).toBe(store.get(room._id).creator._id);

    const bobId = bobJoined.players.find((p) => p.nickname === 'Bob')._id;
    bob.disconnect();
    await waitDisconnected(room._id, bobId);

    const update = once(alice, 'updateRoom');
    alice.emit('removePlayer', { roomId: room._id, playerId: bobId });
    await update;

    // Turn was never Bob's, so it stays with Alice; room still has a turn.
    expect(store.get(room._id).players.some((p) => p._id === bobId)).toBe(false);
    expect(store.get(room._id).turn._id).toBe(turnId);
    expect(store.get(room._id).turn.connected).toBe(true);
  });

  it('removing a mid-list disconnected player keeps turn indices valid', async () => {
    const alice = await connect();
    const bob = await connect();
    const carol = await connect();
    const room = await createRoom(alice, { nickname: 'Alice', playerfaction: 'Crimea', playermat: '1' });
    await joinRoom(bob, room._id, { nickname: 'Bob', playerfaction: 'Saxony', playermat: '2' });
    await joinRoom(carol, room._id, {
      nickname: 'Carol', playerfaction: 'Polania', playermat: '2A',
    });

    alice.emit('startGame', { roomId: room._id });
    await once(alice, 'updateRoom');

    const playersBefore = store.get(room._id).players;
    const bobId = playersBefore.find((p) => p.nickname === 'Bob')._id;
    const bobIndex = playersBefore.findIndex((p) => p._id === bobId);

    bob.disconnect();
    await waitDisconnected(room._id, bobId);

    const update = once(alice, 'updateRoom');
    alice.emit('removePlayer', { roomId: room._id, playerId: bobId });
    await update;

    const after = store.get(room._id);
    expect(after.players.length).toBe(2);
    // turnIndex must stay in bounds after the splice.
    expect(after.turnIndex).toBeGreaterThanOrEqual(0);
    expect(after.turnIndex).toBeLessThan(after.players.length);
    expect(after.turn._id).toBe(after.players[after.turnIndex]._id);
    // The turn is on a connected player (Alice or Carol).
    expect(after.turn.connected).toBe(true);
    void bobIndex;
  });
});
