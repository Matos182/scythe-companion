// SPDX-License-Identifier: MIT

/// Thin seam over the raw socket.io client.
///
/// `SocketService` talks to this interface instead of `socket_io_client`
/// directly so unit tests can drive the full connection lifecycle
/// (connect → join → turn → drop → rejoin) with a fake, no network needed.
library;

import 'package:socket_io_client/socket_io_client.dart' as io;

/// Minimal socket surface the service needs.
abstract class SocketAdapter {
  /// Base URL this transport connects to, used in actionable client errors.
  String get serverUrl;

  /// Current socket id, or null when disconnected.
  String? get id;

  bool get isConnected;

  void connect();

  void disconnect();

  /// Emit [event] with a JSON [payload]. Safe to call while connecting:
  /// socket.io buffers outgoing packets until the connection is up.
  void emit(String event, Map<String, dynamic> payload);

  /// Register a handler for [event]. Called once per event by the service
  /// (never from widgets — audit A10).
  void on(String event, void Function(dynamic data) handler);

  void dispose();
}

/// Production adapter wrapping `socket_io_client` 3.x.
///
/// Reconnection with exponential backoff is delegated to socket.io itself
/// (`reconnectionDelay` doubles up to `reconnectionDelayMax` with jitter) —
/// no hand-rolled retry loop to get wrong.
class IoSocketAdapter implements SocketAdapter {
  IoSocketAdapter(this.serverUrl)
      : _socket = io.io(serverUrl, <String, dynamic>{
          'transports': ['websocket'],
          'autoConnect': false,
          'reconnection': true,
          'reconnectionDelay': 1000,
          'reconnectionDelayMax': 10000,
          'randomizationFactor': 0.5,
        });

  @override
  final String serverUrl;

  final io.Socket _socket;

  @override
  String? get id => _socket.id;

  @override
  bool get isConnected => _socket.connected;

  @override
  void connect() => _socket.connect();

  @override
  void disconnect() => _socket.disconnect();

  @override
  void emit(String event, Map<String, dynamic> payload) =>
      _socket.emit(event, payload);

  @override
  void on(String event, void Function(dynamic data) handler) =>
      _socket.on(event, handler);

  @override
  void dispose() => _socket.dispose();
}
