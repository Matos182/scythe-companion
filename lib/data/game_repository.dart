// SPDX-License-Identifier: MIT

/// Coordinates [SocketService] + [SessionStore] (02_ARCHITECTURE, D3).
///
/// Responsibilities:
/// - Identify "me": on room entry, match our socket id against the
///   players list and remember the server-minted playerId (D4).
/// - Persist `{roomCode, playerId}` so a drop, app restart, or Wi-Fi
///   blip can be healed with `rejoinRoom`.
/// - Auto-rejoin: when the socket reconnects and a session exists,
///   emit `rejoinRoom` without the user doing anything.
///
/// Widgets talk to this (via notifiers) — never to the socket.
library;

import 'dart:async';

import '../domain/models/room.dart';
import 'session_store.dart';
import 'settings_repository.dart';
import 'socket_adapter.dart';
import 'socket_service.dart';

class GameRepository {
  GameRepository({
    required SocketService socketService,
    required SessionStore sessionStore,
    required SettingsRepository settingsRepository,
    String? initialServerUrl,
  })  : _socket = socketService,
        _sessions = sessionStore,
        _settings = settingsRepository,
        _currentServerUrl = initialServerUrl {
    _joinedSub = _socket.roomJoined.listen(_onJoined);
    _stateSub = _socket.connectionStates.listen(_onConnectionState);
  }

  final SocketService _socket;
  final SessionStore _sessions;
  final SettingsRepository _settings;

  late final StreamSubscription<Room> _joinedSub;
  late final StreamSubscription<SocketConnectionState> _stateSub;

  String? _myPlayerId;
  String? _roomCode;
  bool _everJoined = false;
  String? _currentServerUrl;

  // ── Read surface for notifiers ────────────────────────────────────

  /// This device's server-minted playerId (null before first join).
  String? get myPlayerId => _myPlayerId;

  Stream<Room> get roomUpdates => _socket.roomUpdates;
  Stream<Room> get roomJoined => _socket.roomJoined;
  Stream<SocketConnectionState> get connectionStates =>
      _socket.connectionStates;
  Stream<TimerTick> get ticks => _socket.ticks;
  Stream<SocketError> get errors => _socket.errors;
  SocketConnectionState get connectionState => _socket.state;

  /// URL the socket adapter is currently bound to. Set in main()
  /// and updated by [setServerUrl]. The lobby encodes this into the
  /// QR payload so a scanned join lands on the right server (T3.2).
  String? get currentServerUrl => _currentServerUrl;

  // ── Actions ───────────────────────────────────────────────────────

  Future<void> connect() => _socket.connect();

  /// Read-side helper for the Settings page.
  Future<AppSettings> loadSettings() => _settings.load();

  /// Synchronous nickname accessor for the create/join pages to pre-fill
  /// their text controllers. Returns null on the very first frame
  /// (before SharedPreferences resolves); the pages fall back to
  /// empty/typed input in that case, which is the same UX as T3.1.
  Future<String?> loadNickname() async {
    final settings = await _settings.load();
    return settings.nickname;
  }

  /// Persist user settings AND, if a URL was provided, swap the
  /// underlying adapter so the next connect() goes to the new server.
  ///
  /// Blank URL is treated as "keep whatever I already had", not "reset
  /// to the compile-time default" — clearing to default and reconnecting
  /// would silently break a friend who's already mid-game on a
  /// manually-entered LAN IP.
  ///
  /// Returns the URL the adapter is bound to after the save.
  Future<String?> saveSettings(AppSettings settings) async {
    final normalizedUrl = _normalizeUrl(settings.serverUrl);
    final next = AppSettings(
      // Persist the URL we already run on when the field was blank, so
      // the next launch restores it (main() reads settings at startup).
      serverUrl: normalizedUrl ?? _currentServerUrl,
      nickname: _normalizeNickname(settings.nickname),
    );
    await _settings.save(next);
    if (normalizedUrl != null && normalizedUrl != _currentServerUrl) {
      _applyServerUrl(normalizedUrl);
    }
    return _currentServerUrl;
  }

  static String? _normalizeUrl(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    final withScheme = trimmed.contains('://') ? trimmed : 'http://$trimmed';
    // Strip trailing slash so `http://x:3000/` and `http://x:3000` are the
    // same — socket.io doesn't care but QR round-trips are cleaner.
    return withScheme.endsWith('/')
        ? withScheme.substring(0, withScheme.length - 1)
        : withScheme;
  }

  static String? _normalizeNickname(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  /// Switch to a different socket.io server at runtime (T3.2: QR scan
  /// pointed at a new host, or Settings save).
  ///
  /// Persists the URL (so the next launch restores it) and swaps the
  /// live adapter. Returns the normalized URL actually applied.
  Future<String> setServerUrl(String url) async {
    final normalized = _normalizeUrl(url) ?? url;
    final current = await _settings.load();
    await _settings.save(current.copyWith(serverUrl: normalized));
    if (normalized != _currentServerUrl) {
      _applyServerUrl(normalized);
    }
    return normalized;
  }

  /// Swap the live transport to [url] WITHOUT persisting.
  ///
  /// Builds a fresh [IoSocketAdapter] + `/healthz` version probe bound
  /// to [url], asks the [SocketService] to swap both, and forgets any
  /// auto-rejoin state — the new server has no idea who we are, so
  /// rejoin would just generate a confusing `errorOccurred`. The
  /// persisted `session.*` prefs are NOT cleared: the user might want
  /// to come back to the old server, and a clean reconnect there can
  /// still use them.
  void _applyServerUrl(String url) {
    _socket.swapAdapter(
      IoSocketAdapter(url),
      versionProbe: () => healthzVersionProbe(url),
    );
    _everJoined = false;
    _myPlayerId = null;
    _roomCode = null;
    _currentServerUrl = url;
  }

  Future<void> createRoom({
    required String nickname,
    required String faction,
    required String mat,
    required int timerSec,
  }) async {
    await _socket.connect();
    _socket.createRoom(
      nickname: nickname,
      faction: faction,
      mat: mat,
      timerSec: timerSec,
    );
  }

  Future<void> joinRoom({
    required String nickname,
    required String roomCode,
    required String faction,
    required String mat,
  }) async {
    await _socket.connect();
    _socket.joinRoom(
      nickname: nickname,
      roomCode: roomCode,
      faction: faction,
      mat: mat,
    );
  }

  /// Rejoin a previous session explicitly (e.g. after app restart).
  /// Returns false when there is nothing to resume.
  Future<bool> rejoinSavedSession() async {
    final session = await _sessions.load();
    if (session == null) return false;
    _roomCode = session.roomCode;
    _myPlayerId = session.playerId;
    _everJoined = true;
    await _socket.connect();
    _socket.rejoinRoom(
      roomCode: session.roomCode,
      playerId: session.playerId,
    );
    return true;
  }

  void startGame(String roomCode) => _socket.startGame(roomCode);
  void passTurn(String roomCode) => _socket.passTurn(roomCode);
  void pause(String roomCode) => _socket.pause(roomCode);
  void resume(String roomCode) => _socket.resume(roomCode);

  /// Leave the multiplayer flow: forget the session so the next launch
  /// doesn't try to resurrect a dead room.
  Future<void> leaveSession() async {
    _myPlayerId = null;
    _roomCode = null;
    _everJoined = false;
    await _sessions.clear();
    _socket.disconnect();
  }

  // ── Internals ─────────────────────────────────────────────────────

  void _onJoined(Room room) {
    _roomCode = room.id;
    // "Me" = the seated player whose socketID matches this connection.
    // (The old client compared socket.id against a player _id — a bug
    // by construction, see T1.2 hand-off.)
    final mySocketId = _socket.socketId;
    for (final player in room.players) {
      if (player.socketID == mySocketId && player.id.isNotEmpty) {
        _myPlayerId = player.id;
        break;
      }
    }
    _everJoined = true;
    final playerId = _myPlayerId;
    if (playerId != null && room.id.isNotEmpty) {
      // Fire-and-forget: persisting must not block the UI stream.
      unawaited(
        _sessions.save(GameSession(roomCode: room.id, playerId: playerId)),
      );
    }
  }

  void _onConnectionState(SocketConnectionState state) {
    // Auto-heal: socket came back after a drop while we were seated.
    if (state == SocketConnectionState.connected &&
        _everJoined &&
        _roomCode != null &&
        _myPlayerId != null) {
      _socket.rejoinRoom(roomCode: _roomCode!, playerId: _myPlayerId!);
    }
  }

  void dispose() {
    _joinedSub.cancel();
    _stateSub.cancel();
  }
}
