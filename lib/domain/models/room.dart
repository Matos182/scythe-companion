// SPDX-License-Identifier: MIT

/// Typed room state — the single source of truth for a multiplayer game.
///
/// Replaces the untyped `Map<String, dynamic> roomData` (audit A12). Pages
/// and widgets read typed fields: `room.turn.nickname`, `room.isJoin`,
/// `room.turnState.turnIndex`, etc. — no string indexing, no runtime casts.
///
/// The current server payload is a **flat** Mongoose document:
/// ```
/// { _id, isJoin, turnIndex, totalTurns, isPaused,
///   players: [...], turn: {...}, creator: {...} }
/// ```
/// [fromJson] reads that flat shape and composes it into [Player] and
/// [TurnState] sub-objects. This is the **adapter seam** (02_ARCHITECTURE):
/// when T2.1 changes the payload (e.g. nests turnState, renames fields),
/// only `fromJson`/`toJson` need updating — every consumer keeps working.
library;

import 'player.dart';
import 'turn_state.dart';

class Room {
  final String id;
  final bool isJoin;
  final List<Player> players;
  final Player turn;
  final Player creator;
  final TurnState turnState;

  const Room({
    this.id = '',
    this.isJoin = true,
    this.players = const [],
    this.turn = const Player(),
    this.creator = const Player(),
    this.turnState = const TurnState(),
  });

  /// Convenience: the player whose turn it is (alias for [turn]).
  Player get currentPlayer => turn;

  /// Convenience: the current turn index (alias for `turnState.turnIndex`).
  int get turnIndex => turnState.turnIndex;

  /// Convenience: total rounds elapsed (alias for `turnState.totalTurns`).
  int get totalTurns => turnState.totalTurns;

  /// Convenience: whether the game is paused.
  bool get isPaused => turnState.isPaused;

  factory Room.fromJson(Map<String, dynamic> json) {
    return Room(
      id: json['_id'] as String? ?? '',
      isJoin: json['isJoin'] as bool? ?? true,
      players: (json['players'] as List?)
              ?.map((p) => Player.fromJson(p as Map<String, dynamic>))
              .toList() ??
          const [],
      turn: json['turn'] is Map<String, dynamic>
          ? Player.fromJson(json['turn'] as Map<String, dynamic>)
          : const Player(),
      creator: json['creator'] is Map<String, dynamic>
          ? Player.fromJson(json['creator'] as Map<String, dynamic>)
          : const Player(),
      turnState: TurnState.fromJson(json),
    );
  }

  Map<String, dynamic> toJson() => {
        '_id': id,
        'isJoin': isJoin,
        'players': players.map((p) => p.toJson()).toList(),
        'turn': turn.toJson(),
        'creator': creator.toJson(),
        'turnIndex': turnState.turnIndex,
        'totalTurns': turnState.totalTurns,
        'isPaused': turnState.isPaused,
      };
}
