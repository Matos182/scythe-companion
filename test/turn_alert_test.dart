// SPDX-License-Identifier: MIT

// T5.5: the composition root cues the phone on your-turn even while
// the app is in the foreground (the T3.4 path only fired when Homed).

import 'package:flutter_test/flutter_test.dart';
import 'package:scythe_companion/data/game_repository.dart';
import 'package:scythe_companion/data/notifications.dart';
import 'package:scythe_companion/data/session_store.dart';
import 'package:scythe_companion/data/settings_repository.dart';
import 'package:scythe_companion/data/socket_service.dart';
import 'package:scythe_companion/main.dart';

import 'data/fake_socket_adapter.dart';
import 'data/socket_service_test.dart' show playerJson, roomJson;

void main() {
  late FakeSocketAdapter fake;
  late _RecordingNotificationService notifications;
  late GameRepository repository;

  final aliceBob = [
    playerJson(id: 'uuid-alice', nickname: 'Alice', socketID: 'socket-1'),
    playerJson(id: 'uuid-bob', nickname: 'Bob', socketID: 'socket-2'),
  ];

  setUp(() {
    fake = FakeSocketAdapter();
    notifications = _RecordingNotificationService();
    repository = GameRepository(
      socketService: SocketService(adapter: fake),
      sessionStore: InMemorySessionStore(),
      settingsRepository: InMemorySettingsRepository(),
      initialServerUrl: 'http://test-server:3000',
    );
  });

  tearDown(() {
    repository.dispose();
  });

  Future<void> seatAlice() async {
    await repository.createRoom(
        nickname: 'Alice', faction: 'Crimea', mat: '1', timerSec: 900);
    fake.serverEmit(
        'createRoomSuccess', roomJson(isJoin: true, players: aliceBob));
  }

  testWidgets('lobby create does not announce your-turn', (tester) async {
    await tester.pumpWidget(
        MyApp(repository: repository, notifications: notifications));
    await tester.pump();

    await seatAlice();
    await tester.pump();

    expect(notifications.yourTurnCalls, isEmpty);
  });

  testWidgets('your-turn announces in the foreground when the game starts',
      (tester) async {
    await tester.pumpWidget(
        MyApp(repository: repository, notifications: notifications));
    await tester.pump();

    await seatAlice();
    await tester.pump();
    expect(notifications.yourTurnCalls, isEmpty);

    fake.serverEmit(
        'newTurn', roomJson(isJoin: false, turnIndex: 0, players: aliceBob));
    await tester.pump();

    expect(notifications.yourTurnCalls, ['Alice']);
  });

  testWidgets('your-turn announces again after a pass back to me',
      (tester) async {
    await tester.pumpWidget(
        MyApp(repository: repository, notifications: notifications));
    await tester.pump();

    await seatAlice();
    fake.serverEmit(
        'newTurn', roomJson(isJoin: false, turnIndex: 0, players: aliceBob));
    await tester.pump();
    notifications.yourTurnCalls.clear();

    fake.serverEmit(
        'newTurn', roomJson(isJoin: false, turnIndex: 1, players: aliceBob));
    await tester.pump();
    expect(notifications.yourTurnCalls, isEmpty);

    fake.serverEmit(
        'newTurn', roomJson(isJoin: false, turnIndex: 0, players: aliceBob));
    await tester.pump();
    expect(notifications.yourTurnCalls, ['Alice']);
  });
}

class _RecordingNotificationService extends NotificationService {
  _RecordingNotificationService() : super();

  final List<String?> yourTurnCalls = [];

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<void> announceYourTurn({String? nickname}) async {
    yourTurnCalls.add(nickname);
  }

  @override
  Future<void> showYourTurn({String? nickname}) async {
    yourTurnCalls.add(nickname);
  }

  @override
  Future<void> cancel() async {}
}
