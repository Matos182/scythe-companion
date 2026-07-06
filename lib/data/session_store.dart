// SPDX-License-Identifier: MIT

/// Persists the rejoin credentials (D4): the server-minted `playerId`
/// UUID and the 6-char room code. Surviving an app restart or a socket
/// drop, these two strings are all the server needs to remap the seat
/// (`rejoinRoom {roomCode, playerId}`).
library;

import 'package:shared_preferences/shared_preferences.dart';

/// A saved multiplayer session (one room at a time).
class GameSession {
  const GameSession({required this.roomCode, required this.playerId});

  final String roomCode;
  final String playerId;
}

abstract class SessionStore {
  Future<GameSession?> load();
  Future<void> save(GameSession session);
  Future<void> clear();
}

/// Production store backed by `shared_preferences` (D4).
class SharedPrefsSessionStore implements SessionStore {
  static const _roomCodeKey = 'session.roomCode';
  static const _playerIdKey = 'session.playerId';

  @override
  Future<GameSession?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final roomCode = prefs.getString(_roomCodeKey);
    final playerId = prefs.getString(_playerIdKey);
    if (roomCode == null || playerId == null) return null;
    return GameSession(roomCode: roomCode, playerId: playerId);
  }

  @override
  Future<void> save(GameSession session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_roomCodeKey, session.roomCode);
    await prefs.setString(_playerIdKey, session.playerId);
  }

  @override
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_roomCodeKey);
    await prefs.remove(_playerIdKey);
  }
}

/// In-memory store for unit tests.
class InMemorySessionStore implements SessionStore {
  GameSession? _session;

  @override
  Future<GameSession?> load() async => _session;

  @override
  Future<void> save(GameSession session) async => _session = session;

  @override
  Future<void> clear() async => _session = null;
}
