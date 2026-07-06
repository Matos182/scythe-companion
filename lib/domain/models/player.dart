// SPDX-License-Identifier: MIT

/// A player in a multiplayer Scythe room.
///
/// This is the typed counterpart of the player sub-document the server
/// serializes (Mongoose `playerSchema`). It is **not** the same as
/// [ScoreEntry] (the offline calculator model) — [Player] carries only
/// the fields the multiplayer flow needs: identity, faction/mat, and the
/// remaining turn timer.
///
/// `fromJson` / `toJson` form the **adapter seam** (02_ARCHITECTURE §"Typed
/// models"): when T2.1 changes the server payload, only these factories
/// change — widgets and providers keep working with typed fields.
library;

class Player {
  final String id;
  final String nickname;
  final String socketID;
  final String playerfaction;
  final String playermat;
  final int timer;
  final int remainingSec;
  final bool connected;

  const Player({
    this.id = '',
    this.nickname = '',
    this.socketID = '',
    this.playerfaction = '',
    this.playermat = '',
    this.timer = 0,
    this.remainingSec = 0,
    this.connected = true,
  });

  /// Parses a player sub-document from the server payload.
  ///
  /// `_id` is the server-minted playerId UUID (D4). `timer` is the
  /// configured per-turn allowance; `remainingSec` the live countdown
  /// (distinct fields — audit A6). `connected` is the presence flag
  /// (T2.3). All fields default to empty/zero if missing — null-safety
  /// at the JSON edge.
  factory Player.fromJson(Map<String, dynamic> json) {
    return Player(
      id: json['_id'] as String? ?? '',
      nickname: json['nickname'] as String? ?? '',
      socketID: json['socketID'] as String? ?? '',
      playerfaction: json['playerfaction'] as String? ?? '',
      playermat: json['playermat'] as String? ?? '',
      timer: (json['timer'] as num?)?.toInt() ?? 0,
      remainingSec: (json['remainingSec'] as num?)?.toInt() ?? 0,
      connected: json['connected'] as bool? ?? true,
    );
  }

  /// Copy with an updated live countdown (used when a server tick
  /// arrives between full-room updates).
  Player copyWith({int? remainingSec}) => Player(
        id: id,
        nickname: nickname,
        socketID: socketID,
        playerfaction: playerfaction,
        playermat: playermat,
        timer: timer,
        remainingSec: remainingSec ?? this.remainingSec,
        connected: connected,
      );

  Map<String, dynamic> toJson() => {
        '_id': id,
        'nickname': nickname,
        'socketID': socketID,
        'playerfaction': playerfaction,
        'playermat': playermat,
        'timer': timer,
        'remainingSec': remainingSec,
        'connected': connected,
      };

  @override
  String toString() =>
      'Player($nickname, faction=$playerfaction, mat=$playermat, timer=$timer)';
}
