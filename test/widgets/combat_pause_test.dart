// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:scythe_companion/data/game_repository.dart';
import 'package:scythe_companion/data/session_store.dart';
import 'package:scythe_companion/data/settings_repository.dart';
import 'package:scythe_companion/data/socket_service.dart';
import 'package:scythe_companion/pages/game.dart';
import 'package:scythe_companion/provider/room_notifier.dart';
import 'package:scythe_companion/utils/strings.dart';

import '../data/fake_socket_adapter.dart';
import '../data/socket_service_test.dart' show playerJson, roomJson;

({GameRepository repository, RoomNotifier notifier}) _build(
  FakeSocketAdapter fake,
) {
  final service = SocketService(adapter: fake);
  final repository = GameRepository(
    socketService: service,
    sessionStore: InMemorySessionStore(),
    settingsRepository: InMemorySettingsRepository(),
  );
  final notifier = RoomNotifier(repository);
  return (repository: repository, notifier: notifier);
}

Widget _gameUnderTest(GameRepository repository, RoomNotifier notifier) {
  return MaterialApp(
    home: MultiProvider(
      providers: [
        Provider<GameRepository>.value(value: repository),
        ChangeNotifierProvider<RoomNotifier>.value(value: notifier),
      ],
      child: const Scaffold(body: GamePage()),
    ),
  );
}

final aliceBob = [
  playerJson(
      id: 'uuid-alice',
      nickname: 'Alice',
      socketID: 'socket-1',
      remainingSec: 300),
  playerJson(
      id: 'uuid-bob',
      nickname: 'Bob',
      socketID: 'socket-bob',
      remainingSec: 300),
];

Future<void> _seatInGame(
  FakeSocketAdapter fake,
  GameRepository repository, {
  int turnIndex = 0,
  bool isPaused = false,
  String? pauseReason,
}) async {
  await repository.createRoom(
      nickname: 'Alice', faction: 'Crimea', mat: '1', timerSec: 900);
  fake.serverEmit(
    'createRoomSuccess',
    roomJson(
      isJoin: false,
      turnIndex: turnIndex,
      isPaused: isPaused,
      pauseReason: pauseReason,
      players: aliceBob,
    ),
  );
}

void main() {
  group('GamePage — combat control (T5.7)', () {
    testWidgets('combat control is present only for the current-turn player',
        (tester) async {
      final fake = FakeSocketAdapter();
      final built = _build(fake);
      addTearDown(built.repository.dispose);
      addTearDown(built.notifier.dispose);

      await _seatInGame(fake, built.repository);
      await tester.pumpWidget(_gameUnderTest(built.repository, built.notifier));
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const ValueKey('combat-action')), findsOneWidget);
      expect(find.text(CombatStrings.start), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('combat-action')));
      await tester.pump();
      expect(
        fake.sentEvents.where((e) => e.name == 'combat'),
        isNotEmpty,
      );
    });

    testWidgets('combat control is hidden when it is not my turn',
        (tester) async {
      final fake = FakeSocketAdapter();
      final built = _build(fake);
      addTearDown(built.repository.dispose);
      addTearDown(built.notifier.dispose);

      await _seatInGame(fake, built.repository, turnIndex: 1);
      await tester.pumpWidget(_gameUnderTest(built.repository, built.notifier));
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const ValueKey('combat-action')), findsNothing);
      expect(find.text(CombatStrings.start), findsNothing);
    });
  });

  group('GamePage — combat overlay vs generic pause (T5.7)', () {
    testWidgets('overlay copy shows when pauseReason is combat',
        (tester) async {
      final fake = FakeSocketAdapter();
      final built = _build(fake);
      addTearDown(built.repository.dispose);
      addTearDown(built.notifier.dispose);

      await _seatInGame(
        fake,
        built.repository,
        isPaused: true,
        pauseReason: 'combat',
      );
      await tester.pumpWidget(_gameUnderTest(built.repository, built.notifier));
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const ValueKey('combat-overlay')), findsOneWidget);
      expect(find.text(CombatStrings.overlayTitle), findsOneWidget);
      expect(find.text(CombatStrings.overlayBody), findsOneWidget);
      expect(find.text(GameStrings.pausedLabel), findsNothing);
      expect(find.byKey(const ValueKey('combat-action')), findsNothing);
      expect(find.byKey(const ValueKey('combat-resolved')), findsOneWidget);
    });

    testWidgets('generic pause still shows GAME IS PAUSED, not combat overlay',
        (tester) async {
      final fake = FakeSocketAdapter();
      final built = _build(fake);
      addTearDown(built.repository.dispose);
      addTearDown(built.notifier.dispose);

      await _seatInGame(fake, built.repository, isPaused: true);
      await tester.pumpWidget(_gameUnderTest(built.repository, built.notifier));
      await tester.pump();
      await tester.pump();

      expect(find.text(GameStrings.pausedLabel), findsOneWidget);
      expect(find.byKey(const ValueKey('combat-overlay')), findsNothing);
      expect(find.text(CombatStrings.overlayTitle), findsNothing);
    });
  });
}
