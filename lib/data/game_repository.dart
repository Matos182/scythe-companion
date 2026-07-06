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
import 'socket_service.dart';

class GameRepository {
  GameRepository({
    required SocketService socketService,
    required SessionStore sessionStore,
  })  : _socket = socketService,
        _sessions = sessionStore {
    _joinedSub = _socket.roomJoined.listen(_onJoined);
    _stateSub = _socket.connectionStates.listen(_onConnectionState);
  }

  final SocketService _socket;
  final SessionStore _sessions;

  late final StreamSubscription<Room> _joinedSub;
  late final StreamSubscription<SocketConnectionState> _stateSub;

  String? _myPlayerId;
  String? _roomCode;
  bool _everJoined = false;

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

  // ── Actions ───────────────────────────────────────────────────────

  Future<void> connect() => _socket.connect();

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
