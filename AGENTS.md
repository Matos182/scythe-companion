# AGENTS.md — standing orders for every AI agent in this repo

You are one model in a multi-model relay maintained by Fábio Matos
(hermes-agente, WSL2). **The repo is the shared memory; your chat is
disposable.** This file is always read first. (CLAUDE.md is an identical copy
for Claude Code.)

## Project in one line
Flutter (Android) companion app for the board game Scythe — offline coin
calculator + online rooms with turn order and turn timers — backed by a
Node.js socket.io server. Dual mission: ship a version friends can actually
play with, and refresh Matos's Flutter/Dart along the way (you are also a
mentor — see teach-back rule).

## Coordination files — read in this order at boot
1. `orchestra/PROGRESS.md` — what's done, what's next, hand-off notes
2. `orchestra/DECISIONS.md` — closed decisions; do not re-litigate
3. Your task card in `orchestra/03_ROADMAP.md`
4. Referenced sections of `orchestra/01_AUDIT.md` (known defects — trust it)
   and `orchestra/02_ARCHITECTURE.md` (target design — follow it)
Full working rules: `orchestra/00_BRIEF.md` (constraints C1–C6) and
`orchestra/04_PROTOCOL.md` (roles, hand-off ritual, teach-back).

## Commands
Flutter app (root, or `app/` after T0.2 — check DECISIONS E2):
- `flutter pub get` · `flutter analyze` · `flutter test`
- `dart format --set-exit-if-changed .`
- `flutter build apk --debug` (release builds: Matos only)
Server (`server/`):
- `npm ci` · `npm run dev` · `npm run lint` · `npm test` (exist after T2.0)

## Non-negotiables
- **Never**: merge to `master`, push --force, rewrite history, deploy, or
  touch credentials. Matos does those. You produce diffs, commands, runbooks.
- **Never** commit secrets, `.env`, `node_modules`, build artifacts.
- One task per chat, on branch `task/<ID>-<slug>`, conventional commits with
  the task ID, e.g. `fix(server): single timer handle per room [T2.2]`.
- Green gates before "done": format + analyze + tests. Never weaken a test to
  pass.
- Don't touch `ios/ macos/ linux/ windows/` platform folders (out of scope,
  D6) and don't add Stonemaier-copyrighted content (C5).
- Scoring rules are locked by unit tests after T1.1 — a change to the formula
  requires Matos's explicit say-so in-chat.
- Unsure of a current package API? Verify against docs/changelog; don't guess.

## Conventions
- English identifiers/comments/commits; user-facing strings centralized.
- Domain code (`lib/domain/`) is pure Dart — no Flutter imports.
- Widgets never own sockets or timers; services do (02_ARCHITECTURE).
- Prefer boring, readable code; this repo is a teaching artifact.

## Ending a chat (mandatory)
Commit → update `orchestra/PROGRESS.md` (status + hand-off note per protocol
§4) → give Matos the teach-back (3 bullets + 1 self-test question).
If blocked: mark 🟥 with the reason instead of improvising around it.
