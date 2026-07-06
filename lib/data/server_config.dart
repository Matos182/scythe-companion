// SPDX-License-Identifier: MIT

/// Where the server lives, until T3.2 makes it runtime-configurable (QR).
///
/// The old `lib/env/env.dart` (gitignored, audit A11) is gone: the repo
/// now compiles straight after clone. Override at build time with
/// `flutter run --dart-define=SCYTHE_SERVER_URL=http://192.168.1.50:3000`.
library;

class ServerConfig {
  /// Base URL of the socket.io server (no trailing slash).
  static const String serverUrl = String.fromEnvironment(
    'SCYTHE_SERVER_URL',
    defaultValue: 'http://localhost:3000',
  );
}
