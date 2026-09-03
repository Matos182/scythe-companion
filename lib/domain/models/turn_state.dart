// SPDX-License-Identifier: MIT

/// Turn-engine state for a room.
///
/// Groups the flat fields the current server puts on the room document —
/// `turnIndex`, `totalTurns`, `isPaused`, optional `pauseReason` — into a
/// single typed object. This is the state the timer engine in T2.2 will
/// own; here we only parse it so widgets stop indexing into a raw `Map`.
///
/// `fromJson` reads the fields from the **room-level** JSON (not a nested
/// object) because the current server payload is flat. When T2.1 nests
/// these under a `turnState` key, only this factory changes.
library;

class TurnState {
  final int turnIndex;
  final int totalTurns;
  final bool isPaused;

  /// T5.7: omitted/null = ordinary pause; `'combat'` = table fight.
  final String? pauseReason;

  const TurnState({
    this.turnIndex = 0,
    this.totalTurns = 1,
    this.isPaused = false,
    this.pauseReason,
  });

  /// Combat pause is a paused room tagged `'combat'`. Missing key ⇒ not combat.
  bool get isCombatPause => isPaused && pauseReason == 'combat';

  factory TurnState.fromJson(Map<String, dynamic> json) {
    final rawReason = json['pauseReason'];
    return TurnState(
      turnIndex: (json['turnIndex'] as num?)?.toInt() ?? 0,
      totalTurns: (json['totalTurns'] as num?)?.toInt() ?? 1,
      isPaused: json['isPaused'] as bool? ?? false,
      pauseReason:
          rawReason is String && rawReason.isNotEmpty ? rawReason : null,
    );
  }

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'turnIndex': turnIndex,
      'totalTurns': totalTurns,
      'isPaused': isPaused,
    };
    if (pauseReason != null) {
      json['pauseReason'] = pauseReason;
    }
    return json;
  }
}
