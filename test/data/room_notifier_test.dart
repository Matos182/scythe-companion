// SPDX-License-Identifier: MIT

import 'package:flutter_test/flutter_test.dart';
import 'package:scythe_companion/data/game_repository.dart';
import 'package:scythe_companion/data/session_store.dart';
import 'package:scythe_companion/data/settings_repository.dart';
import 'package:scythe_companion/data/socket_service.dart';
import 'package:scythe_companion/provider/room_notifier.dart';

import 'fake_socket_adapter.dart';
import 'socket_service_test.dart' show roomJson, playerJson;

void main() {
  late FakeSocketAdapter fake;
  late GameRepository repository;
  late RoomNotifier notifier;

  setUp(() {
    fake = FakeSocketAdapter();
    repository = GameRepository(
      socketService: SocketService(adapter: fake),
      sessionStore: InMemorySessionStore(),
      settingsRepository: InMemorySettingsRepository(),
    );
    notifier = RoomNotifier(repository);
  });

  tearDown(() {
    notifier.dispose();
    repository.dispose();
  });

  Future<void> seatAlice() async {
    await repository.createRoom(
        nickname: 'Alice', faction: 'Crimea', mat: '1', timerSec: 900);
    fake.serverEmit(
        'createRoomSuccess',
        roomJson(players: [
          playerJson(id: 'uuid-alice', nickname: 'Alice', socketID: 'socket-1'),
          playerJson(id: 'uuid-bob', nickname: 'Bob', socketID: 'socket-2'),
        ]));
    await Future<void>.delayed(Duration.zero);
  }

  test('room updates flow into typed state + justJoined one-shot', () async {
    await seatAlice();

    expect(notifier.room.id, 'AB3KMN');
    expect(notifier.room.players.length, 2);
    expect(notifier.consumeJoinedFlag(), isTrue);
    expect(notifier.consumeJoinedFlag(), isFalse); // one-shot
  });

  test('isMyTurn / isCreator use playerId, not socket id (D4)', () async {
    await seatAlice();

    expect(notifier.isSeated, isTrue);
    expect(notifier.isMyTurn, isTrue); // turnIndex 0 = Alice
    expect(notifier.isCreator, isTrue);

    // Bob's turn now.
    fake.serverEmit(
        'newTurn',
        roomJson(turnIndex: 1, players: [
          playerJson(id: 'uuid-alice', nickname: 'Alice', socketID: 'socket-1'),
          playerJson(id: 'uuid-bob', nickname: 'Bob', socketID: 'socket-2'),
        ]));
    await Future<void>.delayed(Duration.zero);

    expect(notifier.isMyTurn, isFalse);
    expect(notifier.isCreator, isTrue); // creator unchanged
  });

  test('server ticks fold into player remainingSec (A2: server is clock)',
      () async {
    await seatAlice();

    fake.serverEmit('tick',
        {'roomCode': 'AB3KMN', 'playerId': 'uuid-alice', 'remainingSec': 123});
    await Future<void>.delayed(Duration.zero);

    expect(notifier.room.players[0].remainingSec, 123);
    expect(notifier.room.turn.remainingSec, 123);
    expect(notifier.room.players[1].remainingSec, 900); // Bob untouched
  });

  test('tick for another room is ignored', () async {
    await seatAlice();

    fake.serverEmit('tick',
        {'roomCode': 'OTHER1', 'playerId': 'uuid-alice', 'remainingSec': 5});
    await Future<void>.delayed(Duration.zero);

    expect(notifier.room.players[0].remainingSec, 900);
  });

  test('server error lands in lastError and clears on demand', () async {
    fake.serverEmit('errorOccurred',
        {'code': 'STATE_ROOM_NOT_FOUND', 'message': 'Room not found.'});
    await Future<void>.delayed(Duration.zero);

    expect(notifier.lastError!.code, 'STATE_ROOM_NOT_FOUND');
    notifier.clearError();
    expect(notifier.lastError, isNull);
  });

  // T3.4: the justBecameMyTurn one-shot flag fires only on a genuine
  // transition (wasn't my turn → is my turn), not on refreshes that
  // keep the same active player.
  group('justBecameMyTurn (T3.4)', () {
    test('fires when newTurn transitions to my turn', () async {
      await seatAlice();
      // Seat alice: turnIndex 0 = Alice → the initial room went from
      // empty (no turn) to Alice's turn, so the flag IS set — this is
      // a genuine transition from the notifier's perspective.
      expect(notifier.consumeJustBecameMyTurnFlag(), isTrue);
      // One-shot: second consume is false.
      expect(notifier.consumeJustBecameMyTurnFlag(), isFalse);

      // Bob's turn — not my turn, flag stays false.
      fake.serverEmit(
          'newTurn',
          roomJson(turnIndex: 1, players: [
            playerJson(
                id: 'uuid-alice', nickname: 'Alice', socketID: 'socket-1'),
            playerJson(id: 'uuid-bob', nickname: 'Bob', socketID: 'socket-2'),
          ]));
      await Future<void>.delayed(Duration.zero);
      expect(notifier.consumeJustBecameMyTurnFlag(), isFalse);

      // Back to Alice — genuine transition, flag fires.
      fake.serverEmit(
          'newTurn',
          roomJson(turnIndex: 0, players: [
            playerJson(
                id: 'uuid-alice', nickname: 'Alice', socketID: 'socket-1'),
            playerJson(id: 'uuid-bob', nickname: 'Bob', socketID: 'socket-2'),
          ]));
      await Future<void>.delayed(Duration.zero);
      expect(notifier.consumeJustBecameMyTurnFlag(), isTrue);
      expect(notifier.consumeJustBecameMyTurnFlag(), isFalse);
    });

    test('does not fire on a refresh that keeps the same active player',
        () async {
      await seatAlice();
      // Consume the initial transition flag (empty → Alice's turn).
      expect(notifier.consumeJustBecameMyTurnFlag(), isTrue);

      // Another update with the same turn (Alice still at turnIndex 0).
      // No transition → flag stays false.
      fake.serverEmit(
          'updateRoom',
          roomJson(turnIndex: 0, players: [
            playerJson(
                id: 'uuid-alice',
                nickname: 'Alice',
                socketID: 'socket-1',
                remainingSec: 500),
            playerJson(id: 'uuid-bob', nickname: 'Bob', socketID: 'socket-2'),
          ]));
      await Future<void>.delayed(Duration.zero);
      expect(notifier.consumeJustBecameMyTurnFlag(), isFalse);
    });
  });
}
