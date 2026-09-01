// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import '../utils/strings.dart';

/// T3.5: small pill widget shown at the top of Create/Join/Settings
/// while the socket is mid-handshake. Not a full-screen spinner — the
/// user is filling a form, they should still see the form, they just
/// need to know why the button hasn't done anything yet.
///
/// Colour choice: matches the existing `_ReconnectBanner` palette
/// (orange/green) so users learn the visual grammar in one place.
class ConnectionPill extends StatelessWidget {
  const ConnectionPill({super.key, this.label});

  /// Override the default label (rare — useful for tests).
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.orange.shade700,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label ?? ConnectionStrings.connectingPill,
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

/// Shows the socket's current destination directly on Create/Join.
///
/// This stays visible even when disconnected so a stale localhost binding is
/// obvious without opening Settings or interpreting a transient error.
class ServerUrlFooter extends StatelessWidget {
  const ServerUrlFooter({super.key, required this.serverUrl});

  final String? serverUrl;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Text(
        ConnectionStrings.serverFooter(serverUrl),
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white70, fontSize: 12),
      ),
    );
  }
}
