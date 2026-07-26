// SPDX-License-Identifier: MIT

/// Pure-Dart codec for the `scythe://join?server=…&room=…` deep-link
/// payload exchanged via QR code (T3.2).
///
/// Lives in `lib/utils/` and imports nothing from Flutter — unit-testable
/// in isolation, no widget context, no shared_preferences.
///
/// Wire shape: `scythe://join?server=<urlencoded>&room=<code>`
/// - `server` is the full base URL (scheme + host[:port], no trailing slash)
///   the host is *currently* pointed at. Encoded so `://`, `?` and `&`
///   inside the value cannot be mistaken for URI delimiters.
/// - `room` is the 6-char room code, uppercased on decode.
///
/// Round-trip invariant: for any (server, room), `parse(encode(s, r))`
/// returns `(s, r)`. Tested in `test/utils/qr_payload_test.dart`.
library;

/// Custom URI scheme used by the in-app scanner. External camera-app
/// launch is deliberately not wired yet (no Android VIEW intent-filter
/// or app_links handler), but the payload shape leaves that path open.
/// Picked over `https://` to keep the payload obviously app-internal and
/// to avoid registering a real domain we don't own.
const String scytheScheme = 'scythe';
const String _joinHost = 'join';

/// Encoded form of a "join this room on this server" payload.
///
/// Value semantics (`==`/`hashCode`) so round-trip tests and callers can
/// compare decoded payloads directly.
class JoinPayload {
  const JoinPayload({required this.server, required this.roomCode});

  /// Base URL of the socket.io server (no trailing slash).
  final String server;

  /// 6-char room code, expected uppercased by the server.
  final String roomCode;

  @override
  bool operator ==(Object other) =>
      other is JoinPayload &&
      other.server == server &&
      other.roomCode == roomCode;

  @override
  int get hashCode => Object.hash(server, roomCode);

  @override
  String toString() => 'JoinPayload(server: $server, roomCode: $roomCode)';
}

/// Encode a [JoinPayload] as `scythe://join?server=…&room=…`.
///
/// Empty fields produce an obviously-bad payload (`server=`, `room=`)
/// rather than throwing — QR scanning is a hostile input surface and
/// failing loudly at decode time is friendlier than a null-check at
/// every call site.
String encodeJoin(JoinPayload payload) {
  final encodedServer = Uri.encodeComponent(payload.server);
  final encodedRoom = Uri.encodeComponent(payload.roomCode);
  return '$scytheScheme://$_joinHost?server=$encodedServer&room=$encodedRoom';
}

/// Decode a payload string. Returns null when [raw] is not a
/// `scythe://join?…` shape, when the required query params are missing,
/// or when either value is empty after URL-decoding.
///
/// We deliberately accept *any* scheme+host and check them explicitly
/// here rather than relying on `Uri.parse` alone: Dart's Uri parser is
/// forgiving in surprising ways (e.g. it lowercases the scheme silently),
/// and we want to reject "https://join?…" even though it parses.
JoinPayload? decodeJoin(String raw) {
  final uri = Uri.tryParse(raw);
  if (uri == null) return null;
  if (uri.scheme.toLowerCase() != scytheScheme) return null;
  if (uri.host.toLowerCase() != _joinHost) return null;
  final server = uri.queryParameters['server'];
  final room = uri.queryParameters['room'];
  if (server == null || server.isEmpty) return null;
  if (room == null || room.isEmpty) return null;
  return JoinPayload(server: server, roomCode: room.toUpperCase());
}
