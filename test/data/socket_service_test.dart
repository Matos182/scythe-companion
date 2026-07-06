// SPDX-License-Identifier: MIT

import 'package:flutter_test/flutter_test.dart';
import 'package:scythe_companion/data/game_repository.dart';
import 'package:scythe_companion/data/session_store.dart';
import 'package:scythe_companion/data/socket_service.dart';
import 'package:scythe_companion/domain/models/room.dart';

import 'fake_socket_adapter.dart';

/// Server-shaped room payload (docs/PROTOCOL.md room shape).
Map<String, dynamic> roomJson({
  String id = 'AB3KMN',
  bool isJoin = true,
  int turnIndex = 0,
  List<Map<String, dynamic>>? players,
}) {
  final playerList = players ??
      [
        playerJson(id: 'uuid-alice', nickname: 'Alice', socketID: 'socket-1'),
      ];
  return {
    '_id': id,
    'isJoin': isJoin,
    'turnIndex': turnIndex,
    'totalTurns': 1,
    'isPaused': false,
    'players': playerList,
    'turn': playerList[turnIndex],
    'creator': playerList[0],
  };
}

Map<String, dynamic> playerJson({
  required String id,
  required String nickname,
  required String socketID,
  bool connected = true,
  int remainingSec = 900,
}) {
  return {
    '_id': id,
    'nickname': nickname,
    'socketID': socketID,
    'playerfaction': 'Crimea',
    'playermat': '1',
    'timer': 900,
    'remainingSec': remainingSec,
    'connected': connected,
  };
}

void main() {
  late FakeSocketAdapter fake;
  late SocketService service;
  late InMemorySessionStore sessions;
  late GameRepository repository;

  setUp(() {
    fake = FakeSocketAdapter();
    service = SocketService(adapter: fake); // no probe: skip version check
    sessions = InMemorySessionStore();
    repository = GameRepository(socketService: service, sessionStore: sessions);
  });

  tearDown(() {
    repository.dispose();
  });

  group('SocketService — connection state', () {
    test('connect walks disconnected → connecting → connected', () async {
      final states = <SocketConnectionState>[];
      service.connectionStates.listen(states.add);

      await service.connect();
      await Future<void>.delayed(Duration.zero);

      expect(states,
          [SocketConnectionState.connecting, SocketConnectionState.connected]);
      expect(service.state, SocketConnectionState.connected);
    });

    test('unexpected drop → reconnecting; manual disconnect → disconnected',
        () async {
      await service.connect();
      fake.simulateDrop();
      expect(service.state, SocketConnectionState.reconnecting);

      fake.simulateReconnect('socket-2');
      expect(service.state, SocketConnectionState.connected);

      service.disconnect();
      expect(service.state, SocketConnectionState.disconnected);
    });

    test('protocol mismatch blocks the connection (D5)', () async {
      final mismatched = SocketService(
        adapter: fake,
        versionProbe: () async => 99,
      );
      final errors = <SocketError>[];
      mismatched.errors.listen(errors.add);

      await mismatched.connect();
      await Future<void>.delayed(Duration.zero);

      expect(mismatched.state, SocketConnectionState.protocolMismatch);
      expect(fake.connectCalls, 0); // never opened the socket
      expect(errors.single.code, 'PROTOCOL_MISMATCH');
    });

    test('matching protocol version connects normally', () async {
      final matched = SocketService(
        adapter: fake,
        versionProbe: () async => SocketService.expectedProtocolVersion,
      );
      await matched.connect();
      expect(matched.state, SocketConnectionState.connected);
    });

    test('handlers are registered once, not per page (A10)', () async {
      // All handlers live on the service; opening/closing pages must not
      // change the count. 1 handler per wire event.
      expect(fake.handlerCount('updateRoom'), 1);
      expect(fake.handlerCount('newTurn'), 1);
      expect(fake.handlerCount('errorOccurred'), 1);
      expect(fake.handlerCount('createRoomSuccess'), 1);
      expect(fake.handlerCount('joinRoomSuccess'), 1);
      expect(fake.handlerCount('tick'), 1);
    });
  });

  group('SocketService — events', () {
    test('error envelope {code, message} is parsed (T2.4)', () async {
      final errors = <SocketError>[];
      service.errors.listen(errors.add);

      fake.serverEmit('errorOccurred',
          {'code': 'VAL_INVALID_FACTION', 'message': 'Bad faction'});
      fake.serverEmit('errorOccurred', 'legacy string error');
      await Future<void>.delayed(Duration.zero);

      expect(errors[0].code, 'VAL_INVALID_FACTION');
      expect(errors[0].message, 'Bad faction');
      expect(errors[1].code, 'UNKNOWN'); // old-style degrades readable
      expect(errors[1].message, 'legacy string error');
    });

    test('malformed room payload surfaces an error, not a crash', () async {
      final errors = <SocketError>[];
      final rooms = <Room>[];
      service.errors.listen(errors.add);
      service.roomUpdates.listen(rooms.add);

      fake.serverEmit('updateRoom', 'not-a-map');
      await Future<void>.delayed(Duration.zero);

      expect(rooms, isEmpty);
      expect(errors.single.code, 'CLIENT_BAD_PAYLOAD');
    });

    test('tick events are decoded', () async {
      final ticks = <TimerTick>[];
      service.ticks.listen(ticks.add);

      fake.serverEmit('tick',
          {'roomCode': 'AB3KMN', 'playerId': 'uuid-alice', 'remainingSec': 42});
      await Future<void>.delayed(Duration.zero);

      expect(ticks.single.remainingSec, 42);
      expect(ticks.single.playerId, 'uuid-alice');
    });
  });

  group('GameRepository — full lifecycle connect→join→turn→drop→rejoin', () {
    test('create → identify me → session persisted (D4)', () async {
      await repository.createRoom(
          nickname: 'Alice', faction: 'Crimea', mat: '1', timerSec: 900);

      expect(fake.sentEvents.single.name, 'createRoom');
      expect(fake.sentEvents.single.payload['nickname'], 'Alice');

      fake.serverEmit('createRoomSuccess', roomJson());
      await Future<void>.delayed(Duration.zero);

      expect(repository.myPlayerId, 'uuid-alice');
      final saved = await sessions.load();
      expect(saved!.roomCode, 'AB3KMN');
      expect(saved.playerId, 'uuid-alice');
    });

    test('drop then reconnect auto-emits rejoinRoom with playerId', () async {
      // Seat Alice first.
      await repository.createRoom(
          nickname: 'Alice', faction: 'Crimea', mat: '1', timerSec: 900);
      fake.serverEmit('createRoomSuccess', roomJson());
      await Future<void>.delayed(Duration.zero);
      fake.sentEvents.clear();

      // Wi-Fi blip: drop, then socket.io's retry succeeds w/ new id.
      fake.simulateDrop();
      fake.simulateReconnect('socket-9');
      await Future<void>.delayed(Duration.zero);

      final rejoin = fake.sentEvents.single;
      expect(rejoin.name, 'rejoinRoom');
      expect(rejoin.payload['roomCode'], 'AB3KMN');
      expect(rejoin.payload['playerId'], 'uuid-alice');
    });

    test('rejoin success re-identifies me under the new socket id', () async {
      await repository.createRoom(
          nickname: 'Alice', faction: 'Crimea', mat: '1', timerSec: 900);
      fake.serverEmit('createRoomSuccess', roomJson());
      await Future<void>.delayed(Duration.zero);

      fake.simulateDrop();
      fake.simulateReconnect('socket-9');
      await Future<void>.delayed(Duration.zero);

      // Server remaps the seat to the new socket id (T2.3).
      fake.serverEmit(
          'joinRoomSuccess',
          roomJson(players: [
            playerJson(
                id: 'uuid-alice', nickname: 'Alice', socketID: 'socket-9'),
          ]));
      await Future<void>.delayed(Duration.zero);

      expect(repository.myPlayerId, 'uuid-alice'); // identity survives
    });

    test('app-restart path: rejoinSavedSession uses the stored session',
        () async {
      await sessions
          .save(const GameSession(roomCode: 'ZZTOP9', playerId: 'uuid-old'));

      final resumed = await repository.rejoinSavedSession();
      expect(resumed, isTrue);

      final rejoin =
          fake.sentEvents.where((e) => e.name == 'rejoinRoom').single;
      expect(rejoin.payload['roomCode'], 'ZZTOP9');
      expect(rejoin.payload['playerId'], 'uuid-old');
    });

    test('rejoinSavedSession is a no-op without a stored session', () async {
      expect(await repository.rejoinSavedSession(), isFalse);
      expect(fake.sentEvents, isEmpty);
    });

    test('leaveSession clears identity and stored session', () async {
      await repository.createRoom(
          nickname: 'Alice', faction: 'Crimea', mat: '1', timerSec: 900);
      fake.serverEmit('createRoomSuccess', roomJson());
      await Future<void>.delayed(Duration.zero);

      await repository.leaveSession();

      expect(repository.myPlayerId, isNull);
      expect(await sessions.load(), isNull);

      // A later reconnect must NOT try to rejoin a room we left.
      fake.simulateReconnect('socket-5');
      await Future<void>.delayed(Duration.zero);
      expect(fake.sentEvents.where((e) => e.name == 'rejoinRoom'), isEmpty);
    });

    test('turn/pause/resume emit protocol v1 payloads', () async {
      repository.passTurn('AB3KMN');
      repository.pause('AB3KMN');
      repository.resume('AB3KMN');

      expect(fake.sentEvents[0].name, 'turn');
      expect(fake.sentEvents[1].name, 'pause');
      expect(fake.sentEvents[2].name, 'toContinue');
      // The old client leaked 'atualTurn' — server is authoritative now.
      expect(fake.sentEvents[2].payload.containsKey('atualTurn'), isFalse);
      for (final e in fake.sentEvents) {
        expect(e.payload['roomId'], 'AB3KMN');
      }
    });
  });
}
