// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:scythe_companion/data/game_repository.dart';
import 'package:scythe_companion/data/session_store.dart';
import 'package:scythe_companion/data/settings_repository.dart';
import 'package:scythe_companion/data/socket_service.dart';
import 'package:scythe_companion/pages/create.dart';
import 'package:scythe_companion/pages/game.dart';
import 'package:scythe_companion/pages/join.dart';
import 'package:scythe_companion/provider/room_notifier.dart';
import 'package:scythe_companion/widgets/scrollable_center_column.dart';

import '../data/fake_socket_adapter.dart';
import '../data/socket_service_test.dart' show roomJson, playerJson;

/// A deliberately cramped screen: 320×480 logical pixels is roughly a
/// small phone in portrait with the keyboard open. Every page in this
/// file overflowed at this size before ScrollableCenterColumn.
const _smallPhone = Size(320, 480);

void _useSmallPhone(WidgetTester tester) {
  tester.view.physicalSize = _smallPhone;
  tester.view.devicePixelRatio = 1.0;
  // Without this the shrunken viewport leaks into every later test in
  // the process and produces failures that look unrelated.
  addTearDown(tester.view.reset);
}

GameRepository _buildRepository(FakeSocketAdapter fake) {
  return GameRepository(
    socketService: SocketService(adapter: fake),
    sessionStore: InMemorySessionStore(),
    settingsRepository: InMemorySettingsRepository(),
    initialServerUrl: 'http://test-server:3000',
  );
}

Widget _pumpPage({
  required Widget child,
  required GameRepository repository,
  required RoomNotifier notifier,
}) {
  return MaterialApp(
    scaffoldMessengerKey: GlobalKey<ScaffoldMessengerState>(),
    home: MultiProvider(
      providers: [
        Provider<GameRepository>.value(value: repository),
        ChangeNotifierProvider<RoomNotifier>.value(value: notifier),
      ],
      child: child,
    ),
  );
}

/// A full 7-player room — Scythe's maximum, and the case the parked
/// backlog item was actually worried about.
List<Map<String, dynamic>> _sevenPlayers() {
  const names = ['Alice', 'Bob', 'Carol', 'Dave', 'Erin', 'Frank', 'Grace'];
  return [
    for (var i = 0; i < names.length; i++)
      playerJson(
        id: 'uuid-${names[i].toLowerCase()}',
        nickname: names[i],
        socketID: 'socket-$i',
        remainingSec: 300,
      ),
  ];
}

void main() {
  group('Small-phone vertical overflow (T4.6)', () {
    testWidgets('CreateRoom lays out at 320x480 without overflowing',
        (tester) async {
      _useSmallPhone(tester);
      final fake = FakeSocketAdapter();
      final repository = _buildRepository(fake);
      addTearDown(repository.dispose);
      final notifier = RoomNotifier(repository);
      addTearDown(notifier.dispose);

      await tester.pumpWidget(_pumpPage(
        child: const CreateRoom(),
        repository: repository,
        notifier: notifier,
      ));
      await tester.pump();

      // A RenderFlex overflow is reported through takeException, NOT as a
      // thrown assertion — a test that never calls this passes happily
      // against a broken layout.
      expect(tester.takeException(), isNull);
      expect(find.byType(ScrollableCenterColumn), findsOneWidget);
    });

    testWidgets('CreateRoom can scroll to the button hidden below the fold',
        (tester) async {
      _useSmallPhone(tester);
      final fake = FakeSocketAdapter();
      final repository = _buildRepository(fake);
      addTearDown(repository.dispose);
      final notifier = RoomNotifier(repository);
      addTearDown(notifier.dispose);

      await tester.pumpWidget(_pumpPage(
        child: const CreateRoom(),
        repository: repository,
        notifier: notifier,
      ));
      await tester.pump();

      // The point of the fix: the submit button is off-screen at this
      // size and must be reachable by dragging.
      final button = find.widgetWithText(ElevatedButton, 'Create Room');
      // Target our scroll view explicitly — the dropdowns bring their own
      // Scrollables, so an unqualified finder matches several.
      final scrollView = find
          .descendant(
            of: find.byType(ScrollableCenterColumn),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.dragUntilVisible(button, scrollView, const Offset(0, -100));
      expect(button, findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('JoinRoom lays out at 320x480 without overflowing',
        (tester) async {
      _useSmallPhone(tester);
      final fake = FakeSocketAdapter();
      final repository = _buildRepository(fake);
      addTearDown(repository.dispose);
      final notifier = RoomNotifier(repository);
      addTearDown(notifier.dispose);

      await tester.pumpWidget(_pumpPage(
        child: const JoinRoom(),
        repository: repository,
        notifier: notifier,
      ));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byType(ScrollableCenterColumn), findsOneWidget);
    });

    testWidgets('GamePage with a full 7-player room does not overflow',
        (tester) async {
      _useSmallPhone(tester);
      final fake = FakeSocketAdapter();
      final repository = _buildRepository(fake);
      addTearDown(repository.dispose);
      final notifier = RoomNotifier(repository);
      addTearDown(notifier.dispose);

      await repository.createRoom(
          nickname: 'Alice', faction: 'Crimea', mat: '1', timerSec: 900);
      fake.serverEmit(
        'createRoomSuccess',
        roomJson(id: 'AB3KMN', isJoin: false, players: _sevenPlayers()),
      );

      await tester.pumpWidget(_pumpPage(
        child: const GamePage(),
        repository: repository,
        notifier: notifier,
      ));
      await tester.pump();
      await tester.pump();

      // 7 rows of DataTable plus banner, countdown and pass button is
      // far taller than 480px — this is the case T3.3 parked.
      expect(tester.takeException(), isNull);
      // roomJson's totalTurns default is 1 — same banner text game_test uses.
      expect(find.text("Alice's Turn  -  Round: 1"), findsOneWidget);
    });
  });

  group('ScrollableCenterColumn — centring is preserved', () {
    testWidgets('short content stays vertically centred, not top-aligned',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: ScrollableCenterColumn(
            children: [SizedBox(height: 40, child: Text('middle'))],
          ),
        ),
      ));

      // The naive SingleChildScrollView fix loses the centring: the
      // Column shrink-wraps in unbounded height and pins to the top.
      // Assert the child sits near the middle of the viewport, which is
      // what ConstrainedBox(minHeight: viewport) buys us.
      final screen = tester.getSize(find.byType(Scaffold));
      final box = tester.getRect(find.text('middle'));
      final centreOffset = (box.center.dy - screen.height / 2).abs();
      expect(centreOffset, lessThan(30),
          reason: 'content should be centred, was at dy=${box.center.dy} '
              'in a ${screen.height}px viewport');
      expect(tester.takeException(), isNull);
    });

    testWidgets('shrink-wraps instead of asserting inside another scrollable',
        (tester) async {
      // An unbounded maxHeight would make ConstrainedBox assert. Nesting
      // is how the next call site breaks, so pin the guard.
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ScrollableCenterColumn(
              children: [Text('nested')],
            ),
          ),
        ),
      ));

      expect(find.text('nested'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
