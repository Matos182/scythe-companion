# Changelog

All notable user-facing changes are recorded here.

## v0.4.0 — first multiplayer-ready release

### Added

- Online rooms backed by the rebuilt Node/socket.io server.
- Server-resolved faction-wheel turn order.
- Per-player turn timers with pause, resume, pass-turn, and automatic timer cleanup.
- Presence and reconnect flow: disconnected players keep their seat and can rejoin by saved player id.
- Runtime server URL setting in the Android app.
- Lobby QR codes and in-app QR scanning for faster joining.
- Human-readable socket error messages and confirm-leave dialogs.
- Local Android “your turn” notification while the app is backgrounded.
- Docker + Caddy deployment guide for a TLS `https://` / `wss://` server.
- Signed-release APK runbook with keystore template, R8/proguard rules, and GitHub Release steps.
- GitHub Actions CI for Flutter and server gates.

### Changed

- Server state moved from MongoDB/Mongoose to an in-memory room store with TTL cleanup.
- Flutter multiplayer state moved behind typed models, `SocketService`, `GameRepository`, and Provider notifiers.
- The Android application id is now `com.matos.scythe_companion` instead of the Flutter template placeholder.
- App version bumped to `0.4.0+1`.

### Notes for players

- If you installed an old debug APK, uninstall it before installing v0.4.0.
- Multiplayer requires a running server. Set its URL from the home-screen gear icon before creating or joining rooms.
- External camera-app `scythe://` deep links are not supported yet; use the in-app Join Room → Scan QR flow.
