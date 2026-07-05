# Scythe Companion — Wire Protocol v1

**Protocol version:** 1  
**Transport:** socket.io (client 3.x ↔ server 4.x)  
**Last updated:** 2026-07-05 (T2.3)

> A `protocolVersion` field is included in the `/healthz` HTTP response
> and in the handshake. If the client's expected version differs, it must
> refuse to connect and show an upgrade prompt. Bump the version when any
> event name or payload shape changes.

---

## Room shape (server → client)

All `createRoomSuccess`, `joinRoomSuccess`, `updateRoom`, and `newTurn`
events carry a serialized room object:

```json
{
  "_id": "AB3KMN",
  "isJoin": true,
  "turnIndex": 0,
  "totalTurns": 1,
  "isPaused": false,
  "players": [
    {
      "_id": "550e8400-e29b-41d4-a716-446655440000",
      "nickname": "Alice",
      "socketID": "xW123...",
      "playerfaction": "Crimea",
      "playermat": "1",
      "timer": 300,
      "remainingSec": 300
    }
  ],
  "turn": { /* same shape as a player */ },
  "creator": { /* same shape as a player */ }
}
```

| Field | Type | Description |
|---|---|---|
| `_id` | string | 6-char room code (unambiguous alphabet) |
| `isJoin` | boolean | Room open for joining? |
| `turnIndex` | int | Index into `players[]` for current turn |
| `totalTurns` | int | Round counter (starts at 1) |
| `isPaused` | boolean | Game paused? |
| `players[]` | array | Seated players, in turn order after faction wheel |
| `turn` | object | Current player (reference into players[]) |
| `creator` | object | Room creator |

### Player sub-document

| Field | Type | Description |
|---|---|---|
| `_id` | string (UUID) | Server-minted playerId (D4) |
| `nickname` | string | Display name |
| `socketID` | string | Current socket.io id (updated on rejoin) |
| `playerfaction` | string | One of: Crimea, Saxony, Polania, Albion, Nordic, Rusviet, Togawa |
| `playermat` | string | One of: 1, 2, 2A, 3, 3A, 4, 5 |
| `timer` | int | Per-turn allowance in seconds (config, A6) |
| `remainingSec` | int | Live countdown value (A6: distinct from `timer`) |
| `connected` | boolean | Presence flag — is the player's socket connected? (T2.3) |

---

## Events

### Client → Server

#### `createRoom`

Creates a new room; the emitting player becomes the creator.

```json
{
  "nickname": "Alice",
  "playerfaction": "Crimea",
  "playermat": "1",
  "timer": 300
}
```

**Server response:** `createRoomSuccess` (to the room) with the full room object.

**Errors:** `errorOccurred` — "Please enter a valid nickname!"

---

#### `joinRoom`

Joins an existing room by code.

```json
{
  "nickname": "Bob",
  "roomId": "AB3KMN",
  "playerfaction": "Saxony",
  "playermat": "2"
}
```

**Server response:**
- `updateRoom` (to the room) with updated room state.
- `joinRoomSuccess` (to the joining socket) with the room state.

**Errors:** `errorOccurred` — "Room not found.", "This game is in progress, try another room", "Please enter a valid nickname!", "Player faction or player mat is already picked in this room."

---

#### `startGame`

Closes the room, runs the faction wheel, sets first player.

```json
{
  "roomId": "AB3KMN"
}
```

**Server response:** `updateRoom` (to the room) with reordered players + first turn.

**Errors:** `errorOccurred` — "Room not found.", "You aren't playing with Automa!!" (single-player room)

---

#### `turn`

Passes the turn to the next player. The server advances `turnIndex`
(wrapping around at the end of the player list, incrementing `totalTurns`),
resets the next player's `remainingSec` to at least `minTurnSec` if it was
below that threshold (audit A6), and restarts the timer engine for the room.

```json
{
  "roomId": "AB3KMN"
}
```

**Server response:** `newTurn` (to the room) with updated room state.

---

#### `pause`

Pauses the game timer. The timer engine clears the 1s interval for this
room; `remainingSec` is preserved (not reset). When resumed, ticking
continues from where it left off.

```json
{
  "roomId": "AB3KMN"
}
```

**Server response:** `updateRoom` (to the room).

---

#### `toContinue`

Resumes the game timer. Wire name kept as `toContinue` for backward
compatibility; renamed to `resume` in Dart code (T1.4).

```json
{
  "roomId": "AB3KMN"
}
```

**Server response:** `updateRoom` (to the room).

---

#### `rejoinRoom`

Reconnects a previously-seated player to their room using their persistent
playerId (D4). The server remaps the socket ID, marks the player connected,
and sends the full room state. If the timer was auto-paused because this
player disconnected during their turn, it is resumed on rejoin.

The client stores `playerId` in `shared_preferences` and sends it here on
reconnect — the server never sends playerId to the client after the initial
create/join.

```json
{
  "roomCode": "AB3KMN",
  "playerId": "550e8400-e29b-41d4-a716-446655440000"
}
```

**Server response:**
- `joinRoomSuccess` (to the rejoining socket) with the room state.
- `updateRoom` (to the room) with updated presence.

If the player was the current turn player and the timer was auto-paused on
their disconnect, the server also resumes the timer and broadcasts the
un-paused state.

**Errors:** `errorOccurred` — "Room code and player ID are required.", "Room or player not found."

---

### Server → Client

| Event | Trigger | Payload |
|---|---|---|
| `createRoomSuccess` | Room created | Room object |
| `joinRoomSuccess` | Player joined (to joiner) | Room object |
| `updateRoom` | Room state changed | Room object |
| `newTurn` | Turn passed (manual or auto-pass on timeout) | Room object |
| `tick` | 1s timer tick (T2.2) | `{ roomCode, playerId, remainingSec }` |
| `errorOccurred` | Any validation error | string (error message) |

---

## HTTP endpoints

### `GET /healthz`

Returns server health + protocol version.

```json
{
  "status": "ok",
  "protocolVersion": 1
}
```

---

## Faction wheel (turn order)

Players are sorted by `playermat` (ascending string sort), then rotated
so the player with the lowest mat whose faction is earliest in the
wheel order leads. The faction wheel order is:

1. Crimea
2. Saxony
3. Polania
4. Albion
5. Nordic
6. Rusviet
7. Togawa

This logic is extracted in `src/factionWheel.js` and pinned by unit
tests (audit A8).

---

## Room codes (D4)

6 characters from the alphabet `ABCDEFGHJKMNPQRSTUVWXYZ23456789`
(no ambiguous characters: no 0/O/1/I/L). Server-minted, collision-checked.

## Player IDs (D4)

UUID v4, minted by server at join, stored client-side in
`shared_preferences`. Enables `rejoinRoom` in T2.3 (not yet implemented).
