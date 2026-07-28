// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

/// A centred [Column] that scrolls instead of overflowing when its
/// content is taller than the space available.
///
/// The naive fix for a `RenderFlex overflowed` is to wrap the Column in a
/// [SingleChildScrollView], but that hands the Column an *unbounded*
/// height, and a Column with `MainAxisAlignment.center` in unbounded
/// space shrink-wraps — the vertical centring silently disappears
/// (documented as the T3.3 trap that kept this fix parked).
///
/// [LayoutBuilder] + [ConstrainedBox] is the standard cure: force the
/// content to be *at least* as tall as the viewport, so it stays centred
/// while it fits, and grows past the viewport — scrolling — when it
/// doesn't.
///
/// Only handles vertical overflow. A child that is too *wide* (a
/// [DataTable] with many columns on a narrow phone) still clips; that
/// needs a horizontal scroll view around the offending child.
///
/// Do not add [Expanded] or [Spacer] to [children]: they need a bounded
/// height and there isn't one here. Wrap the child in [IntrinsicHeight]
/// first if you ever need flex behaviour.
class ScrollableCenterColumn extends StatelessWidget {
  const ScrollableCenterColumn({
    super.key,
    required this.children,
    this.padding,
  });

  final List<Widget> children;

  /// Optional padding applied inside the scroll view, so the padding
  /// scrolls with the content rather than clipping it.
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, viewport) {
        // An infinite maxHeight means we're already inside another
        // vertical scrollable, and ConstrainedBox would assert. Fall
        // back to shrink-wrapping: the outer scrollable handles it.
        final minHeight =
            viewport.maxHeight.isFinite ? viewport.maxHeight : 0.0;

        return SingleChildScrollView(
          padding: padding,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: minHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: children,
            ),
          ),
        );
      },
    );
  }
}
