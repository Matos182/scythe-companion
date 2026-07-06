// SPDX-License-Identifier: MIT

/// Owns the socket: connection state, wire protocol, and typed event
/// streams. Replaces `SocketClient` + `SocketMethods` (audit A10).
///
/// Design rules (02_ARCHITECTURE "Connection lifecycle"):
/// - Handlers are registered ONCE, here — never in widgets.
/// - Widgets/pages consume broadcast streams via Provider; they never see
///   the raw socket.
/// - Reconnect/backoff is socket.io's job (see IoSocketAdapter); this
///   service only translates raw events into [SocketConnectionState].
/// - Before the first connect, the server's `protocolVersion` (from
///   `/healthz`) is checked against [expectedProtocolVersion] so a stale
///   APK fails loudly instead of misbehaving quietly (D5).
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../domain/models/room.dart';
import 'socket_adapter.dart';

/// Client-side view of the connection lifecycle.
enum SocketConnectionState {
  /// No socket, or explicitly disconnected.
  disconnected,

  /// First connection attempt (or manual reconnect) in flight.
  connecting,

  /// Live.
  connected,

  /// Dropped after being connected — socket.io is retrying with backoff.
  reconnecting,

  /// Server speaks a different protocol version — connection refused,
  /// user must update the app (D5).
  protocolMismatch,
}

/// Structured server error (T2.4 envelope: `{code, message}`).
class SocketError {
  const SocketError({required this.code, required this.message});

  final String code;
  final String message;

  /// The old server sent bare strings; T2.4 sends `{code, message}`.
  /// Accept both so a protocol drift degrades to a readable message.
  factory SocketError.fromWire(dynamic data) {
    if (data is Map) {
      return SocketError(
        code: data['code']?.toString() ?? 'UNKNOWN',
        message: data['message']?.toString() ?? 'Unknown error',
      );
    }
    return SocketError(code: 'UNKNOWN', message: data.toString());
  }

  @override
  String toString() => '[$code] $message';
}

/// A 1s server tick for the current player (server is the clock; the
/// client only renders — audit A2).
class TimerTick {
  const TimerTick({
    required this.roomCode,
    required this.playerId,
    required this.remainingSec,
  });

  final String roomCode;
  final String playerId;
  final int remainingSec;
}

/// Reads `protocolVersion` from the server's `/healthz` endpoint.
/// Returns null when the server is unreachable (the connect attempt will
/// surface its own error; we only hard-block on a *confirmed* mismatch).
Future<int?> healthzVersionProbe(String serverUrl) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
  try {
    final request = await client.getUrl(Uri.parse('$serverUrl/healthz'));
    final response = await request.close();
    if (response.statusCode != 200) return null;
    final body = await response.transform(utf8.decoder).join();
    final json = jsonDecode(body) as Map<String, dynamic>;
    return (json['protocolVersion'] as num?)?.toInt();
  } catch (_) {
    return null;
  } finally {
    client.close();
  }
}

class SocketService {
  SocketService({
    required SocketAdapter adapter,
    Future<int?> Function()? versionProbe,
  })  : _adapter = adapter,
        _versionProbe = versionProbe {
    _registerHandlers();
  }

  /// Wire protocol this client build understands (docs/PROTOCOL.md).
  static const int expectedProtocolVersion = 1;

  final SocketAdapter _adapter;
  final Future<int?> Function()? _versionProbe;

  SocketConnectionState _state = SocketConnectionState.disconnected;
  bool _wasConnected = false;
  bool _versionChecked = false;

  final _stateController = StreamController<SocketConnectionState>.broadcast();
  final _roomJoinedController = StreamController<Room>.broadcast();
  final _roomUpdatesController = StreamController<Room>.broadcast();
  final _tickController = StreamController<TimerTick>.broadcast();
  final _errorController = StreamController<SocketError>.broadcast();

  // ── Public surface ────────────────────────────────────────────────

  SocketConnectionState get state => _state;

  /// Connection lifecycle, for banners/spinners and rejoin triggers.
  Stream<SocketConnectionState> get connectionStates => _stateController.stream;

  /// Fires when THIS client enters a room: createRoomSuccess,
  /// joinRoomSuccess (also after rejoin). Navigation hangs off this.
  Stream<Room> get roomJoined => _roomJoinedController.stream;

  /// Every full-room refresh: updateRoom, newTurn, and both success
  /// events (so state listeners need only one subscription).
  Stream<Room> get roomUpdates => _roomUpdatesController.stream;

  /// 1s countdown ticks for the active player.
  Stream<TimerTick> get ticks => _tickController.stream;

  /// Structured server errors (T2.4 envelope).
  Stream<SocketError> get errors => _errorController.stream;

  /// Current socket id (matches `socketID` on our player server-side).
  String? get socketId => _adapter.id;

  /// Checks the protocol version once, then opens the socket.
  /// No-op when already connected. Safe to call before every emit.
  Future<void> connect() async {
    if (_state == SocketConnectionState.connected ||
        _state == SocketConnectionState.connecting ||
        _state == SocketConnectionState.reconnecting) {
      return;
    }
    if (!_versionChecked && _versionProbe != null) {
      final serverVersion = await _versionProbe();
      if (serverVersion != null && serverVersion != expectedProtocolVersion) {
        _setState(SocketConnectionState.protocolMismatch);
        _errorController.add(SocketError(
          code: 'PROTOCOL_MISMATCH',
          message: 'Server protocol v$serverVersion, app expects '
              'v$expectedProtocolVersion — update the app.',
        ));
        return;
      }
      // Unreachable server (null) falls through: the socket connect will
      // fail visibly on its own, and we re-probe on the next connect().
      if (serverVersion != null) _versionChecked = true;
    }
    _setState(SocketConnectionState.connecting);
    _adapter.connect();
  }

  void disconnect() {
    _setState(SocketConnectionState.disconnected);
    _adapter.disconnect();
  }

  // ── Emits (payload shapes per docs/PROTOCOL.md) ───────────────────

  void createRoom({
    required String nickname,
    required String faction,
    required String mat,
    required int timerSec,
  }) {
    _adapter.emit('createRoom', {
      'nickname': nickname,
      'playerfaction': faction,
      'playermat': mat,
      'timer': timerSec,
    });
  }

  void joinRoom({
    required String nickname,
    required String roomCode,
    required String faction,
    required String mat,
  }) {
    _adapter.emit('joinRoom', {
      'nickname': nickname,
      'roomId': roomCode,
      'playerfaction': faction,
      'playermat': mat,
    });
  }

  void startGame(String roomCode) =>
      _adapter.emit('startGame', {'roomId': roomCode});

  void passTurn(String roomCode) => _adapter.emit('turn', {'roomId': roomCode});

  void pause(String roomCode) => _adapter.emit('pause', {'roomId': roomCode});

  /// Wire name stays `toContinue` (protocol v1). The old client also sent
  /// `atualTurn` — dropped: the server is authoritative for turnIndex.
  void resume(String roomCode) =>
      _adapter.emit('toContinue', {'roomId': roomCode});

  void rejoinRoom({required String roomCode, required String playerId}) =>
      _adapter.emit('rejoinRoom', {
        'roomCode': roomCode,
        'playerId': playerId,
      });

  // ── Internals ─────────────────────────────────────────────────────

  /// The ONLY place socket handlers are registered (A10 fix).
  void _registerHandlers() {
    _adapter.on('connect', (_) {
      _wasConnected = true;
      _setState(SocketConnectionState.connected);
    });
    _adapter.on('disconnect', (_) {
      // socket.io auto-retries after an unexpected drop; a manual
      // disconnect() already moved state to disconnected.
      if (_state == SocketConnectionState.disconnected) return;
      _setState(_wasConnected
          ? SocketConnectionState.reconnecting
          : SocketConnectionState.disconnected);
    });
    _adapter.on('connect_error', (_) {
      // Includes rate-limit rejections (T2.4: middleware errors surface
      // as connect_error, not the structured envelope).
      if (_state == SocketConnectionState.connecting) {
        _setState(SocketConnectionState.reconnecting);
      }
    });

    _adapter.on('createRoomSuccess', (data) => _onJoined(data));
    _adapter.on('joinRoomSuccess', (data) => _onJoined(data));
    _adapter.on('updateRoom', (data) => _onRoom(data));
    _adapter.on('newTurn', (data) => _onRoom(data));

    _adapter.on('tick', (data) {
      if (data is! Map) return;
      _tickController.add(TimerTick(
        roomCode: data['roomCode']?.toString() ?? '',
        playerId: data['playerId']?.toString() ?? '',
        remainingSec: (data['remainingSec'] as num?)?.toInt() ?? 0,
      ));
    });

    _adapter.on('errorOccurred',
        (data) => _errorController.add(SocketError.fromWire(data)));
  }

  void _onJoined(dynamic data) {
    final room = _parseRoom(data);
    if (room == null) return;
    _roomJoinedController.add(room);
    _roomUpdatesController.add(room);
  }

  void _onRoom(dynamic data) {
    final room = _parseRoom(data);
    if (room == null) return;
    _roomUpdatesController.add(room);
  }

  /// One readable failure path instead of a crash (02_ARCHITECTURE
  /// "Typed models").
  Room? _parseRoom(dynamic data) {
    try {
      return Room.fromJson(Map<String, dynamic>.from(data as Map));
    } catch (e) {
      _errorController.add(SocketError(
        code: 'CLIENT_BAD_PAYLOAD',
        message: 'Could not parse room state: $e',
      ));
      return null;
    }
  }

  void _setState(SocketConnectionState next) {
    if (next == _state) return;
    _state = next;
    _stateController.add(next);
  }

  void dispose() {
    _adapter.dispose();
    _stateController.close();
    _roomJoinedController.close();
    _roomUpdatesController.close();
    _tickController.close();
    _errorController.close();
  }
}
