// SPDX-License-Identifier: MIT

library;

/// [ScoreEntry] represents a player's score breakdown in the offline
/// Scythe Coin Calculator.
///
/// Renamed from `Players` (T1.2) to avoid confusion with the multiplayer
/// [Player] model in `domain/models/player.dart`. This class is mutable
/// and positional — the form pages write straight into its fields from
/// their text controllers before computing the final `result`.
class ScoreEntry {
  String name = '';
  int popularity = 0;
  int stars = 0;
  int lands = 0;
  int resources = 0;
  int coins = 0;
  int buildings = 0;
  int result = 0;

  /// Constructor for initializing a score entry with provided attributes.
  ScoreEntry(this.name, this.popularity, this.stars, this.lands, this.resources,
      this.buildings, this.coins, this.result);
}

const List<String> playerFactions = [
  'Crimea',
  'Saxony',
  'Polania',
  'Albion',
  'Nordic',
  'Rusviet',
  'Togawa'
];

const List<String> playerMats = ['1', '2', '2A', '3', '3A', '4', '5'];

const List<String> playerTimers = ['15:00', '20:00', '25:00', '30:00'];
