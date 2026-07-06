// SPDX-License-Identifier: MIT

/// Test double for [SocketAdapter]: a scriptable fake socket.
///
/// Tests emit server events with [serverEmit], inspect client emits via
/// [sentEvents], and simulate drops/reconnects with [simulateDrop] /
/// [simulateReconnect]. No network, no socket.io.
library;

import 'package:scythe_companion/data/socket_adapter.dart';

class SentEvent {
  SentEvent(this.name, this.payload);
  final String name;
  final Map<String, dynamic> payload;
}

class FakeSocketAdapter implements SocketAdapter {
  final Map<String, List<void Function(dynamic)>> _handlers = {};
  final List<SentEvent> sentEvents = [];

  String? _id;
  bool _connected = false;
  int connectCalls = 0;

  /// Next socket id to assign on connect (socket.io mints a new id per
  /// connection — reconnects change it, tests must model that).
  String nextId = 'socket-1';

  @override
  String? get id => _id;

  @override
  bool get isConnected => _connected;

  @override
  void connect() {
    connectCalls++;
    _connected = true;
    _id = nextId;
    _fire('connect', null);
  }

  @override
  void disconnect() {
    _connected = false;
    _id = null;
    _fire('disconnect', 'io client disconnect');
  }

  @override
  void emit(String event, Map<String, dynamic> payload) {
    sentEvents.add(SentEvent(event, payload));
  }

  @override
  void on(String event, void Function(dynamic data) handler) {
    _handlers.putIfAbsent(event, () => []).add(handler);
  }

  @override
  void dispose() {
    _handlers.clear();
    _connected = false;
  }

  // ── Test controls ─────────────────────────────────────────────────

  /// Deliver a server→client event.
  void serverEmit(String event, dynamic data) => _fire(event, data);

  /// Unexpected drop (Wi-Fi blip): socket.io fires 'disconnect' and
  /// starts retrying internally.
  void simulateDrop() {
    _connected = false;
    _id = null;
    _fire('disconnect', 'transport close');
  }

  /// Backoff retry succeeded: new socket id, 'connect' fires again.
  void simulateReconnect(String newId) {
    nextId = newId;
    _connected = true;
    _id = newId;
    _fire('connect', null);
  }

  /// How many handlers are registered for [event] (A10 regression guard).
  int handlerCount(String event) => _handlers[event]?.length ?? 0;

  void _fire(String event, dynamic data) {
    final handlers = _handlers[event];
    if (handlers == null) return;
    for (final h in List.of(handlers)) {
      h(data);
    }
  }
}
