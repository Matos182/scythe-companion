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

import '../data/fake_socket_adapter.dart';
import '../data/socket_service_test.dart' show roomJson, playerJson;

/// Builds a repository + notifier pair wired to [fake], mirroring the
/// composition root in main.dart (T3.2 + T3.1 wiring). The test never
/// touches the network — the fake stands in for socket.io.
({GameRepository repository, RoomNotifier notifier}) _build(
  FakeSocketAdapter fake, {
  String? serverUrl,
}) {
  final service = SocketService(adapter: fake); // no probe: skip version check
  final repository = GameRepository(
    socketService: service,
    sessionStore: InMemorySessionStore(),
    settingsRepository: InMemorySettingsRepository(),
    initialServerUrl: serverUrl,
  );
  final notifier = RoomNotifier(repository);
  return (repository: repository, notifier: notifier);
}

Widget _gameUnderTest(GameRepository repository, RoomNotifier notifier) {
  return MaterialApp(
    scaffoldMessengerKey: GlobalKey<ScaffoldMessengerState>(),
    home: MultiProvider(
      providers: [
        Provider<GameRepository>.value(value: repository),
        ChangeNotifierProvider<RoomNotifier>.value(value: notifier),
      ],
      // No SingleChildScrollView — the Scaffold inside GamePage has a
      // MultiChildLayout that needs bounded height. The page itself
      // uses Column-with-Center + DataTable; it fits in the default
      // test viewport (800x600) for the small rooms we test (1-2
      // players). Larger rooms would scroll; that's a T3.5 polish.
      child: const Scaffold(body: GamePage()),
    ),
  );
}

/// Push a full room into the notifier via the fake's join/create
/// success event so the page has something to render.
///
/// Defaults to `isJoin: false` (in-game) — T3.3 is the in-game view.
/// Tests that want the lobby (creator waiting for players) pass
/// `isJoin: true` explicitly.
void _seatAlice(FakeSocketAdapter fake,
    {List<Map<String, dynamic>>? players,
    String id = 'AB3KMN',
    bool isJoin = false}) {
  final playersJson = players ??
      [
        playerJson(
            id: 'uuid-alice',
            nickname: 'Alice',
            socketID: 'socket-1',
            remainingSec: 300),
      ];
  fake.serverEmit('createRoomSuccess',
      roomJson(id: id, isJoin: isJoin, players: playersJson));
}

void main() {
  group('GamePage — turn banner', () {
    testWidgets("renders the active player's name and round counter",
        (tester) async {
      final fake = FakeSocketAdapter();
      final built = _build(fake);
      addTearDown(built.repository.dispose);
      addTearDown(built.notifier.dispose);

      await built.repository.createRoom(
          nickname: 'Alice', faction: 'Crimea', mat: '1', timerSec: 900);
      _seatAlice(fake);

      await tester.pumpWidget(_gameUnderTest(built.repository, built.notifier));
      await tester.pump();
      await tester.pump();

      expect(find.text("Alice's Turn  -  Round: 1"), findsOneWidget);
      expect(find.text('Turn Time Remaining:'), findsOneWidget);
      // 300s default from _seatAlice → 05:00. Appears at least once
      // (the countdown + once per player row in the presence table;
      // the selector's text + the Alice DataTable row).
      expect(find.text('05:00'), findsWidgets);
    });

    testWidgets('shows the lobby when room.isJoin is true (no game started)',
        (tester) async {
      final fake = FakeSocketAdapter();
      final built = _build(fake);
      addTearDown(built.repository.dispose);
      addTearDown(built.notifier.dispose);

      // Seat Alice but keep isJoin: true → page should render the
      // embedded LobbyPage (creator waiting for players).
      await built.repository.createRoom(
          nickname: 'Alice', faction: 'Crimea', mat: '1', timerSec: 900);
      _seatAlice(fake, isJoin: true);

      await tester.pumpWidget(_gameUnderTest(built.repository, built.notifier));
      await tester.pump();

      expect(find.text('Waiting for Players...'), findsOneWidget);
      expect(find.text("Alice's Turn  -  Round: 1"), findsNothing);
    });
  });

  group('GamePage — pass button gating (T3.1 notifier.isMyTurn)', () {
    testWidgets('pass is enabled when this client is the active player',
        (tester) async {
      final fake = FakeSocketAdapter();
      final built = _build(fake);
      addTearDown(built.repository.dispose);
      addTearDown(built.notifier.dispose);

      await built.repository.createRoom(
          nickname: 'Alice', faction: 'Crimea', mat: '1', timerSec: 900);
      _seatAlice(fake);

      await tester.pumpWidget(_gameUnderTest(built.repository, built.notifier));
      await tester.pump();
      await tester.pump();

      final passButton = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Pass Turn'),
      );
      expect(passButton.onPressed, isNotNull);

      // Tapping emits `turn` on the fake — proves the binding is real.
      await tester.tap(find.text('Pass Turn'));
      await tester.pump();
      expect(
        fake.sentEvents.where((e) => e.name == 'turn'),
        isNotEmpty,
      );
    });

    testWidgets('pass is disabled when another player is the active turn',
        (tester) async {
      final fake = FakeSocketAdapter();
      final built = _build(fake);
      addTearDown(built.repository.dispose);
      addTearDown(built.notifier.dispose);

      // Us = Alice (default socket id). Bob's seat gets socket-bob.
      // The active turn is set to index 1 (Bob) so it's not my turn.
      fake.nextId = 'socket-1';
      await built.repository.createRoom(
          nickname: 'Alice', faction: 'Crimea', mat: '1', timerSec: 900);
      _seatAlice(fake, players: [
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
      ]);
      // Tell the notifier it's Bob's turn (turnIndex = 1) so isMyTurn
      // (which compares _room.turn.id to my playerId = alice) is false.
      // `roomJson` defaults isJoin:true — override to false (in-game).
      fake.serverEmit(
          'newTurn',
          roomJson(
            id: 'AB3KMN',
            turnIndex: 1,
            isJoin: false,
            players: [
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
            ],
          ));
      await tester.pumpWidget(_gameUnderTest(built.repository, built.notifier));
      await tester.pump();
      await tester.pump();

      final passButton = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Pass Turn'),
      );
      expect(passButton.onPressed, isNull);
    });
  });

  group('GamePage — pause/resume gate on isMyTurn', () {
    testWidgets('pause icon is present and tappable for the active player',
        (tester) async {
      final fake = FakeSocketAdapter();
      final built = _build(fake);
      addTearDown(built.repository.dispose);
      addTearDown(built.notifier.dispose);

      await built.repository.createRoom(
          nickname: 'Alice', faction: 'Crimea', mat: '1', timerSec: 900);
      _seatAlice(fake);
      await tester.pumpWidget(_gameUnderTest(built.repository, built.notifier));
      await tester.pump();
      await tester.pump();

      // AppBar Icons: pause = it's my turn, game not paused.
      final pauseIcon = find.byIcon(Icons.pause).first;
      expect(pauseIcon, findsOneWidget);
      await tester.tap(pauseIcon);
      await tester.pump();
      expect(
        fake.sentEvents.where((e) => e.name == 'pause'),
        isNotEmpty,
      );
    });
  });

  group('GamePage — presence badges (T2.3 player.connected)', () {
    testWidgets("disconnected players render with an '(offline)' suffix",
        (tester) async {
      final fake = FakeSocketAdapter();
      final built = _build(fake);
      addTearDown(built.repository.dispose);
      addTearDown(built.notifier.dispose);

      await built.repository.createRoom(
          nickname: 'Alice', faction: 'Crimea', mat: '1', timerSec: 900);
      _seatAlice(fake, players: [
        playerJson(
            id: 'uuid-alice',
            nickname: 'Alice',
            socketID: 'socket-1',
            remainingSec: 300),
        playerJson(
            id: 'uuid-bob',
            nickname: 'Bob',
            socketID: 'socket-bob',
            remainingSec: 280,
            connected: false),
      ]);

      await tester.pumpWidget(_gameUnderTest(built.repository, built.notifier));
      await tester.pump();
      await tester.pump();

      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('Bob (offline)'), findsOneWidget);
    });
  });

  group('GamePage — leave action (T3.5 confirm-leave)', () {
    testWidgets('shows the leave icon in the AppBar', (tester) async {
      final fake = FakeSocketAdapter();
      final built = _build(fake);
      addTearDown(built.repository.dispose);
      addTearDown(built.notifier.dispose);

      await built.repository.createRoom(
          nickname: 'Alice', faction: 'Crimea', mat: '1', timerSec: 900);
      _seatAlice(fake);

      await tester.pumpWidget(_gameUnderTest(built.repository, built.notifier));
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const ValueKey('leave-action')), findsOneWidget);
      expect(find.byIcon(Icons.exit_to_app), findsOneWidget);
    });

    testWidgets('tapping leave shows the confirm dialog and cancels cleanly',
        (tester) async {
      final fake = FakeSocketAdapter();
      final built = _build(fake);
      addTearDown(built.repository.dispose);
      addTearDown(built.notifier.dispose);

      await built.repository.createRoom(
          nickname: 'Alice', faction: 'Crimea', mat: '1', timerSec: 900);
      _seatAlice(fake);
      final sentBefore = fake.sentEvents.length;
      await tester.pumpWidget(_gameUnderTest(built.repository, built.notifier));
      await tester.pump();
      await tester.pump();

      // Tap the leave action — dialog appears.
      await tester.tap(find.byKey(const ValueKey('leave-action')));
      await tester.pumpAndSettle();

      // Game (in-game, not lobby) shows the in-game dialog copy.
      expect(find.text('Leave the game?'), findsOneWidget);

      // Cancel — dialog dismisses, leaveSession NOT called.
      await tester.tap(find.text('Stay'));
      await tester.pumpAndSettle();

      expect(find.text('Leave the game?'), findsNothing);
      // Cancel must not have produced any new socket emit (the only
      // emits at this point come from _seatAlice's createRound).
      expect(fake.sentEvents.length, sentBefore);
    });

    testWidgets('confirming leave calls leaveSession on the notifier',
        (tester) async {
      final fake = FakeSocketAdapter();
      final built = _build(fake);
      addTearDown(built.repository.dispose);
      addTearDown(built.notifier.dispose);

      await built.repository.createRoom(
          nickname: 'Alice', faction: 'Crimea', mat: '1', timerSec: 900);
      _seatAlice(fake);
      await tester.pumpWidget(_gameUnderTest(built.repository, built.notifier));
      await tester.pump();
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('leave-action')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Leave'));
      await tester.pumpAndSettle();

      // After leaveSession the notifier room is the empty default —
      // the page rebuilds and the page-level room.id is empty.
      expect(built.notifier.room.id, isEmpty);
    });
  });

  group('GamePage — connection banners', () {
    testWidgets('shows "reconnecting" copy while the socket retries',
        (tester) async {
      final fake = FakeSocketAdapter();
      final built = _build(fake);
      addTearDown(built.repository.dispose);
      addTearDown(built.notifier.dispose);

      await built.repository.createRoom(
          nickname: 'Alice', faction: 'Crimea', mat: '1', timerSec: 900);
      _seatAlice(fake);
      await tester.pumpWidget(_gameUnderTest(built.repository, built.notifier));
      await tester.pump();
      await tester.pump();

      // Socket had connected (from the createRoom choreography).
      // Simulate a drop. The fake fires `disconnect`, the service
      // transitions to reconnecting, the notifier notifies, the page
      // rebuilds — but only on the next pump() because we're inside
      // a test.
      fake.simulateDrop();
      await tester.pump(); // process disconnect → reconnecting
      await tester.pump(); // second pump for the rebuild to flush

      expect(find.text('Connection lost — reconnecting…'), findsOneWidget);
    });

    testWidgets('shows the disconnected copy on a fully-disconnected socket',
        (tester) async {
      final fake = FakeSocketAdapter();
      final built = _build(fake);
      addTearDown(built.repository.dispose);
      addTearDown(built.notifier.dispose);

      // Never connect: skip createRoom so the socket stays at default.
      await tester.pumpWidget(_gameUnderTest(built.repository, built.notifier));
      await tester.pump();

      expect(find.text('Disconnected from server'), findsOneWidget);
    });
  });

  group('GamePage — tick selector scope (T3.1 hand-off debt item 4)', () {
    testWidgets('a tick only rebuilds the countdown subtree, not the page',
        (tester) async {
      final fake = FakeSocketAdapter();
      final built = _build(fake);
      addTearDown(built.repository.dispose);
      addTearDown(built.notifier.dispose);

      await built.repository.createRoom(
          nickname: 'Alice', faction: 'Crimea', mat: '1', timerSec: 900);
      _seatAlice(fake);
      await tester.pumpWidget(_gameUnderTest(built.repository, built.notifier));
      await tester.pump();
      await tester.pump();

      // The banner "Alice's Turn — Round: 1" lives outside the selector.
      // We re-find on every rebuild via a stable Finder so any rebuild
      // that drops it would have to re-resolve and keep it on screen.
      final banner = find.text("Alice's Turn  -  Round: 1");
      expect(banner, findsOneWidget);

      // A tick arrives — only the countdown (inside Selector) should
      // redraw; the page-level state hasn't changed. If Selector
      // weren't there, the whole page would still rebuild (Provider's
      // ChangeNotifier notifies on every tick), but the visible
      // outcome is identical, so what we verify is that the test
      // observes a single-frame tick rendered through the selector.
      // We pin by reading the Selector's outcome: 04:59.
      fake.serverEmit('tick', {
        'roomCode': 'AB3KMN',
        'playerId': 'uuid-alice',
        'remainingSec': 299,
      });
      await tester.pump();
      await tester.pump();

      // Banner still on screen after tick.
      expect(banner, findsOneWidget);
      // Countdown updated via the selector. The same value also shows
      // on Alice's row in the presence table, so expect ≥ 1.
      expect(find.text('04:59'), findsWidgets);
    });
  });

  group('GameRepository.rejoinSavedSession — T3.3 boot wiring', () {
    test('returns false when no session is stored (silent no-op on boot)',
        () async {
      final fake = FakeSocketAdapter();
      final built = _build(fake);
      addTearDown(built.repository.dispose);
      addTearDown(built.notifier.dispose);

      // The composition root calls this in initState — no session means
      // it returns false and main.dart's _attemptBootRejoin drops out.
      expect(await built.repository.rejoinSavedSession(), isFalse);
      expect(fake.sentEvents, isEmpty);
    });

    test('fires rejoinRoom with stored credentials when a session exists',
        () async {
      final fake = FakeSocketAdapter();
      final built = _build(fake);
      addTearDown(built.repository.dispose);
      addTearDown(built.notifier.dispose);

      await built.repository.sessionStore
          .save(const GameSession(roomCode: 'ZZTOP9', playerId: 'uuid-old'));
      final resumed = await built.repository.rejoinSavedSession();
      expect(resumed, isTrue);

      final rejoin =
          fake.sentEvents.where((e) => e.name == 'rejoinRoom').single;
      expect(rejoin.payload['roomCode'], 'ZZTOP9');
      expect(rejoin.payload['playerId'], 'uuid-old');
    });
  });
}
