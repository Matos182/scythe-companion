# FULL-CODE AUDIT — orchestrator review
Date: 2026-07-25 · Reviewer: orchestrator (kimi-k3) · Branch at audit: task/AUDIT-pi-registration
Scope: re-ran every gate + read every Dart source file, every server module,
CI workflow, android config, and the 4 pending branches. This is a
whole-repo quality pass, not a spot check.

## 1. Gates re-run (fresh, this session)
| Gate | Result |
|---|---|
| dart format --set-exit-if-changed . | ✅ 57 files, 0 changed |
| flutter analyze | ✅ No issues found |
| flutter test | ✅ 142/142 passed |
| server: npm run lint | ✅ eslint clean (0/0) |
| server: npm test | ✅ 116/116 passed (10 files) |

All green. No agent lied in a hand-off about gate state — matches PROGRESS.

## 2. Architecture conformance (spot-verified against 02_ARCHITECTURE)
- Handlers registered once at service level, never in widgets ✅ (A10)
- Widgets never touch socket/GameRepository directly; go through
  RoomNotifier ✅ (game.dart, lobby, create/join all clean)
- Domain (lib/domain/) is pure Dart, zero Flutter imports ✅
- Server authoritative for turnIndex/timer; client only renders ✅ (A1/A2/A6)
- Composition root owns single guarded nav/error/notification listener ✅
- Ticks folded into narrow Selector sub-tree, not whole-page rebuild ✅

## 3. Code quality — what's genuinely good
- socket_service.dart: clean adapter seam, version probe before connect,
  graceful legacy-string error fallback. Readable, boring, testable.
- timerEngine.js: start() always clears before creating — ≤1 interval per
  room by construction. Auto-pass at 0 correct. Module-level Map (A1 fixed).
- roomStore.js: serialize() matches Dart Room.fromJson exactly (adapter
  seam holds). TTL sweeper, unambiguous room-code alphabet (D4).
- handlers.js: every event validates payload, structured {code,message}
  envelopes, rate-limit slot released on disconnect. Solid.
- error_messages.dart: full VAL_*/STATE_*/REJOIN_*/RATE_*/SERVER_* mapping
  with sensible fallback — won't silently drop future codes.
- qr_payload.dart: value equality, hostile-input decode (rejects wrong
  scheme/host), round-trip tested.

## 4. Findings / improvements (ranked; NONE block the current release)
### Minor (worth a follow-up ticket, not urgent)
F1. create.dart timer mapping (lines 68-76): `_secondsPlayerTimer` is a
    late int set by an if/else chain on the '15:00'/'20:00'/... strings.
    If playerTimers ever gains a value not in the chain, it throws
    LateInitializationError. Suggest a const map {'15:00':900,...} lookup.
    Low risk today (dropdown constrains input) but fragile-by-construction.
F2. validation.js exports MAX_ROOMS=7 but handlers.js caps rooms via
    options.maxRooms ?? MAX_ROOMS env (default 100). Two different
    "max rooms" concepts with the same name — the validation.js constant
    is dead/confusing. Rename one (e.g. MAX_PLAYERS_PER_ROOM) or delete.
F3. game.dart _PlayersTable rebuilds the whole table on any notifier event.
    Bounded (≤7 rows) and only on real events — acceptable, comment already
    acknowledges this. No action needed; noting it's a deliberate trade-off.
F4. ci.yml comment (line 63-66) still says "currently lib/resources/socket_client.dart"
    imports lib/env — that file is gone (T3.1). The stub step is now
    belt-and-suspenders for a deleted importer. Harmless; comment is stale.
    Can drop the stub step entirely once someone confirms nothing imports env.

### Cosmetic / zero-impact (do not act unless touching the file anyway)
F5. PROGRESS.md markdown fence structure still has orphan ``` pairs between
    old hand-offs (flagged since T3.2). Purely cosmetic.
F6. pubspec.lock drift: 40 packages have newer versions incompatible with
    constraints (flutter analyze noted). Not a defect — just pending refresh.

## 5. Pending branches — verified against master (429cda3)
| Branch | Commits | Verdict |
|---|---|---|
| origin/fm/scythe-android-launch-v6 (PR #1, T4.2.x) | 5 | ✅ REAL fix, merge FIRST. Moves MainActivity.kt com.example.scythe→com.matos.scythe_companion (master still has wrong pkg → v0.4.0 APK crashes at launch). +entrypoint regression test, toolchain bump AGP 8.9.1/Gradle 8.11.1/Java 17/compileSdk 36. |
| task/AUDIT-pi-registration | 1 | ✅ Correct. Removes invalid ${{ runner.tool_cache/flutter-path }} from ci.yml (the reason CI was NEVER green — all runs failed at YAML parse in 0s). Registers PR#1 as T4.2.x. Docs+CI only. |
| task/T4.3-docs-readme | 1 (d01c099) | ✅ Clean. README rewrite + CHANGELOG v0.4.0 + 2 real doc-drift fixes (HTTPS-not-WSS in DEPLOY.md, /healthz-not-handshake in PROTOCOL.md). Docs only. |
| task/T4.4-playtest-protocol | 1 (40dd4a1) | ✅ Clean. PLAYTEST-01.md, 28 checkboxes mapped to BRIEF release list. Docs only. |

Confirmed on disk: master MainActivity.kt = `package com.example.scythe`
(WRONG — this is the crash). PR#1 MainActivity.kt = `package
com.matos.scythe_companion` (CORRECT). The fix is real and necessary.

## 6. Security / hygiene
- No secrets, .env, keystores, or credentials anywhere in tracked files ✅
- key.properties + *.jks + mapping.txt gitignored (T4.2) ✅
- Rate limiting + payload validation present server-side ✅
- lib/env/env.dart: NOT tracked (gitignored), only referenced in comments ✅

## 7. Where we are NOW
- Code: all 24 relay tasks merged to master are ✅ and re-verified green.
- 4 items sit 🟦 awaiting Matos (only Matos merges/pushes — C1):
  PR #1 → AUDIT-pi-registration → T4.3 → T4.4.
- CI has never been green (broken YAML expr). The AUDIT branch fixes it;
  it only validates on the first real push to master.
- Any v0.4.0 APK built before PR #1 merges carries the launcher crash.

## 8. NEXT STEP (single, blocking)
Matos merges the 4 pending items in this order, then pushes master:
  1. PR #1 (fm/scythe-android-launch-v6)  ← release blocker
  2. task/AUDIT-pi-registration           ← CI fix
  3. task/T4.3-docs-readme
  4. task/T4.4-playtest-protocol
Then: push master → watch first-ever green CI run → rebuild v0.4.0 APK per
docs/RELEASE.md → run PLAYTEST-01 at game night.
