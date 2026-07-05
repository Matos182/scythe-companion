# 00 — PROJECT BRIEF

## Mission (two goals, both mandatory)

1. **Product**: evolve `scythe-companion` from a clunky v0.3.5 prototype into a
   reliable companion app for physical games of Scythe with friends: scoring
   calculator + shared room with turn order and per-player turn timers.
2. **Learning**: Matos built this app years ago and wants to *refresh his
   Flutter/Dart knowledge* through this project. Models are mentors, not just
   contractors. Every task ends with a **Teach-back** (see 04_PROTOCOL.md).
   Prefer solutions Matos can read and reason about over clever ones.

## What the app is

Companion app for the board game Scythe (Stonemaier Games):

- **Coin calculator** (offline): per player, inputs = popularity, stars, lands,
  resources÷2, building bonus coins, coins on hand. Popularity tier sets the
  multipliers: 0–6 → ×3 stars / ×2 lands / ×1 per 2 resources; 7–12 → 4/3/2;
  13–18 → 5/4/3. Up to 7 players, results page picks the winner.
- **Rooms** (online): creator sets nickname, faction, player mat, turn timer;
  others join by room ID; server derives turn order from player-mat sort and
  faction wheel order (Crimea→Saxony→Polania→Albion→Nordic→Rusviet→Togawa);
  current player passes turn; server runs a countdown per turn; pause/continue;
  notification when it becomes your turn.

Current stack: Flutter (Provider, go_router, socket_io_client 1.x) + Node.js
(Express + socket.io + Mongoose/MongoDB Atlas). See 01_AUDIT.md for the state
of it — read the audit, do not re-audit.

## Environment

- **Host**: Windows 11 + WSL2 (Ubuntu). All agent work happens inside WSL.
- **Orchestrator**: hermes-agente running several models. Named backends:
  Claude Fable 5 (`claude-fable-5`), Claude Opus 4.8 (`claude-opus-4-8`),
  Claude Sonnet 4.6 (`claude-sonnet-4-6`), Claude Haiku 4.5
  (`claude-haiku-4-5-20251001`), MiniMax. Role→model mapping in 04_PROTOCOL.md.
- **Repo**: `https://github.com/Matos182/scythe-companion` — default branch
  `master`, working copy in WSL (path recorded in DECISIONS.md → E1).
- **Deployment option**: Matos operates a hardened Debian VPS (Hostinger) with
  Docker-capable tooling and WireGuard — a natural home for the game server if
  decision D1 selects self-hosting. Models never receive VPS credentials; they
  produce runbooks and Matos executes them.
- **Devices**: Android phones (Matos + friends). Testing on a physical device
  via `adb`; emulator optional on the Windows side.

## Hard constraints

- **C1 — Matos is the gate.** Models work on branches, never merge to
  `master`, never deploy, never run destructive git commands (`push --force`,
  `reset --hard` on shared branches, history rewrites) without an explicit
  instruction from Matos in that same chat.
- **C2 — No secrets in the repo or in chats.** Server config via environment
  variables (`.env` gitignored, `.env.example` committed). Matos never pastes
  credentials to a model.
- **C3 — One task per chat, one branch per task.** Scope creep is a protocol
  violation; park ideas in `PROGRESS.md → Backlog`.
- **C4 — Verifiable done.** A task is done only when its acceptance commands
  pass (`flutter analyze`, `flutter test`, `dart format`, server tests) and
  the diff is committed with the task ID in the message.
- **C5 — Keep the app free of Stonemaier IP.** No copyrighted artwork, card
  text, or rulebook reproductions. Faction/mat names as plain identifiers are
  fine. Original icons/colors only.
- **C6 — English in code and docs.** Chat with Matos may be PT or EN;
  identifiers, comments, commits: English. User-facing strings centralized so
  PT localization stays cheap (Phase 3).

## Definition of "viable to play with friends" (release checklist)

- Friends install one APK (GitHub Release); no rebuild needed to point at a
  server — server address is runtime configuration or discovery.
- Creating/joining a room takes < 30 s; joining works by short code and/or QR.
- A phone that locks its screen, drops Wi-Fi, or kills the app can rejoin the
  room and land in the correct state within seconds.
- Turn timer is accurate (±1 s), pause works, and it's always obvious whose
  turn it is; local notification fires when your turn starts.
- Scoring is provably correct (unit tests cover the official tier table).
- Server runs unattended (Docker on VPS or documented LAN mode), cleans up
  dead rooms, and survives restarts without babysitting.
- `master` is green in CI: analyze + test + APK build.
