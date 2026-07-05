// SPDX-License-Identifier: MIT
//
// T0.4: The old background service (flutter_background_service +
// awesome_notifications) was structurally broken — it spawned an isolate
// that created its own phantom socket connection (audit A9). Both packages
// were removed. This file is kept as a placeholder; the full notification
// replacement lands in T3.4 using flutter_local_notifications fired from
// the foreground socket listener.
//
// TODO[T3.4]: implement "your turn" local notification via
// flutter_local_notifications, fired from SocketService on newTurn when
// the app is backgrounded. No background isolate, no phantom socket.

// Intentionally empty — no background service in T0.4.
