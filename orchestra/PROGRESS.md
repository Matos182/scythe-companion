# PROGRESS BOARD

Legend: ⬜ not started · 🟨 in progress (branch open) · ✅ done (gates green,
Matos reviewed) · 🟥 blocked. Every chat updates this file before ending
(protocol §4). "Next up" is the single source of truth for what happens next.

**Next up:** T0.2 — Repo hygiene (IMP, small; suggested model: MiniMax or
claude-haiku). Work in `~/dev/scythe-companion`, branch off
`task/T0.1-env-bringup` until Matos merges it (it carries orchestra/ docs).

## Phase 0 — Foundation
| Task | Title | Role | Status |
|---|---|---|---|
| T0.1 | Environment bring-up (WSL2) | CON+Matos | ✅ |
| T0.2 | Repo hygiene | IMP | ⬜ |
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

