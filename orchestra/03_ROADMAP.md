# 03 — ROADMAP & TASK CARDS

One task = one chat = one branch (`task/<ID>-<slug>`) = one PR-sized diff.
Roles: **CON** Conductor · **IMP** Implementer · **REV** Reviewer · **SCR**
Scribe (model mapping in 04_PROTOCOL.md). Every task ends with the hand-off
ritual (04_PROTOCOL §4) including a Teach-back for Matos.

Global acceptance commands (referenced as **GATE-F** for Flutter, **GATE-S**
for server):

- GATE-F: `dart format --set-exit-if-changed .` · `flutter analyze` (0 issues)
  · `flutter test` (green)
- GATE-S: `npm run lint` · `npm test` (green) — exist after T2.0

---

## Phase 0 — Foundation (Conductor-led, interactive with Matos)

**T0.1 — Environment bring-up (WSL2)** [CON+Matos]
Verify/install in WSL: Flutter SDK (latest stable via manual install or fvm —
record exact Flutter/Dart versions in DECISIONS E3), Android cmdline-tools +
SDK/NDK licenses, OpenJDK 17, Node LTS (≥ 22). Get `flutter doctor` clean for
Android. Device strategy: physical phone via `adb` — either usbipd-win USB
passthrough or `adb connect <phone-ip>:5555` over Wi-Fi (document the one that
works in DECISIONS E3). Done when: `flutter doctor -v` has no Android-section
errors and `flutter devices` lists the phone.
*Teach-back: what flutter doctor actually checks; how WSL reaches Android
devices.*

**T0.2 — Repo hygiene** [IMP, small]
`git rm -r --cached server/node_modules` + `.gitignore` it (history rewrite is
**out of scope** — C1); delete dead commented code called out in A16; decide &
record `app/` move (E2; if moved, `git mv` the Flutter dirs and fix tooling
paths); add root `README` pointer to orchestra/. Done when: GATE-F still at
pre-existing failure baseline or better, repo clone is < 5 MB working tree
excluding assets, diff reviewed by Matos.
*Teach-back: why node_modules in git hurts; cached vs working-tree rm.*

**T0.3 — Baseline & truth commit** [IMP, small]
Run `flutter pub get`, `flutter analyze`, `flutter test`, `cd server && npm
ci && node --check index.js`. Fix **nothing** except what blocks the commands
from running; record all warnings/failures verbatim in
`orchestra/BASELINE.md`. Purpose: honest before-picture for the refresh
journey. Done when: BASELINE.md committed.
*Teach-back: reading analyzer output; what a lockfile pins.*

**T0.4 — Dependency refresh** [IMP, medium] deps: T0.3
Upgrade `pubspec.yaml` to current majors: `wakelock`→`wakelock_plus`,
`socket_io_client` →3.x, `go_router` latest, `flutter_lints` latest (adopt
its new lints, don't silence them), drop `awesome_notifications` +
`flutter_background_service` in favor of `flutter_local_notifications`
(A9/A14 — the removal lands fully in T3.4; here just make it compile).
Migrate breaking APIs mechanically; record chosen versions in DECISIONS E4.
Done when: GATE-F passes except pre-existing test debt noted in BASELINE.
*Teach-back: semver in pub; reading a package CHANGELOG for migration.*

## Phase 1 — Domain core (offline value first)

**T1.1 — ScoreCalculator extraction** [IMP, small] deps: T0.4
Create `domain/score_calculator.dart` + `domain/models/score_input.dart` per
02_ARCHITECTURE. Unit tests: tier boundaries (pop 0,6,7,12,13,18), resources
odd/even floor, zeros, 7-player batch. Done when: GATE-F; both scoring pages
still behave identically (manual check by Matos).
*Teach-back: pure functions & why the domain layer has no Flutter imports.*

**T1.2 — Typed models** [IMP, medium] deps: T1.1
`Player`, `Room`, `TurnState` with `fromJson/toJson` matching the **current**
server payloads (protocol upgrade comes in Phase 2 — write an adapter seam so
T2.1 swaps cleanly). Replace `Map` access in provider/pages. Rename `Players`
→ `ScoreEntry` where it serves the calculator. Done when: GATE-F; zero
`roomData[...]` string indexing left in `lib/`.
*Teach-back: null-safety at JSON edges; named constructors & factories.*

**T1.3 — Scoring UIs consolidated** [IMP, medium] deps: T1.1, T1.2
`simple.dart` + `player_add.dart` + `result.dart` refactored onto the shared
engine and a shared form widget; input validation (0–18 popularity, ≥0 ints);
winner logic (ties!) into domain with tests. Done when: GATE-F + widget test
for the form.
*Teach-back: controllers vs Form/TextFormField validators; widget tests 101.*

**T1.4 — Lint & language pass** [IMP, small] deps: T1.3
English identifiers (`atualTurn`→`currentTurnIndex`, `toContinue`→`resume`),
delete dead code, strengthen `analysis_options.yaml`, doc comments on public
domain API. Done when: GATE-F with the stricter lints.
*Teach-back: 3 lints that caught something real here, and why.*

## Phase 2 — Server rebuild (Node, per D1/D2)

**T2.0 — Server scaffolding** [IMP, small] deps: D1, D2 closed
`server/`: ESLint + vitest + `npm scripts` (`dev`, `start`, `lint`, `test`),
`src/` layout per 02_ARCHITECTURE, `.env.example` (PORT, CORS_ORIGIN,
ROOM_TTL_HOURS), config module. Keep old `index.js` running untouched until
T2.3 reaches parity. Done when: GATE-S green on empty suites + hello-world
socket test.
*Teach-back: reading env config safely; why .env.example is committed.*

**T2.1 — RoomStore + protocol v1** [IMP, large] deps: T2.0
In-memory `RoomStore` (create/join/get, room codes per D4, playerId minting,
TTL sweeper); `docs/PROTOCOL.md` defining every event + JSON schema +
`protocolVersion`; port `createRoom/joinRoom/startGame` handlers; keep faction
wheel logic **verbatim** but with unit tests pinning current behavior (A8),
including mat-order edge cases. Mongo/Mongoose removed. Done when: GATE-S;
integration test: 3 fake clients create/join/start and receive identical room
state; turn order matches 5 pinned fixtures.
*Teach-back: why ephemeral state ≠ database; designing a message protocol.*

**T2.2 — Timer engine** [IMP, large] deps: T2.1
`timerEngine.js` exactly per 02_ARCHITECTURE (one handle per room,
allowance vs remaining, tick broadcast, pause/resume/stop, ≤1 interval per
room enforced by construction). Wire `turn/pause/toContinue→resume`. Done
when: GATE-S; tests with fake timers prove: no double-interval after rapid
pass-pass-pause; remaining survives pause; room deletion kills its timer.
*Teach-back: closures & why A1 happened; fake timers in tests.*

**T2.3 — Presence & rejoin** [IMP, medium] deps: T2.2
`disconnect` handler (seat kept, presence broadcast, auto-pause policy),
`rejoinRoom {roomCode, playerId}` remapping socket, room-creator handover if
creator leaves > N min (policy in DECISIONS). Old `index.js` deleted — new
server is authoritative. Done when: GATE-S; integration test: client drops,
reconnects with same playerId, receives full state; timer paused/resumed
correctly.
*Teach-back: sockets vs sessions; idempotent rejoin design.*

**T2.4 — Hardening** [IMP, small] deps: T2.3
Payload validation (zod or hand-rolled) on every event, error envelope
(`errorOccurred {code, message}`), CORS from env, basic rate limit
(joins/sec/IP), max players enforced server-side, structured logs (pino),
`/healthz` HTTP endpoint. Done when: GATE-S; malformed-payload tests return
errors, never crash.
*Teach-back: validating at trust boundaries; what /healthz is for.*

**T2.5 — Docker & deploy runbook** [IMP, small] deps: T2.4; D1=(a)
`Dockerfile` (multi-stage, non-root user), `docker-compose.yml`,
`docs/DEPLOY.md`: step-by-step for Matos's VPS — container behind
Caddy/Nginx, TLS + `wss://`, systemd or compose restart policy, firewall note
(expose 443 only), update procedure. **Model writes the runbook; Matos runs
it** (C1/C2). LAN mode section: `npm start` + QR (D1 b/c). Done when: Matos
deploys successfully following the doc alone; `/healthz` reachable via https.
*Teach-back: multi-stage builds; reverse proxy TLS termination for WebSockets.*

## Phase 3 — Client multiplayer rebuild

**T3.1 — SocketService & state layer** [IMP, large] deps: T1.2, T2.3
Replace `SocketClient/SocketMethods` with `data/socket_service.dart`
(connection-state stream, auto-reconnect+backoff, handlers registered once,
protocolVersion check) + `GameRepository` + room/game `ChangeNotifier`s per
D3. All navigation-from-socket moved to one guarded listener. Done when:
GATE-F; unit tests with a fake socket cover connect→join→turn→drop→rejoin.
*Teach-back: streams vs ChangeNotifier; why widgets never own sockets.*

**T3.2 — Runtime server config + QR flow** [IMP, medium] deps: T3.1, T2.5
Settings screen (server URL, default nickname → shared_preferences); delete
`lib/env/` dependency (A11); lobby shows room code + QR encoding
`scythe://join?server=…&room=…`; join page scans QR (mobile_scanner) or
accepts typed code. Done when: GATE-F; fresh APK on a second phone joins via
QR with zero typing.
*Teach-back: shared_preferences vs secure storage; deep-link URI design.*

**T3.3 — Game screen rebuild** [IMP, large] deps: T3.1, T2.2
Turn screen driven by typed `RoomState`: whose-turn banner, per-player
remaining time from server ticks + local interpolation, pause/resume, pass
button only for current player, presence badges (connected/disconnected),
end-of-game path into the score calculator with room's player names
pre-filled. wakelock_plus during own turn. Done when: GATE-F; widget tests for
turn banner + pass-button gating; Matos smoke-tests a 3-phone game.
*Teach-back: selectors/Consumer granularity; interpolating server time.*

**T3.4 — Notifications done right** [IMP, medium] deps: T3.3
Remove background isolate + `awesome_notifications` + `flutter_background_service`
entirely (A9); `flutter_local_notifications` on `newTurn` while backgrounded;
Android 13+ POST_NOTIFICATIONS permission flow. Done when: GATE-F; locked
phone receives "your turn" during a live room test.
*Teach-back: Android notification permissions; app lifecycle states.*

**T3.5 — UX & error polish** [IMP, medium] deps: T3.2–T3.4
Loading/disconnected/reconnecting states everywhere, human error messages
(from T2.4 codes), empty states, confirm-leave dialogs, centralize strings
(prep for PT l10n — actual l10n = backlog). Done when: GATE-F; Matos clicks
through every failure path (server down, bad code, room full, drop mid-turn).
*Teach-back: error-state driven UI; where l10n hooks in later.*

## Phase 4 — Ship it

**T4.1 — CI** [IMP, small] deps: T1.4, T2.4
GitHub Actions: job 1 Flutter (format/analyze/test + debug APK artifact),
job 2 server (lint/test), on PR + master. Done when: badge green on master.
*Teach-back: anatomy of a workflow file; caching pub/npm.*

**T4.2 — Release build** [IMP, small] deps: T4.1
Keystore signing (keystore + passwords stay with Matos — C2; document
`key.properties` flow), versioning scheme, R8/proguard sanity, release APK in
GitHub Releases with install notes for friends. Done when: friends install
signed v0.4.0 from Releases.
*Teach-back: debug vs release signing; what R8 strips.*

**T4.3 — Docs & README rewrite** [SCR, small] deps: T4.2
README: what/screenshots/install-for-players/self-host-in-10-min/architecture
sketch; CHANGELOG started; orchestra/ docs marked as living history. Done
when: Matos approves; a stranger could self-host from README alone.

**T4.4 — Playtest protocol** [CON+Matos] deps: T4.2
Structured game-night test: checklist mirroring the BRIEF release list,
feedback captured to `orchestra/PLAYTEST-01.md`, defects triaged into
PROGRESS Backlog. Done when: one full real game of Scythe runs on v0.4.x and
the checklist is scored.

## Stretch (backlog — needs new decision + Conductor plan)

- **S1** Rewrite server in Dart (`shelf` + WebSockets) — one language, deeper
  Dart practice. **S2** Riverpod migration. **S3** Score history (local
  sqlite). **S4** Web build of the calculator. **S5** Expansions data
  (Invaders from Afar mats/factions) — mind C5. **S6** iOS.
