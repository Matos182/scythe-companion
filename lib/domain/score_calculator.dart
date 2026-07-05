// SPDX-License-Identifier: MIT

/// Pure-function Scythe coin calculator.
///
/// Implements the official popularity-tier scoring table from the BRIEF
/// (§"What the app is"):
///
/// | Popularity | Stars × | Lands × | Resources÷2 × |
/// |------------|---------|---------|----------------|
/// | 0–6        | 3       | 2       | 1              |
/// | 7–12       | 4       | 3       | 2              |
/// | 13–18      | 5       | 4       | 3              |
///
/// Building coins and coins on hand are always added at face value
/// (×1 multiplier, no tier bonus).
///
/// This file is pure Dart — no Flutter imports. Widgets call [coinsFor]
/// instead of inlining the tier ladder (audit A13).
library;

import 'models/score_input.dart';

/// Returns the total coin score for [input].
///
/// The resource count is floored by half (÷2, truncated) *inside* this
/// function — callers pass the raw resource number straight off the mat.
int coinsFor(ScoreInput input) {
  final int starMult;
  final int landMult;
  final int resMult;

  if (input.popularity < 7) {
    starMult = 3;
    landMult = 2;
    resMult = 1;
  } else if (input.popularity < 13) {
    starMult = 4;
    landMult = 3;
    resMult = 2;
  } else {
    starMult = 5;
    landMult = 4;
    resMult = 3;
  }

  // Resources are counted as coin pairs: floor(raw / 2).
  final resourcesAsCoins = (input.resources / 2).truncate();

  return input.stars * starMult +
      input.lands * landMult +
      resourcesAsCoins * resMult +
      input.buildings +
      input.coins;
}
