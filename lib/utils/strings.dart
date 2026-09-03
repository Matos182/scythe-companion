// SPDX-License-Identifier: MIT

/// T3.5: central registry for user-facing strings introduced by the
/// UX-polish pass.
///
/// Scope is deliberately narrow: only the new T3.5 copy (error
/// humanisation, confirm-leave dialogs, loading/empty states, the
/// rate-limited banner). Mass-rewriting every page's labels is out of
/// scope for T3.5 — the goal is to make NEW strings trivially
/// translatable later, not to retrofit every existing string at once.
///
/// AGENTS.md C6 says "user-facing strings centralized so PT
/// localization stays cheap (Phase 3)". The Phase 3 backlog item
/// owns the global migration; this file is the seed for it.
library;

/// Confirm-leave dialog copy (GamePage + WaitingLobby).
class LeaveDialogStrings {
  const LeaveDialogStrings._();

  static const gameTitle = 'Leave the game?';
  static const gameMessage =
      'Your seat will be freed and the timer will auto-pause for '
      "whoever's turn it is.";

  static const lobbyTitle = 'Leave the lobby?';
  static const lobbyMessage =
      "You'll lose your seat. The creator can keep playing without "
      'you, or you can rejoin from the home menu.';

  static const cancelLabel = 'Stay';
  static const confirmLabel = 'Leave';
  static const disconnectTitle = 'Connection lost';
  static const disconnectMessage = 'You appear to be offline. Reconnect?';
  static const reconnectLabel = 'Retry';
}

/// Connection-state UI (banners, pills, spinners).
class ConnectionStrings {
  const ConnectionStrings._();

  static const connecting = 'Connecting…';
  static const reconnecting = 'Connection lost — reconnecting…';
  static const disconnected = 'Disconnected from server';
  static const protocolMismatch = 'Server protocol mismatch';

  /// Short pill used on Create/Join/Settings so the user knows the
  /// app is mid-handshake without a full-screen spinner.
  static const connectingPill = 'Connecting…';
  static const retryingPill = "Can't reach server — retrying…";

  static String serverFooter(String? serverUrl) =>
      'Server: ${serverUrl ?? 'not configured'}';
}

/// Settings-page feedback introduced by the connection probe.
class SettingsStrings {
  const SettingsStrings._();

  static String probeSaved(int version) =>
      'Server OK (protocol v$version) — saved.';
}

/// Empty-state copy.
class EmptyStateStrings {
  const EmptyStateStrings._();

  static const noPlayers = 'Waiting for the first player…';
  static const noScores = 'No scores yet — add a player to get started.';
  static const noQRScan = 'Point the camera at the room QR.';
}

/// Form validation snackbars (Create/Join — T3.5 mirrors the server's
/// VAL_MISSING_NICKNAME / VAL_MISSING_ROOM_ID envelopes so the user
/// gets faster feedback than a round-trip).
class ValidationStrings {
  const ValidationStrings._();

  static const nicknameRequiredCreate =
      'Please enter a nickname before creating a room.';
  static const nicknameRequiredJoin =
      'Please enter a nickname before joining a room.';
  static const roomCodeRequired =
      "Please enter a room code (or scan the creator's QR).";
}

/// QR scanner copy.
class QrScannerStrings {
  const QrScannerStrings._();

  static const title = 'Scan Room QR';
  static const scannedPrefix = 'Scanned room';
  static const scannedOnSuffix = 'on';
  static const cameraDenied =
      'Camera permission was denied. Grant it in Android Settings '
      'to scan a QR code.';
}

/// Game-page specific.
class GameStrings {
  const GameStrings._();

  static const title = 'Scythe Game';
  static const turnBannerPrefix = "Turn:"; // shown beside player name
  static const roundLabel = 'Round';
  static const timeRemaining = 'Turn Time Remaining:';
  static const passTurn = 'Pass Turn';
  static const pausedLabel = 'GAME IS PAUSED!';
  static const offlineSuffix = '(offline)';
}

/// T5.7 combat pause — short English copy, no faction lore.
class CombatStrings {
  const CombatStrings._();

  static const start = 'Combat';
  static const startTooltip = 'Pause the clock — fight on the table';
  static const overlayTitle = 'COMBAT';
  static const overlayBody = 'Clocks stopped. Resolve the fight on the board.';
  static const resolved = 'Resolved';
  static const waiting = 'Fight in progress';
}
