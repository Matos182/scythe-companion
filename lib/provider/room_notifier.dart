// SPDX-License-Identifier: MIT

/// Multiplayer room state for the widget tree (D3: Provider done right).
///
/// Subscribes ONCE to the repository's streams; widgets rebuild off
/// `notifyListeners` and read typed getters. No widget ever touches the
/// socket, and no navigation happens here — the single guarded listener
/// in main.dart consumes [justJoined] / [lastError].
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/game_repository.dart';
import '../data/socket_service.dart';
import '../domain/models/room.dart';

class RoomNotifier extends ChangeNotifier {
  RoomNotifier(this._repository) {
    _roomSub = _repository.roomUpdates.listen(_onRoom);
    _joinedSub = _repository.roomJoined.listen(_onJoined);
    _tickSub = _repository.ticks.listen(_onTick);
    _errorSub = _repository.errors.listen(_onError);
    _stateSub = _repository.connectionStates.listen(_onConnectionState);
  }

  final GameRepository _repository;

  late final StreamSubscription<Room> _roomSub;
  late final StreamSubscription<Room> _joinedSub;
  late final StreamSubscription<TimerTick> _tickSub;
  late final StreamSubscription<SocketError> _errorSub;
  late final StreamSubscription<SocketConnectionState> _stateSub;

  Room _room = const Room();
  SocketError? _lastError;
  bool _justJoined = false;

  // ── Read surface for widgets ──────────────────────────────────────

  Room get room => _room;

  SocketConnectionState get connectionState => _repository.connectionState;

  /// Last server error, cleared with [clearError] after display.
  SocketError? get lastError => _lastError;

  /// One-shot flag: set when THIS client enters a room
  /// (create/join/rejoin success). The navigation listener in main.dart
  /// consumes it via [consumeJoinedFlag].
  bool get justJoined => _justJoined;

  /// Am I seated in this room? (identity via playerId, D4 — not socket
  /// id, which changes on every reconnect)
  bool get isSeated => _repository.myPlayerId != null;

  /// Is it my turn?
  bool get isMyTurn =>
      isSeated &&
      _room.turn.id.isNotEmpty &&
      _room.turn.id == _repository.myPlayerId;

  /// Am I the room creator (start rights)?
  bool get isCreator =>
      isSeated &&
      _room.creator.id.isNotEmpty &&
      _room.creator.id == _repository.myPlayerId;

  // ── Actions (thin passthroughs) ───────────────────────────────────

  Future<void> createRoom({
    required String nickname,
    required String faction,
    required String mat,
    required int timerSec,
  }) =>
      _repository.createRoom(
        nickname: nickname,
        faction: faction,
        mat: mat,
        timerSec: timerSec,
      );

  Future<void> joinRoom({
    required String nickname,
    required String roomCode,
    required String faction,
    required String mat,
  }) =>
      _repository.joinRoom(
        nickname: nickname,
        roomCode: roomCode,
        faction: faction,
        mat: mat,
      );

  void startGame() => _repository.startGame(_room.id);
  void passTurn() => _repository.passTurn(_room.id);
  void pause() => _repository.pause(_room.id);
  void resume() => _repository.resume(_room.id);

  Future<void> leaveSession() async {
    await _repository.leaveSession();
    _room = const Room();
    notifyListeners();
  }

  bool consumeJoinedFlag() {
    final was = _justJoined;
    _justJoined = false;
    return was;
  }

  void clearError() => _lastError = null;

  // ── Stream handlers ───────────────────────────────────────────────

  void _onRoom(Room room) {
    _room = room;
    notifyListeners();
  }

  void _onJoined(Room room) {
    _justJoined = true;
    // roomUpdates also carries this room; notify happens in _onRoom.
  }

  /// Fold a 1s tick into the current state (server is the clock; the
  /// client only renders — A2).
  void _onTick(TimerTick tick) {
    if (tick.roomCode != _room.id) return;
    final players = _room.players
        .map((p) => p.id == tick.playerId
            ? p.copyWith(remainingSec: tick.remainingSec)
            : p)
        .toList();
    final turn = _room.turn.id == tick.playerId
        ? _room.turn.copyWith(remainingSec: tick.remainingSec)
        : _room.turn;
    _room = _room.copyWith(players: players, turn: turn);
    notifyListeners();
  }

  void _onError(SocketError error) {
    _lastError = error;
    notifyListeners();
  }

  void _onConnectionState(SocketConnectionState _) => notifyListeners();

  @override
  void dispose() {
    _roomSub.cancel();
    _joinedSub.cancel();
    _tickSub.cancel();
    _errorSub.cancel();
    _stateSub.cancel();
    super.dispose();
  }
}
