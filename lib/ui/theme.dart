// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';

/// The single Rust & Tesla palette used throughout the application.
abstract final class ScytheColors {
  // Surfaces (dark, aged metal).
  static const coal = Color(0xFF16181A);
  static const gunmetal = Color(0xFF23282C);
  static const gunmetalHi = Color(0xFF2F363B);
  static const seam = Color(0xFF3D4348);

  // Rust and brass accents.
  static const rust = Color(0xFFB4552D);
  static const rustDeep = Color(0xFF7E3A1F);
  static const brass = Color(0xFFC9A45C);
  static const brassDim = Color(0xFF8A7443);

  // Parchment text.
  static const parchment = Color(0xFFE8DFC9);
  static const parchmentDim = Color(0xFFA89F8C);

  // Tesla-tech status accents.
  static const teslaGlow = Color(0xFF5FD3BC);
  static const teslaDim = Color(0xFF2E6B60);

  // Semantic states.
  static const danger = Color(0xFFC63A2F);
  static const warning = Color(0xFFD98E32);
  static const disabled = Color(0xFF5A5F63);
}

/// Builds the app's one canonical dark theme.
abstract final class ScytheTheme {
  static ThemeData dark() {
    const radius6 = BorderRadius.all(Radius.circular(6));
    const radius8 = BorderRadius.all(Radius.circular(8));
    const enabledInputBorder = OutlineInputBorder(
      borderRadius: radius6,
      borderSide: BorderSide(color: ScytheColors.seam),
    );
    const focusedInputBorder = OutlineInputBorder(
      borderRadius: radius6,
      borderSide: BorderSide(color: ScytheColors.brass, width: 1.5),
    );
    const errorInputBorder = OutlineInputBorder(
      borderRadius: radius6,
      borderSide: BorderSide(color: ScytheColors.danger),
    );
    const focusedErrorInputBorder = OutlineInputBorder(
      borderRadius: radius6,
      borderSide: BorderSide(color: ScytheColors.danger, width: 1.5),
    );

    const colorScheme = ColorScheme.dark(
      primary: ScytheColors.rust,
      secondary: ScytheColors.brass,
      tertiary: ScytheColors.teslaGlow,
      surface: ScytheColors.gunmetal,
      error: ScytheColors.danger,
      onPrimary: ScytheColors.parchment,
      onSurface: ScytheColors.parchment,
    );

    return ThemeData(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: ScytheColors.coal,
      textTheme: const TextTheme(
        headlineSmall: TextStyle(
          color: ScytheColors.parchment,
          fontSize: 24,
          fontWeight: FontWeight.w700,
        ),
        titleMedium: TextStyle(
          color: ScytheColors.parchment,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        bodyMedium: TextStyle(
          color: ScytheColors.parchment,
          fontSize: 14,
        ),
        labelLarge: TextStyle(
          color: ScytheColors.parchment,
          fontSize: 15,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: ScytheColors.gunmetal,
        foregroundColor: ScytheColors.parchment,
        elevation: 0,
        centerTitle: true,
        shape: Border(
          bottom: BorderSide(color: ScytheColors.seam),
        ),
        titleTextStyle: TextStyle(
          color: ScytheColors.parchment,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: 1,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return ScytheColors.rustDeep.withValues(alpha: 0.4);
            }
            return ScytheColors.rust;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return ScytheColors.disabled;
            }
            return ScytheColors.parchment;
          }),
          minimumSize: const WidgetStatePropertyAll(Size(170, 52)),
          shape: const WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: radius6,
              side: BorderSide(color: ScytheColors.brass),
            ),
          ),
          textStyle: const WidgetStatePropertyAll(
            TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.5),
          ),
        ),
      ),
      inputDecorationTheme: const InputDecorationThemeData(
        filled: true,
        fillColor: ScytheColors.gunmetalHi,
        hintStyle: TextStyle(color: ScytheColors.parchmentDim),
        helperStyle: TextStyle(color: ScytheColors.brassDim),
        enabledBorder: enabledInputBorder,
        focusedBorder: focusedInputBorder,
        errorBorder: errorInputBorder,
        focusedErrorBorder: focusedErrorInputBorder,
      ),
      dataTableTheme: const DataTableThemeData(
        headingTextStyle: TextStyle(
          color: ScytheColors.brass,
          fontWeight: FontWeight.w700,
        ),
        dataTextStyle: TextStyle(color: ScytheColors.parchment),
        dividerThickness: 0.5,
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: ScytheColors.gunmetalHi,
        contentTextStyle: TextStyle(color: ScytheColors.parchment),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: radius6,
          side: BorderSide(color: ScytheColors.seam),
        ),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: ScytheColors.gunmetal,
        shape: RoundedRectangleBorder(
          borderRadius: radius8,
          side: BorderSide(color: ScytheColors.seam),
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.fuchsia: FadeForwardsPageTransitionsBuilder(),
        },
      ),
    );
  }
}
