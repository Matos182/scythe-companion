# 02 — TARGET ARCHITECTURE & DECISION GATES

Decision gates D1–D6 must be closed by the Conductor **with Matos** before any
Phase ≥ 2 task starts. Record outcomes in `DECISIONS.md`. Recommendations
below are Claude Fable 5's, based on the audit.

## Decision gates

**D1 — Where does the game server live?**
- (a) *VPS, always-on* — fixed Node server, Docker, behind Caddy/Nginx with
  TLS on Matos's Hostinger VPS. Friends connect over the internet; zero setup
  on game night. **Recommended.**
- (b) *LAN-only* — server runs on Matos's laptop/phone hotspot at the table;
  app discovers it (QR with `ws://ip:port`). No VPS dependency, no TLS needed,
  but game night depends on Matos's machine.
- (c) *Both* — runtime server URL makes (b) free once (a) exists; ship (a),
  document (b).

**D2 — Server storage.** Replace MongoDB with an **in-memory `RoomStore`**
(plain `Map`), TTL sweeper (e.g. rooms idle > 3 h deleted), optional JSON
snapshot on shutdown. Removes Atlas, credentials, latency, and A2/A5 outright.
Recommended: yes. (Alternative if persistence ever matters: SQLite. Mongo:
only if Matos wants to keep it for learning reasons.)

**D3 — Client state management.** Keep **Provider**, done properly: typed
models + `ChangeNotifier`s per feature + repository layer. Matos already knows
Provider; relearning it correctly serves the learning goal with least risk.
**Riverpod migration is stretch task S2**, not Phase 1–3. (If Matos prefers to
learn Riverpod now, swap T3.1's notifier design accordingly — say so in
DECISIONS.md before Phase 1 ends.)

**D4 — Room identity & reconnect model.** Short human room codes (6 chars,
unambiguous alphabet e.g. `ABCDEFGHJKMNPQRSTUVWXYZ23456789`) + per-player
`playerId` (UUID minted by server at join, stored client-side in
`shared_preferences`). Reconnect = `rejoinRoom {roomCode, playerId}` → server
remaps `socketID`. Recommended: yes (fixes A3 by design, not by patch).

**D5 — Transport & protocol.** Keep socket.io (client 3.x ↔ server 4.x) —
rewriting to raw WebSockets adds work without learning value. Formal protocol
doc (`docs/PROTOCOL.md`): every event, payload schema, and a `protocolVersion`
field in the handshake so old APKs fail loudly, not weirdly. TLS terminated by
the reverse proxy when D1=(a) (`wss://`), plain `ws://` allowed for LAN mode.

**D6 — Platforms.** Android is the product. The offline calculator may ship
as a web build later (free win) — backlog, not roadmap. `ios/ macos/ linux/
windows/` folders stay untouched.

## Target repo layout

```
scythe-companion/
├── AGENTS.md · CLAUDE.md · orchestra/        # this system
├── app/                                      # ← Flutter project moves here (T0.2)
│   ├── lib/
│   │   ├── main.dart
│   │   ├── core/          # theme, router, constants, shared widgets, l10n
│   │   ├── data/          # SocketService, GameRepository, local prefs
│   │   ├── domain/        # pure Dart: models, ScoreCalculator, turn logic
│   │   └── features/
│   │       ├── scoring/   # simple + multiplayer calculator UI
│   │       ├── rooms/     # create / join / lobby
│   │       └── game/      # turn screen, timer, notifications
│   └── test/              # unit tests mirror domain/, widget tests per feature
├── server/
│   ├── src/  (index.js → src/server.js, roomStore.js, timerEngine.js,
│   │          handlers/, protocol.js)
│   ├── test/              # vitest + socket.io-client integration tests
│   ├── Dockerfile · docker-compose.yml · .env.example
└── docs/PROTOCOL.md · docs/DEPLOY.md
```

Note on `app/` move: keeping Flutter at repo root is acceptable if the move
proves annoying for tooling — Conductor decides at T0.2 and records it (E2).

## Key mechanics (bind implementers to these)

**Timer engine (fixes A1/A2/A6).** One authoritative timer object per room,
owned by a module-level `Map<roomCode, TimerHandle>` in `timerEngine.js` —
never a per-connection variable. State per player: `allowanceSec` (config) and
`remainingSec` (live), distinct fields. Tick loop: 1 s `setInterval` per
*active* room, decrement in memory, broadcast `tick {roomCode, playerId,
remainingSec}`; **no persistence per tick**. Client renders server ticks and
interpolates locally between them; client clocks are display-only, server is
truth. Pause/resume/pass/disconnect all route through the engine's API
(`start/pause/resume/stop`), which internally guarantees ≤ 1 interval per room.

**Connection lifecycle (fixes A3/A10).** Server: handle `disconnect` → mark
player `connected:false`, keep seat, pause their timer if it was their turn
(policy: configurable, default pause), broadcast presence. Client:
`SocketService` exposes a single `Stream<ConnectionState>` +
`Stream<RoomState>`; registers socket handlers **once** at service level, not
in widgets; pages listen via Provider selectors; navigation happens from a
single listener that checks `mounted`. Auto-reconnect with backoff; on
reconnect, emit `rejoinRoom` (D4).

**Scoring engine (fixes A13).** `domain/score_calculator.dart`: pure function
`int coinsFor(PlayerScoreInput input)` implementing the tier table from the
BRIEF; both UIs call it; golden unit tests enumerate tier boundaries (pop 6/7,
12/13, 18) and the resources÷2 floor.

**Typed models (fixes A12).** `Player`, `Room`, `TurnState` with
`fromJson/toJson` (hand-written or `json_serializable` — implementer's choice,
record in DECISIONS). Server payloads validated at the edge; one
`RoomState.fromJson` failure path that surfaces a readable error instead of a
crash.

**Notifications (fixes A9).** Delete the background isolate + phantom socket.
Local notification (`flutter_local_notifications`) fired from the foreground
socket listener on `newTurn` when app is backgrounded; wakelock_plus keeps the
screen on during your own turn. If backgrounded-app delivery proves unreliable
in playtesting, escalate to a foreground service as a *new decision*, not a
silent add.
