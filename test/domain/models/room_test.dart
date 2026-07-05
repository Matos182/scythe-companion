// SPDX-License-Identifier: MIT

import 'package:flutter_test/flutter_test.dart';
import 'package:scythe_companion/domain/models/player.dart';
import 'package:scythe_companion/domain/models/turn_state.dart';
import 'package:scythe_companion/domain/models/room.dart';

/// A realistic server payload matching the current Mongoose `roomSchema`.
///
/// The server emits this flat shape on `createRoomSuccess`,
/// `joinRoomSuccess`, `updateRoom`, and `newTurn` events.
Map<String, dynamic> _sampleRoomJson() => {
      '_id': '64a1b2c3d4e5f6a7b8c9d0e1',
      'occupancy': 1,
      'turnIndex': 0,
      'totalTurns': 1,
      'isJoin': true,
      'isPaused': false,
      'players': [
        {
          '_id': '64a1b2c3d4e5f6a7b8c9d0e2',
          'nickname': 'Alice',
          'socketID': 'socket-abc123',
          'playerfaction': 'Crimea',
          'playermat': '1',
          'timer': 900,
        },
        {
          '_id': '64a1b2c3d4e5f6a7b8c9d0e3',
          'nickname': 'Bob',
          'socketID': 'socket-def456',
          'playerfaction': 'Saxony',
          'playermat': '2',
          'timer': 900,
        },
      ],
      'turn': {
        '_id': '64a1b2c3d4e5f6a7b8c9d0e2',
        'nickname': 'Alice',
        'socketID': 'socket-abc123',
        'playerfaction': 'Crimea',
        'playermat': '1',
        'timer': 900,
      },
      'creator': {
        '_id': '64a1b2c3d4e5f6a7b8c9d0e2',
        'nickname': 'Alice',
        'socketID': 'socket-abc123',
        'playerfaction': 'Crimea',
        'playermat': '1',
        'timer': 900,
      },
    };

void main() {
  group('Player', () {
    test('fromJson parses all fields', () {
      final json = {
        '_id': 'abc123',
        'nickname': 'Alice',
        'socketID': 'sock1',
        'playerfaction': 'Crimea',
        'playermat': '1',
        'timer': 900,
      };

      final player = Player.fromJson(json);

      expect(player.id, 'abc123');
      expect(player.nickname, 'Alice');
      expect(player.socketID, 'sock1');
      expect(player.playerfaction, 'Crimea');
      expect(player.playermat, '1');
      expect(player.timer, 900);
    });

    test('fromJson defaults on missing fields', () {
      final player = Player.fromJson({});

      expect(player.id, '');
      expect(player.nickname, '');
      expect(player.socketID, '');
      expect(player.playerfaction, '');
      expect(player.playermat, '');
      expect(player.timer, 0);
    });

    test('fromJson handles double-typed timer from Mongoose', () {
      final player = Player.fromJson({'timer': 900.0});
      expect(player.timer, 900);
    });

    test('toJson round-trips fromJson', () {
      final original = {
        '_id': 'abc123',
        'nickname': 'Alice',
        'socketID': 'sock1',
        'playerfaction': 'Crimea',
        'playermat': '1',
        'timer': 900,
      };

      final player = Player.fromJson(original);
      final roundTripped = Player.fromJson(player.toJson());

      expect(roundTripped.id, player.id);
      expect(roundTripped.nickname, player.nickname);
      expect(roundTripped.socketID, player.socketID);
      expect(roundTripped.playerfaction, player.playerfaction);
      expect(roundTripped.playermat, player.playermat);
      expect(roundTripped.timer, player.timer);
    });
  });

  group('TurnState', () {
    test('fromJson parses flat room fields', () {
      final json = {
        'turnIndex': 2,
        'totalTurns': 3,
        'isPaused': true,
      };

      final state = TurnState.fromJson(json);

      expect(state.turnIndex, 2);
      expect(state.totalTurns, 3);
      expect(state.isPaused, true);
    });

    test('fromJson defaults on empty json', () {
      final state = TurnState.fromJson({});

      expect(state.turnIndex, 0);
      expect(state.totalTurns, 1);
      expect(state.isPaused, false);
    });

    test('toJson round-trips', () {
      const original = TurnState(
        turnIndex: 5,
        totalTurns: 2,
        isPaused: true,
      );

      final roundTripped = TurnState.fromJson(original.toJson());

      expect(roundTripped.turnIndex, original.turnIndex);
      expect(roundTripped.totalTurns, original.totalTurns);
      expect(roundTripped.isPaused, original.isPaused);
    });
  });

  group('Room', () {
    test('fromJson parses full server payload', () {
      final room = Room.fromJson(_sampleRoomJson());

      expect(room.id, '64a1b2c3d4e5f6a7b8c9d0e1');
      expect(room.isJoin, true);
      expect(room.players.length, 2);

      final alice = room.players[0];
      expect(alice.nickname, 'Alice');
      expect(alice.playerfaction, 'Crimea');
      expect(alice.timer, 900);

      expect(room.turn.nickname, 'Alice');
      expect(room.turn.socketID, 'socket-abc123');
      expect(room.creator.nickname, 'Alice');
    });

    test('fromJson flattens TurnState from room-level fields', () {
      final room = Room.fromJson(_sampleRoomJson());

      expect(room.turnIndex, 0);
      expect(room.totalTurns, 1);
      expect(room.isPaused, false);
    });

    test('convenience getters expose turnState fields', () {
      final json = _sampleRoomJson()
        ..['turnIndex'] = 1
        ..['totalTurns'] = 5
        ..['isPaused'] = true;
      final room = Room.fromJson(json);

      expect(room.turnIndex, room.turnState.turnIndex);
      expect(room.totalTurns, room.turnState.totalTurns);
      expect(room.isPaused, room.turnState.isPaused);
      expect(room.currentPlayer.nickname, room.turn.nickname);
    });

    test('fromJson handles empty players list', () {
      final json = _sampleRoomJson()..['players'] = [];
      final room = Room.fromJson(json);

      expect(room.players, isEmpty);
    });

    test('fromJson handles missing turn/creator gracefully', () {
      final json = _sampleRoomJson()
        ..remove('turn')
        ..remove('creator');
      final room = Room.fromJson(json);

      expect(room.turn.nickname, '');
      expect(room.creator.nickname, '');
    });

    test('fromJson defaults on completely empty json', () {
      final room = Room.fromJson({});

      expect(room.id, '');
      expect(room.isJoin, true);
      expect(room.players, isEmpty);
      expect(room.turn.nickname, '');
      expect(room.turnIndex, 0);
    });

    test('toJson produces a valid flat payload', () {
      final room = Room.fromJson(_sampleRoomJson());
      final json = room.toJson();

      expect(json['_id'], '64a1b2c3d4e5f6a7b8c9d0e1');
      expect(json['isJoin'], true);
      expect(json['turnIndex'], 0);
      expect(json['totalTurns'], 1);
      expect(json['isPaused'], false);
      expect((json['players'] as List).length, 2);
      expect(json['turn'], isA<Map<String, dynamic>>());
      expect(json['creator'], isA<Map<String, dynamic>>());
    });

    test('toJson → fromJson round-trips losslessly', () {
      final original = Room.fromJson(_sampleRoomJson());
      final roundTripped = Room.fromJson(original.toJson());

      expect(roundTripped.id, original.id);
      expect(roundTripped.isJoin, original.isJoin);
      expect(roundTripped.players.length, original.players.length);
      expect(roundTripped.turn.nickname, original.turn.nickname);
      expect(roundTripped.creator.nickname, original.creator.nickname);
      expect(roundTripped.turnIndex, original.turnIndex);
      expect(roundTripped.totalTurns, original.totalTurns);
      expect(roundTripped.isPaused, original.isPaused);
    });
  });
}
