// SPDX-License-Identifier: MIT

/// Winner logic for the Scythe Coin Calculator.
///
/// Moved here from `result.dart` (T1.3) so tie handling is tested domain
/// code, not buried in a widget's `build` method. Pure Dart — no Flutter.
library;

import '../models/players.dart';

/// A ranked score entry: the [entry] plus its [rank] (1 = winner, ties
/// share a rank) and whether it [isWinner].
class RankedScore {
  final ScoreEntry entry;
  final int rank;
  final bool isWinner;

  const RankedScore({
    required this.entry,
    required this.rank,
    required this.isWinner,
  });
}

/// Returns the sorted, ranked list of [entries] (highest score first).
///
/// Ties share the same rank (standard competition ranking: 1, 1, 3, …).
/// The [findWinners] set is the subset with rank 1.
List<RankedScore> rankScores(List<ScoreEntry> entries) {
  if (entries.isEmpty) return const [];

  // Sort descending by result.
  final sorted = List<ScoreEntry>.from(entries)
    ..sort((a, b) => b.result.compareTo(a.result));

  final ranked = <RankedScore>[];
  int rank = 1;
  for (var i = 0; i < sorted.length; i++) {
    // If this entry's score differs from the previous, advance the rank
    // to i+1 (standard competition ranking).
    if (i > 0 && sorted[i].result != sorted[i - 1].result) {
      rank = i + 1;
    }
    ranked.add(RankedScore(
      entry: sorted[i],
      rank: rank,
      isWinner: rank == 1,
    ));
  }
  return ranked;
}

/// Returns the list of winners (rank 1). May contain more than one entry
/// in case of a tie.
List<ScoreEntry> findWinners(List<ScoreEntry> entries) {
  if (entries.isEmpty) return const [];
  final ranked = rankScores(entries);
  return ranked
      .where((r) => r.isWinner)
      .map((r) => r.entry)
      .toList(growable: false);
}
