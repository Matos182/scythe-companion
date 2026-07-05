// SPDX-License-Identifier: MIT

/// Input for the Scythe coin calculator.
///
/// All fields are the raw values a player reads off their player mat:
/// [resources] is the *unadjusted* resource count (the ÷2 floor happens
/// inside [coinsFor] in `score_calculator.dart`, so the caller never
/// pre-divides).
///
/// See `orchestra/00_BRIEF.md` §"What the app is" for the tier table.
class ScoreInput {
  final String name;
  final int popularity;
  final int stars;
  final int lands;
  final int resources;
  final int buildings;
  final int coins;

  const ScoreInput({
    this.name = '',
    this.popularity = 0,
    this.stars = 0,
    this.lands = 0,
    this.resources = 0,
    this.buildings = 0,
    this.coins = 0,
  });

  @override
  String toString() =>
      'ScoreInput($name, pop=$popularity, stars=$stars, lands=$lands, '
      'res=$resources, bld=$buildings, coins=$coins)';
}
