# 01 — CODE AUDIT (v0.3.5, master @ 2024-04-19)

Audit performed 2026-07-04 by Claude Fable 5 against the full repo. Downstream
models: treat these findings as ground truth inputs to your task cards; verify
locally only what your task touches. Severity: 🔴 breaks play, 🟠 blocks
"viable", 🟡 quality/maintainability, ⚪ cosmetic.

## Server (`server/`)

- 🔴 **A1 — Turn-timer race & leak.** `roomTimerInterval` is declared inside
  `io.on('connection', …)` — one variable *per socket connection* — but it
  controls a *per-room* interval. When player B passes turn, the server
  `clearInterval`s **B's** (usually undefined) handle, not the interval started
  from A's connection. Result: orphaned intervals, multiple timers ticking the
  same room, timers that survive room death. Root cause of most "clunky"
  behavior in play.
- 🔴 **A2 — DB round-trip every second.** `startPlayerTimer` runs
  `Room.findById` + `room.save()` inside a 1 s `setInterval`, per room. Mongo
  Atlas latency from the Azores makes ticks drift; concurrent saves race with
  `turn`/`pause` handlers (lost updates).
- 🔴 **A3 — Rejoin is dead code.** `server/index.js` join handler compares
  `player.socketID == socket._id`; the property is `socket.id`. The reconnect
  branch can never match ⇒ any disconnect (screen lock, Wi-Fi blip) permanently
  ejects the player. Also nothing updates a player's stored `socketID` after
  reconnect, and there's no `disconnect` handler at all.
- 🟠 **A4 — Secrets & config topology.** Server imports credentials from
  `../lib/env/env.json` (server reaching into the Flutter tree); Mongo cluster
  host is hardcoded in the connection string; port fixed at 3000; no CORS
  config, no input size limits, no rate limiting; room IDs are raw Mongo
  ObjectIds (24 hex chars — hostile to "read it out loud at the table").
- 🟠 **A5 — MongoDB is the wrong tool here.** Rooms are ephemeral (~2 h),
  state fits in memory, yet every mutation is a Mongo document save and rooms
  are **never deleted** — the collection grows forever, and `startGame` /
  `turn` trust `findById` results without null checks (crash on stale IDs).
- 🟠 **A6 — Timer semantics conflated.** `player.timer` is simultaneously the
  configured per-turn allowance and the live countdown value, persisted per
  tick. The "reset to 10 if < 10" rule in the `turn` handler silently gifts
  time and encodes policy in a magic number.
- 🟡 **A7 — 22 MB of `server/node_modules` committed** to git; `package.json`
  deps are 2024-era (Express 4, Mongoose 8.x, socket.io 4.x of that time);
  no lockfile discipline, no tests, no lint, `console.log(room)` spam.
- 🟡 **A8 — Turn-order routine** (`reorderPlayers`) sorts player mats as
  *strings* — works only because mats are `'1','2','2A','3','3A','4','5'`;
  fragile if mats change (e.g. IFA mats). No tests pin the faction-wheel
  behavior.

## Flutter client (`lib/`)

- 🔴 **A9 — Background service is structurally broken.**
  `back_services.dart` spawns a background isolate that news up its **own**
  `RoomDataProvider` and its own `SocketMethods` (⇒ second socket connection).
  Isolates share nothing: that provider never receives UI-side room updates,
  so the background turn-notification path cannot work; meanwhile the app
  opens a phantom connection per launch. `game.dart` works around it with a
  foreground notification hack (`triggerNoti`) throttled by comparing
  `TimeOfDay.now()` (minute resolution) and calling empty `setState`.
- 🔴 **A10 — Socket listener lifecycle.** `SocketMethods` registers `.on(…)`
  handlers in pages' `initState` with a captured `BuildContext`, never calls
  `.off(…)`, and navigates with `context.goNamed` inside socket callbacks
  (context across async gaps, no `mounted` checks). Navigating
  create → game → home → join → game stacks duplicate handlers: double
  navigation, double snackbars, provider updates on disposed contexts.
- 🟠 **A11 — Compile-time server address.** `socket_client.dart` builds
  `http://$ipaddress2:3000` from a gitignored `lib/env/env.dart` ⇒ the repo
  doesn't compile after clone, and pointing friends at a server means
  rebuilding the APK. No TLS (`http://`, not `https://`), which also trips
  Android's default cleartext-traffic policy on release builds.
- 🟠 **A12 — Untyped room state.** `RoomDataProvider` holds
  `Map<String, dynamic> roomData`; pages index into it like
  `roomData['turn']['socketID']` with no models, no null-safety at the edges —
  one server payload change away from runtime crashes. The existing `Players`
  class is only used by the offline calculator and has a positional 8-arg
  constructor.
- 🟠 **A13 — Scoring engine duplicated.** The popularity-tier scoring `if`
  ladder is copy-pasted in `pages/simple.dart` and `pages/player_add.dart`
  with magic numbers and zero tests. Any rules fix must be made twice.
- 🟡 **A14 — Dependencies.** `wakelock` is discontinued (successor:
  `wakelock_plus`); `socket_io_client` 1.x (current major is 3.x, matching
  socket.io v4 semantics); `go_router` 13 (many majors behind);
  `flutter_lints` 3; SDK constraint `>=3.2.6`. `awesome_notifications` +
  `flutter_background_service` combo is heavier than the need (a local
  notification on a socket event).
- 🟡 **A15 — Tests/CI.** Single default `widget_test.dart` (counter template —
  doesn't even match the app, so `flutter test` fails); no CI; `analysis_options`
  is the stock file.
- 🟡 **A16 — Mixed language & dead code.** `atualTurn`, `toContinue`,
  commented-out imports/vibration code, ASCII-art headers, README still says
  "Scythe Coin Calculator" in places and the clone URL points at the old repo
  name.
- ⚪ **A17 — Unused platform shells.** `ios/ linux/ macos/ web/ windows/`
  folders are template-generated and untested; keep but explicitly out of
  scope (BRIEF C-scope, D6).

## What is worth keeping

- Feature set and flow (calculator / create / join / lobby / game) are sound.
- Faction wheel + mat-based first-player logic matches the real game — extract
  and test it, don't redesign it.
- go_router + Provider are acceptable foundations (see D3).
- Server event vocabulary (`createRoom`, `joinRoom`, `startGame`, `turn`,
  `pause`, `toContinue`, `updateRoom`, `newTurn`, `errorOccurred`) is a
  reasonable protocol seed — formalize it, version it (see T2.1).
