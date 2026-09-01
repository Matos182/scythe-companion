// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import '../ui/theme.dart';
import '../utils/strings.dart';

class ConnectionPill extends StatelessWidget {
  const ConnectionPill({super.key, this.label});

  final String? label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: ScytheColors.warning,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(ScytheColors.coal),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label ?? ConnectionStrings.connectingPill,
            style: const TextStyle(color: ScytheColors.coal, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

/// Smoothly opens and closes the connection status slot on forms.
class ConnectionPillSlot extends StatelessWidget {
  const ConnectionPillSlot({
    super.key,
    required this.visible,
    this.label,
  });

  final bool visible;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeOutCubic,
        child: visible
            ? ConnectionPill(
                key: const ValueKey('connection-pill'),
                label: label,
              )
            : const SizedBox.shrink(key: ValueKey('connection-pill-empty')),
      ),
    );
  }
}

/// Shows the socket's current destination directly on Create/Join.
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
        style: const TextStyle(
          color: ScytheColors.parchmentDim,
          fontSize: 12,
        ),
      ),
    );
  }
}
