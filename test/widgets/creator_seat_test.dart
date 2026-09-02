// SPDX-License-Identifier: MIT

/// T5.4 — creator seat management UI: turn highlight in the players
/// table, remove affordance for disconnected players (lobby + game),
/// and the removePlayer emit path through the fake adapter.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:scythe_companion/data/game_repository.dart';
import 'package:scythe_companion/data/session_store.dart';
import 'package:scythe_companion/data/settings_repository.dart';
import 'package:scythe_companion/data/socket_service.dart';
import 'package:scythe_companion/pages/game.dart';
import 'package:scythe_companion/provider/room_notifier.dart';
import 'package:scythe_companion/widgets/waiting_lobby.dart';

import '../data/fake_socket_adapter.dart';
import '../data/socket_service_test.dart' show roomJson, playerJson;

GameRepository _buildRepository(FakeSocketAdapter fake) {
  return GameRepository(
    socketService: SocketService(adapter: fake),
    sessionStore: InMemorySessionStore(),
    settingsRepository: InMemorySettingsRepository(),
  );
}

Widget _host(GameRepository repository, RoomNotifier notifier, Widget child,
    {bool scrollable = true}) {
  return MaterialApp(
    scaffoldMessengerKey: GlobalKey<ScaffoldMessengerState>(),
    home: MultiProvider(
      providers: [
        Provider<GameRepository>.value(value: repository),
        ChangeNotifierProvider<RoomNotifier>.value(value: notifier),
      ],
      // GamePage manages its own scrolling (ScrollableCenterColumn) and
      // needs bounded height — never wrap it in a SingleChildScrollView.
      child: scrollable
          ? Scaffold(body: SingleChildScrollView(child: child))
          : Scaffold(body: child),
    ),
  );
}

Future<RoomNotifier> _seedCreator(
  FakeSocketAdapter fake,
  GameRepository repository,
) async {
  final notifier = RoomNotifier(repository);
  await repository.createRoom(
    nickname: 'Alice',
    faction: 'Crimea',
    mat: '1',
    timerSec: 900,
  );
  fake.serverEmit(
    'createRoomSuccess',
    roomJson(
      id: 'XY7ZQR',
      isJoin: true,
      players: [
        playerJson(id: 'uuid-alice', nickname: 'Alice', socketID: 'socket-1'),
        playerJson(
          id: 'uuid-bob',
          nickname: 'Bob',
          socketID: 'socket-2',
          connected: false,
        ),
      ],
    ),
  );
  return notifier;
}

void main() {
  testWidgets(
    'creator sees a remove affordance on disconnected lobby players and '
    'none on connected ones',
    (tester) async {
      final fake = FakeSocketAdapter();
      final repository = _buildRepository(fake);
      addTearDown(repository.dispose);
      final notifier = await _seedCreator(fake, repository);
      addTearDown(notifier.dispose);

      await tester.pumpWidget(_host(repository, notifier, const LobbyPage()));
      await tester.pump();
      await tester.pump();

      expect(
          find.byKey(const ValueKey('lobby-remove-uuid-bob')), findsOneWidget);
      expect(
          find.byKey(const ValueKey('lobby-remove-uuid-alice')), findsNothing);
    },
  );

  testWidgets(
    'tapping remove shows a confirm dialog; confirming emits removePlayer '
    'with the target playerId',
    (tester) async {
      final fake = FakeSocketAdapter();
      final repository = _buildRepository(fake);
      addTearDown(repository.dispose);
      final notifier = await _seedCreator(fake, repository);
      addTearDown(notifier.dispose);

      await tester.pumpWidget(_host(repository, notifier, const LobbyPage()));
      await tester.pump();
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('lobby-remove-uuid-bob')));
      await tester.pumpAndSettle();
      expect(find.text('Remove player'), findsOneWidget);

      fake.sentEvents.clear();
      await tester.tap(find.widgetWithText(TextButton, 'Remove'));
      await tester.pumpAndSettle();

      expect(fake.sentEvents, hasLength(1));
      expect(fake.sentEvents.single.name, 'removePlayer');
      expect(fake.sentEvents.single.payload['roomId'], 'XY7ZQR');
      expect(fake.sentEvents.single.payload['playerId'], 'uuid-bob');
    },
  );

  testWidgets(
    'cancelling the remove dialog emits nothing (per open dialog)',
    (tester) async {
      final fake = FakeSocketAdapter();
      final repository = _buildRepository(fake);
      addTearDown(repository.dispose);
      final notifier = await _seedCreator(fake, repository);
      addTearDown(notifier.dispose);

      await tester.pumpWidget(_host(repository, notifier, const LobbyPage()));
      await tester.pump();
      await tester.pump();

      fake.sentEvents.clear();
      await tester.tap(find.byKey(const ValueKey('lobby-remove-uuid-bob')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();

      expect(fake.sentEvents, isEmpty);
    },
  );

  testWidgets(
    'non-creator sees no remove affordance at all',
    (tester) async {
      final fake = FakeSocketAdapter();
      final repository = _buildRepository(fake);
      addTearDown(repository.dispose);
      final notifier = RoomNotifier(repository);
      addTearDown(notifier.dispose);

      // Bob joins a room created by someone else.
      await repository.joinRoom(
        nickname: 'Bob',
        roomCode: 'XY7ZQR',
        faction: 'Saxony',
        mat: '2',
      );
      fake.serverEmit(
        'joinRoomSuccess',
        roomJson(
          id: 'XY7ZQR',
          isJoin: true,
          players: [
            playerJson(id: 'uuid-alice', nickname: 'Alice', socketID: 's1'),
            playerJson(
              id: 'uuid-carol',
              nickname: 'Carol',
              socketID: fake.nextId,
              connected: false,
            ),
          ],
        ),
      );

      await tester.pumpWidget(_host(repository, notifier, const LobbyPage()));
      await tester.pump();
      await tester.pump();

      expect(
          find.byKey(const ValueKey('lobby-remove-uuid-carol')), findsNothing);
      expect(
          find.byKey(const ValueKey('lobby-remove-uuid-alice')), findsNothing);
    },
  );

  testWidgets(
    'game view highlights the current turn player row',
    (tester) async {
      final fake = FakeSocketAdapter();
      final repository = _buildRepository(fake);
      addTearDown(repository.dispose);
      final notifier = RoomNotifier(repository);
      addTearDown(notifier.dispose);

      await repository.joinRoom(
        nickname: 'Alice',
        roomCode: 'XY7ZQR',
        faction: 'Crimea',
        mat: '1',
      );
      fake.serverEmit(
        'joinRoomSuccess',
        roomJson(
          id: 'XY7ZQR',
          isJoin: false,
          players: [
            playerJson(
                id: 'uuid-alice', nickname: 'Alice', socketID: fake.nextId),
            playerJson(id: 'uuid-bob', nickname: 'Bob', socketID: 's2'),
          ],
        ),
      );

      // GamePage builds its own Scaffold/AnimatedSwitcher — no extra
      // SingleChildScrollView (its layout requires bounded height).
      await tester.pumpWidget(
          _host(repository, notifier, const GamePage(), scrollable: false));
      await tester.pump();
      await tester.pump();

      // Alice is the turn player (roomJson sets turn = players[0]).
      // DataRow is a table-row config, not a Widget — read the rows off
      // the DataTable and match by cell content. toStringDeep() flattens
      // the whole cell subtree, so a plain toString() match on the Text
      // data covers the Row/Flexible wrapping.
      final table = tester.widget<DataTable>(find.byType(DataTable));
      expect(table.rows, hasLength(2));
      String rowName(DataRow r) => (r.cells.first.child as Row)
          .children
          .whereType<Flexible>()
          .map((f) => (f.child as Text).data)
          .join();
      final aliceRow = table.rows.firstWhere((r) => rowName(r) == 'Alice');
      final bobRow = table.rows.firstWhere((r) => rowName(r) == 'Bob');
      // Highlight = non-null row color; the other row is null.
      expect(aliceRow.color, isNotNull);
      expect(bobRow.color, isNull);
    },
  );

  testWidgets(
    'game view offers remove affordance to the creator on offline players',
    (tester) async {
      final fake = FakeSocketAdapter();
      final repository = _buildRepository(fake);
      addTearDown(repository.dispose);
      final notifier = RoomNotifier(repository);
      addTearDown(notifier.dispose);

      await repository.createRoom(
        nickname: 'Alice',
        faction: 'Crimea',
        mat: '1',
        timerSec: 900,
      );
      fake.serverEmit(
        'joinRoomSuccess',
        roomJson(
          id: 'XY7ZQR',
          isJoin: false,
          players: [
            playerJson(
                id: 'uuid-alice', nickname: 'Alice', socketID: 'socket-1'),
            playerJson(
              id: 'uuid-bob',
              nickname: 'Bob',
              socketID: 's2',
              connected: false,
            ),
          ],
        ),
      );

      await tester.pumpWidget(
          _host(repository, notifier, const GamePage(), scrollable: false));
      await tester.pump();
      await tester.pump();

      expect(
          find.byKey(const ValueKey('remove-player-uuid-bob')), findsOneWidget);
      expect(
          find.byKey(const ValueKey('remove-player-uuid-alice')), findsNothing);
    },
  );
}
