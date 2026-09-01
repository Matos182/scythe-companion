// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scythe_companion/ui/theme.dart';

void main() {
  test('ScytheTheme.dark exposes the Rust & Tesla component tokens', () {
    final theme = ScytheTheme.dark();
    final buttonBackground = theme.elevatedButtonTheme.style!.backgroundColor!;

    expect(theme.scaffoldBackgroundColor, ScytheColors.coal);
    expect(buttonBackground.resolve(<WidgetState>{}), ScytheColors.rust);
    expect(
      buttonBackground.resolve(<WidgetState>{WidgetState.disabled}),
      ScytheColors.rustDeep.withValues(alpha: 0.4),
    );
    expect(theme.inputDecorationTheme.fillColor, ScytheColors.gunmetalHi);
    expect(theme.colorScheme.error, ScytheColors.danger);
  });
}
