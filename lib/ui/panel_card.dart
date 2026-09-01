// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'theme.dart';

/// A gunmetal panel with a seam border and two brass corner rivets.
class PanelCard extends StatelessWidget {
  const PanelCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: ScytheColors.gunmetal,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ScytheColors.seam),
      ),
      child: Stack(
        children: [
          Padding(padding: padding, child: child),
          const Positioned(top: 8, left: 8, child: _Rivet()),
          const Positioned(top: 8, right: 8, child: _Rivet()),
        ],
      ),
    );
  }
}

class _Rivet extends StatelessWidget {
  const _Rivet();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        color: ScytheColors.brass,
        shape: BoxShape.circle,
      ),
      child: SizedBox.square(dimension: 4),
    );
  }
}
