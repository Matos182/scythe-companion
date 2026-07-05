// SPDX-License-Identifier: MIT

/// Turn-engine state for a room.
///
/// Groups the three flat fields the current server puts on the room
/// document — `turnIndex`, `totalTurns`, `isPaused` — into a single typed
/// object. This is the state the timer engine in T2.2 will own; here we
/// only parse it so widgets stop indexing into a raw `Map`.
///
/// `fromJson` reads the fields from the **room-level** JSON (not a nested
/// object) because the current server payload is flat. When T2.1 nests
/// these under a `turnState` key, only this factory changes.
library;

class TurnState {
  final int turnIndex;
  final int totalTurns;
  final bool isPaused;

  const TurnState({
    this.turnIndex = 0,
    this.totalTurns = 1,
    this.isPaused = false,
  });

  factory TurnState.fromJson(Map<String, dynamic> json) {
    return TurnState(
      turnIndex: (json['turnIndex'] as num?)?.toInt() ?? 0,
      totalTurns: (json['totalTurns'] as num?)?.toInt() ?? 1,
      isPaused: json['isPaused'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'turnIndex': turnIndex,
        'totalTurns': totalTurns,
        'isPaused': isPaused,
      };
}
