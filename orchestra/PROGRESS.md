# PROGRESS BOARD

Legend: ⬜ not started · 🟨 in progress (branch open) · 🟦 gates green,
awaiting Matos review · ✅ done (gates green, Matos reviewed) · 🟥 blocked.
Every chat updates this file before ending
(protocol §4). "Next up" is the single source of truth for what happens next.

**Next up:** T0.3 — Baseline & truth commit (IMP, small). Work in
`~/dev/scythe-companion`, branch off `task/T0.2-repo-hygiene` (carries
T0.1 + T0.2 work). Run `flutter pub get`, `flutter analyze`, `flutter test`,
`cd server && npm ci && node --check index.js`; fix nothing except what
blocks commands from running; record all warnings/failures verbatim in
`orchestra/BASELINE.md`. Also note there: T0.2 churned `pubspec.lock`
(~66 lines of transitive bumps from `pub get` under Flutter 3.44.4) —
known drift, record it so the truth commit's before-picture stays honest.

## Phase 0 — Foundation
| Task | Title | Role | Status |
|---|---|---|---|
| T0.1 | Environment bring-up (WSL2) | CON+Matos | ✅ |
| T0.2 | Repo hygiene | IMP | 🟦 |
| T0.3 | Baseline & truth commit | IMP | ⬜ |
| T0.4 | Dependency refresh | IMP | ⬜ |

## Phase 1 — Domain core
| T1.1 | ScoreCalculator extraction | IMP | ⬜ |
| T1.2 | Typed models | IMP | ⬜ |
| T1.3 | Scoring UIs consolidated | IMP | ⬜ |
| T1.4 | Lint & language pass | IMP | ⬜ |

## Phase 2 — Server rebuild
| T2.0 | Server scaffolding | IMP | ⬜ |
| T2.1 | RoomStore + protocol v1 | IMP | ⬜ |
| T2.2 | Timer engine | IMP | ⬜ |
| T2.3 | Presence & rejoin | IMP | ⬜ |
| T2.4 | Hardening | IMP | ⬜ |
| T2.5 | Docker & deploy runbook | IMP | ⬜ |

## Phase 3 — Client multiplayer rebuild
| T3.1 | SocketService & state layer | IMP | ⬜ |
| T3.2 | Runtime server config + QR | IMP | ⬜ |
| T3.3 | Game screen rebuild | IMP | ⬜ |
| T3.4 | Notifications done right | IMP | ⬜ |
| T3.5 | UX & error polish | IMP | ⬜ |

## Phase 4 — Ship
| T4.1 | CI | IMP | ⬜ |
| T4.2 | Release build | IMP | ⬜ |
| T4.3 | Docs & README rewrite | SCR | ⬜ |
| T4.4 | Playtest protocol | CON+Matos | ⬜ |

## Backlog (ideas parked by R2 — Conductor triages)
- S1 Dart server rewrite · S2 Riverpod · S3 score history · S4 web calculator
  · S5 expansion content (mind C5) · S6 iOS

## Hand-off notes (append-only, newest first)

```
HANDOFF REV-adhoc (✅ docs-only) | 2026-07-05 | model: claude-fable-5 (REV) | branch: task/T0.2-repo-hygiene
Did: audited T0.1/T0.2 claims against the repo — all gate numbers verified honest (re-ran format/analyze/test). Two board fixes: (1) added 🟦 "gates green, awaiting Matos review" to the legend and moved T0.2 ✅→🟦 (its own hand-off says review pending); (2) flagged the unreported pubspec.lock drift (~66 transitive bumps from pub get) in the T0.3 pointer so BASELINE.md records it.
Gates: n/a (docs only; no lib/ or server/ files touched)
Surprises/debt: all 3 branches still local-only — Matos should push (C1). /mnt/c orchestra copy is a drift trap; consider reducing it to a pointer README. Optional: agents add Co-Authored-By trailer for provenance.
Next chat needs: unchanged — T0.3 per "Next up" (now includes the lockfile note).
```

```
HANDOFF T0.2 (✅ DONE — pending Matos review) | 2026-07-05 | model: glm-5.2 (IMP) | branch: task/T0.2-repo-hygiene (in ~/dev/scythe-companion)
Did: git rm -r --cached server/node_modules (2037 files, ~22MB) + gitignored it. Deleted dead commented-out code per A16: ASCII-art header in main.dart, commented imports (awesome_notifications/vibration/flutter_background_service duplicates), commented-out Vibration/notification/disposeListeners blocks across game.dart, socket_methods.dart, back_services.dart, create.dart, join.dart, home.dart, waiting_lobby.dart. Fixed README clone URL (old repo name scythe-coin-calculator → scythe-companion) + added orchestra/ pointer section. E2 closed: app/ move deferred to Phase 1 (see DECISIONS E2).
Gates: dart format 0 changes ✓; flutter analyze 2 errors + 57 info (all pre-existing: A11 env.dart + MaterialState deprecations) — no new issues introduced ✓; flutter test fails (pre-existing A15 widget_test.dart) ✓; working tree 3.2MB excl .git/assets/node_modules (< 5MB target) ✓; tracked files 180 (was 2044+).
Surprises/debt: None new. T0.2 is a pure hygiene diff — no logic changed. Matos should review the diff before merging. Branch is local-only (not pushed); GitHub visibility decision still pending.
Next chat needs: T0.3 Baseline & truth commit (IMP). Branch off task/T0.2-repo-hygiene. Record all failures verbatim in orchestra/BASELINE.md — the 2 analyze errors (A11) + 57 deprecation infos + test failure (A15) are the known baseline. Fix nothing except what blocks commands from running.
```

```
HANDOFF T0.1 (✅ DONE) | 2026-07-05 | model: claude-fable-5 (CON) | branch: task/T0.1-env-bringup (in ~/dev/scythe-companion)
Did: phone paired & connected over Wi-Fi (winner recorded in E3 — pairing code must be typed interactively). `flutter devices` lists SM S938B / Android 16 / API 36. Done-criteria met (doctor clean + device listed). E1 & E3 closed. T0.1 flipped ✅.
Gates: n/a (env task)
Surprises/debt: Matos still to run (non-blocking): (1) `echo 'export PATH="$HOME/develop/node/bin:$PATH"' >> ~/.bashrc` — node 22.23.1 is installed but not on PATH yet; (2) optional `sudo apt remove adb` (Debian v34 mismatch risk); (3) push branch task/T0.1-env-bringup. Connect port rotates after phone reboot — reconnect per E3, no re-pair.
Next chat needs: T0.2 Repo hygiene (IMP, cheap model). Read task card + A16 in 01_AUDIT.md. Repo at ~/dev/scythe-companion, branch off task/T0.1-env-bringup (has orchestra/ docs). E2 (app/ move) to be decided & recorded during T0.2.
```

```
HANDOFF T0.1 (🟨 continues) | 2026-07-05 | model: claude-fable-5 (CON) | branch: task/T0.1-env-bringup (in ~/dev/scythe-companion)
Did: repo cloned to ~/dev/scythe-companion ✓ (E1 closed). Node 22.23.1 installed at ~/develop/node ✓ (PATH line needs Matos — sandbox blocks .bashrc edits). adb server fixed: platform-tools v37 first in PATH, server starts clean, `adb devices` answers; found WSL pipe-hang gotcha + Debian adb v34 still installed (both recorded in E3). orchestra/+AGENTS.md+CLAUDE.md copied into repo on branch.
Gates: n/a (env task)
Surprises/debt: phone no longer answers at 192.168.1.117 — IP rotated or wireless debugging off; pairing needs Matos with phone in hand (fresh popup port+code). Matos to run: (1) PATH line for node, (2) optional `sudo apt remove adb`.
Next chat needs: ONLY phone pairing left for T0.1. Matos runs pair/connect per E3 runbook, records winner in E3, flips T0.1 ✅. Then T0.2 → cheap IMP.
```

```
HANDOFF T0.1 (🟨 continues) | 2026-07-04 | model: claude-fable-5 (CON) | branch: n/a (docs on /mnt/c; repo not cloned yet)
Did: closed D2/D4/D5/D6. Env: Flutter 3.44.4 + SDK 36 installed, doctor clean for Android (Chrome/Linux ✗ = accepted, D6). Phone pairing FAILED so far.
Gates: n/a (env task)
Surprises/debt: adb "protocol fault" on pair — suspect stale Debian adb server vs Google platform-tools; fix sequence + USB-tcpip fallback recorded in E3. Node v20→≥22 pending. Repo clone to ~/dev/scythe-companion pending. Copy orchestra/+AGENTS.md+CLAUDE.md into repo on a branch once cloned.
Next chat needs: CON (claude-fable-5, Claude Code) resumes T0.1 at phone pairing (read E3 first). Then close E3, flip T0.1 ✅, teach-back, hand T0.2 to cheap IMP.
```

