// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'theme.dart';

/// Shared background image treatment with a coal scrim for legible content.
class ScytheBackdrop extends StatelessWidget {
  const ScytheBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ColorFiltered(
          colorFilter: ColorFilter.mode(
            ScytheColors.coal.withValues(alpha: 0.72),
            BlendMode.srcOver,
          ),
          child: Image.asset('assets/background.png', fit: BoxFit.cover),
        ),
        child,
      ],
    );
  }
}
