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

/// Converts a [playerTimers] label such as `'20:00'` into seconds (1200).
///
/// Parses the `MM:SS` label instead of matching it against a hard-coded
/// list, so adding an option to [playerTimers] needs no change here.
/// The previous if/else chain in `create.dart` left its target variable
/// unassigned for any unrecognised label, which would have thrown
/// `LateInitializationError` at room-creation time (audit F1).
///
/// Returns [fallback] (default 900 = 15:00, the first option) when the
/// label is malformed, so a bad value can never crash room creation.
int playerTimerSeconds(String label, {int fallback = 900}) {
  final parts = label.split(':');
  if (parts.length != 2) return fallback;
  final minutes = int.tryParse(parts[0]);
  final seconds = int.tryParse(parts[1]);
  if (minutes == null || seconds == null) return fallback;
  return minutes * 60 + seconds;
}
