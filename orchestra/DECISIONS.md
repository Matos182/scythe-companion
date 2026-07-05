# DECISIONS LOG

Closed decisions bind all chats (protocol R3). Format:
`ID | date | decision | chosen by | rationale (1 line)`.

## Gates (from 02_ARCHITECTURE.md) — Conductor closes these with Matos in chat #1

| ID | Question | Status | Outcome |
|---|---|---|---|
| D1 | Server hosting: (a) VPS always-on / (b) LAN / (c) both | ✅ closed 2026-07-04 by Matos (via Claude Fable 5, claude.ai) | **(a) VPS always-on** — Docker behind reverse proxy + TLS (`wss://`). T2.5 fully in scope; LAN mode → backlog |
| D2 | Drop MongoDB → in-memory RoomStore + TTL | ✅ closed 2026-07-04 by Matos (Conductor chat #1, claude-fable-5) | **(a) In-memory `RoomStore`** (plain Map) + TTL sweeper (idle > 3 h) + optional JSON snapshot on graceful shutdown. Kills A2/A5; accepted trade-off: server crash/restart drops live rooms (rooms are cheap to recreate) |
| D3 | State mgmt: Provider-done-right now, Riverpod as stretch | ✅ closed 2026-07-04 by Matos (via Claude Fable 5, claude.ai) | **Provider, done properly** (typed models + feature notifiers + repository layer). Riverpod stays stretch S2 |
| D4 | Short room codes + persistent playerId for rejoin | ✅ closed 2026-07-04 by Matos (Conductor chat #1, claude-fable-5) | **(a) Yes** — 6-char room codes (alphabet `ABCDEFGHJKMNPQRSTUVWXYZ23456789`) + server-minted `playerId` UUID stored in `shared_preferences`; reconnect = `rejoinRoom {roomCode, playerId}` → server remaps socket. Fixes A3 by design. Known limit: playerId is device-bound (seat-claim from another device → backlog if ever needed) |
| D5 | Keep socket.io; formal versioned protocol doc; wss via proxy | ✅ closed 2026-07-04 by Matos (Conductor chat #1, claude-fable-5) | **(a) Yes** — socket.io (client 3.x ↔ server 4.x); formal `docs/PROTOCOL.md` with every event + payload schema; `protocolVersion` in handshake so stale APKs fail loudly; TLS terminated at reverse proxy (`wss://`, per D1), plain `ws://` reserved for LAN-mode backlog |
| D6 | Android-only scope; other platform folders untouched | ✅ closed 2026-07-04 by Matos (Conductor chat #1, claude-fable-5) | **(a) Android-only.** `ios/ macos/ linux/ windows/` folders kept but frozen (never edited by models); web calculator build stays backlog S4, not roadmap |

## Environment records (filled during Phase 0)

| ID | What | Value |
|---|---|---|
| E1 | Repo working path in WSL | `~/dev/scythe-companion` (native ext4, NOT /mnt/c — builds 5–10× faster). ✅ cloned 2026-07-05 from `https://github.com/Matos182/scythe-companion` (public, default branch `master`) |
| E2 | Flutter project moved to `app/`? | ✅ closed 2026-07-05 (T0.2, glm-5.2) | **Deferred — stay at repo root for now.** The `lib/` restructure into `core/data/domain/features/` (02_ARCHITECTURE target layout) happens in Phase 1 (T1.1–T1.4). Moving to `app/` now and restructuring `lib/` next = double tooling churn (android paths, .gitignore, pubspec, CI). 02_ARCHITECTURE §"Note on app/ move" explicitly permits staying at root. Revisit the move as part of the Phase 1 restructure, one clean pass. |
| E3 | Flutter/Dart/Node versions + adb strategy | ✅ closed 2026-07-05 (chat #2): Debian 13 trixie. Flutter 3.44.4 / Dart 3.12.2 at `~/develop/flutter`; ANDROID_HOME=`~/develop/android-sdk`, SDK 36 + build-tools 36, cmdline-tools 12.0; OpenJDK 21 (no JDK 17 pkg on trixie). Doctor clean for Android (Chrome/Linux ✗ accepted per D6). **Node v22.23.1** manual tarball (checksum-verified) at `~/develop/node` — PATH line pending Matos: `export PATH="$HOME/develop/node/bin:$PATH"` in `~/.bashrc` (apt node v20 stays installed, gets shadowed; sandbox blocks agents editing shell profiles). **adb PARTLY RESOLVED**: `which adb` = platform-tools v37 ✓ and server now starts clean & answers `adb devices` ✓. Two gotchas found: (1) Debian apt `adb` v34 still installed at `/usr/bin/adb` — harmless while PATH order holds, but `sudo apt remove adb` (Matos, sudo) removes the v34/v37 server-mismatch risk = prime "protocol fault" suspect; (2) WSL quirk: `adb start-server` hangs when stdout is piped (daemon inherits the pipe fd) — use `adb start-server </dev/null >/dev/null 2>&1`. **Phone pairing RESOLVED 2026-07-05 — winner: Wi-Fi pairing code** (no USB fallback needed): Matos ran `adb pair 192.168.1.117:34921` in an interactive terminal — pairing code MUST be typed at the prompt (non-interactive → "adb: No pairing code provided"); device then connected as `192.168.1.117:38653` and `flutter devices` lists SM S938B / Android 16 / API 36 ✓. Pairing persists across reboots; only the *connect* port rotates — if the device drops, `adb connect <ip>:<port from Wireless-debugging main screen>` (no re-pair). Fallback if Wi-Fi debugging regresses: USB + Windows `adb tcpip 5555`, then WSL `adb connect <phone-ip>:5555` |
| E4 | Dependency versions chosen in T0.4 | — |

## Runtime decisions (append below as they happen)

*(none yet)*
