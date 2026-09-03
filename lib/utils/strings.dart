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

  static const notificationsTitle = 'On-screen turn alerts';
  static const notificationsSubtitle =
      'Buzz while you are looking at the game. Homed phones always alert.';
  static const aboutTileTitle = 'About';
}

/// About page. Copy is limited to facts we can stand behind: the MIT
/// LICENSE in this repo, Stonemaier LLC's own site footer ("Scythe is a
/// trademark of Stonemaier LLC"), and what this APK actually stores
/// and sends. Do not add affiliation, endorsement, or "official" claims.
class AboutStrings {
  const AboutStrings._();

  static const appName = 'Scythe Companion';
  static const version = '0.4.0';
  static const title = 'About';

  static const madeForFun =
      'Fábio Matos made this app for fun and to learn Flutter. '
      'It is a free helper for friends playing the physical board game '
      'Scythe at a table.';

  static const whatItDoes =
      'It can count final coins from popularity, stars, lands, '
      'resources, building bonus coins, and coins on hand. In a live '
      'room it also tracks turn order and per-player turn timers. It is '
      'not a digital edition of Scythe; you still need the board game.';

  static const unofficial =
      'This app is unofficial. It is not affiliated with, endorsed by, '
      'sponsored by, or associated with Stonemaier Games, Stonemaier LLC, '
      'or Jamey Stegmaier.';

  static const trademark =
      'Scythe is a trademark of Stonemaier LLC. The board game Scythe '
      'was designed by Jamey Stegmaier and is published by Stonemaier Games.';

  static const noOfficialContent =
      'This app does not include Stonemaier artwork, card text, or '
      'rulebook reproductions. Faction and player-mat names appear only '
      'as identifiers for seating a table.';

  static const license =
      'The source code of this app is licensed under the MIT License. '
      'It is provided "as is", without warranty of any kind.';

  static const sourceLabel = 'Source code';
  static const sourceUrl = 'https://github.com/Matos182/scythe-companion';

  static const privacy =
      'This app does not create user accounts and does not ship '
      'advertising or third-party analytics SDKs. On this device it '
      'stores your server URL, default nickname, room rejoin '
      'identifiers, and the notifications preference. If you join a '
      'multiplayer room, your nickname, faction, player mat, and turn '
      'events are sent to the game server you configured in Settings — '
      'that host is whoever runs the server, not Stonemaier. The camera '
      'is used only to scan a room QR code. Turn alerts use Android\'s '
      'notification permission if you grant it.';

  static const scoringDisclaimer =
      'Treat the physical game and its rulebook as authoritative. '
      'Double-check scores at the table if something looks off.';

  static const openSourceLicenses = 'Open-source licenses';
  static const legalese = 'Copyright (c) 2024-2026 Fábio Matos. MIT License. '
      'Unofficial fan-made helper. Scythe is a trademark of Stonemaier LLC.';

  static const sectionThisApp = 'This app';
  static const sectionLegal = 'Legal';
  static const sectionPrivacy = 'Privacy';
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
