# Scythe Companion — Wire Protocol v1

**Protocol version:** 1  
**Transport:** socket.io (client 3.x ↔ server 4.x)  
**Last updated:** 2026-09-03 (T5.7 combat pause — additive, protocolVersion stays 1)

> A `protocolVersion` field is included in the `/healthz` HTTP response.
> The client probes `/healthz` before opening the socket; if its expected
> version differs, it refuses to connect and shows an upgrade prompt. Bump
> the version when any event name or payload shape changes.

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
  "pauseReason": null,
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
| `pauseReason` | string \| omitted | **T5.7, additive.** Omitted or `null` = ordinary pause (manual or disconnect). `"combat"` = table-fight pause. Missing key ⇒ not combat. `protocolVersion` stays 1. |
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

**Errors:** `errorOccurred` — "Room not found.", "You aren't playing with Automa!!" (single-player room), "You are not a player in that room." (`AUTH_NOT_IN_ROOM`, T4.7c — sender not seated in `roomId`), "Only the room creator can start the game." (`AUTH_NOT_CREATOR` — seated non-creator)

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

**Errors:** `errorOccurred` — "Room not found.", "You are not a player in that room." (`AUTH_NOT_IN_ROOM`, T4.7c), "It's not your turn." (`STATE_NOT_YOUR_TURN`, T4.7c — only the current turn player may pass)

---

#### `pause`

Pauses the game timer. The timer engine clears the 1s interval for this
room; `remainingSec` is preserved (not reset). When resumed, ticking
continues from where it left off.  Requires room membership (T4.7c —
`AUTH_NOT_IN_ROOM` otherwise; same for `toContinue`).

```json
{
  "roomId": "AB3KMN"
}
```

**Server response:** `updateRoom` (to the room).

---

#### `combat` (T5.7 — additive, protocolVersion stays 1)

Starts a **combat pause**: the current-turn player is resolving a fight
on the physical board. The timer pauses (`remainingSec` preserved) and
`pauseReason` is set to `"combat"` so every client can show the fight
overlay. Resume with the existing `toContinue` event (which also clears
`pauseReason`). There is no separate `combatEnded` event.

Current-turn player only (server-enforced). Rejected in the lobby
(`isJoin`). Ordinary `pause` does **not** set `pauseReason` to combat.
Disconnect auto-pause does **not** set combat. Rejoin auto-resume of
the current-turn player runs only when `pauseReason` is not `"combat"`.

```json
{
  "roomId": "AB3KMN"
}
```

**Server response:** `updateRoom` (to the room) with `isPaused: true`
and `pauseReason: "combat"`.

**Errors:** `errorOccurred` — "Room not found.", "You are not a player
in that room." (`AUTH_NOT_IN_ROOM`), "It's not your turn."
(`STATE_NOT_YOUR_TURN`), "The game has not started." (`VAL_BAD_PAYLOAD`
when still in lobby).

---

#### `toContinue`

Resumes the game timer. Wire name kept as `toContinue` for backward
compatibility; renamed to `resume` in Dart code (T1.4). Also clears
`pauseReason` (T5.7) so a combat pause returns to a live clock.

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
un-paused state. **Exception (T5.7):** a combat pause (`pauseReason ===
"combat"`) is not auto-resumed on rejoin — the fight stays paused until
the current-turn player emits `toContinue`.

**Errors:** `errorOccurred` — "Room code and player ID are required.", "Room or player not found."

---

#### `removePlayer` (T5.4 — creator seat management)

Removes a DISCONNECTED player from the room, freeing their faction/mat
seat so a fresh `joinRoom` can take it. Covers the unrecoverable cases:
lost saved session, app reinstall, different device. Creator-only.

```json
{
  "roomId": "AB3KMN",
  "playerId": "550e8400-e29b-41d4-a716-446655440000"
}
```

**Server response:**
- `updateRoom` (to the room) with the player removed.
- If the removed player was the current turn player: also `newTurn` with
  the turn moved to the next remaining player, and the timer restarted.

**Errors:** `errorOccurred` — "You are not a player in that room."
(`AUTH_NOT_IN_ROOM`), "Only the room creator can remove players."
(`AUTH_NOT_CREATOR`), "That player is still connected — you can only
remove players who've left." (`STATE_PLAYER_CONNECTED`), "That player is
not in the room." (`STATE_ROOM_NOT_FOUND`).

---

### Server → Client

| Event | Trigger | Payload |
|---|---|---|
| `createRoomSuccess` | Room created | Room object |
| `joinRoomSuccess` | Player joined (to joiner) | Room object |
| `updateRoom` | Room state changed | Room object |
| `newTurn` | Turn passed (manual or auto-pass on timeout) | Room object |
| `tick` | 1s timer tick (T2.2) | `{ roomCode, playerId, remainingSec }` |
| `errorOccurred` | Any validation error | `{ code, message }` — see Error envelope (T2.4) |

---

## HTTP endpoints

### `GET /healthz`

Returns server health + protocol version.

```json
{
  "status": "ok",
  "protocolVersion": 1,
  "uptime": 3600,
  "rooms": 3,
  "activeTimers": 2,
  "maxRooms": 100
}
```

---

## Error envelope (T2.4)

All `errorOccurred` events carry a structured envelope instead of a bare string:

```json
{
  "code": "STATE_FACTION_OR_MAT_TAKEN",
  "message": "Player faction or player mat is already picked in this room."
}
```

- `code` — machine-readable identifier, stable across versions. Clients can
  switch on it for localized error messages or specific UI behaviour.
- `message` — human-readable English string, suitable for a snackbar.

### Error codes

| Code | Category | Meaning |
|---|---|---|
| `VAL_MISSING_NICKNAME` | Validation | Nickname empty or too long |
| `VAL_MISSING_ROOM_ID` | Validation | Room ID missing |
| `VAL_MISSING_FIELDS` | Validation | Required fields missing (rejoin) |
| `VAL_INVALID_TIMER` | Validation | Timer not an integer in [10, 3600] |
| `VAL_INVALID_FACTION` | Validation | Faction not in the valid set |
| `VAL_INVALID_MAT` | Validation | Player mat not in the valid set |
| `VAL_BAD_PAYLOAD` | Validation | Payload is not a non-null object |
| `AUTH_NOT_IN_ROOM` | Auth | Sender not seated in the room they target (T4.7c) |
| `AUTH_NOT_CREATOR` | Auth | Sender is not the room creator (startGame, T5.4 removePlayer) |
| `STATE_ROOM_NOT_FOUND` | State | Room does not exist |
| `STATE_GAME_IN_PROGRESS` | State | Room closed (game started) |
| `STATE_FACTION_OR_MAT_TAKEN` | State | Faction/mat already chosen |
| `STATE_SINGLE_PLAYER` | State | startGame with < 2 players |
| `STATE_NOT_YOUR_TURN` | State | Not the current turn player |
| `STATE_PASS_FAILED` | State | passTurn failed |
| `REJOIN_NOT_FOUND` | Rejoin | Room or player not found |
| `RATE_LIMITED` | Rate limit | Too many connection attempts per IP |
| `RATE_MAX_CONNECTIONS` | Rate limit | Too many concurrent sockets per IP |
| `SERVER_MAX_ROOMS` | Server | Server room cap reached |

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
`shared_preferences`. Enables `rejoinRoom` (implemented in T2.3).
