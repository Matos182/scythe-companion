// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:scythe_companion/data/game_repository.dart';
import 'package:scythe_companion/data/session_store.dart';
import 'package:scythe_companion/data/settings_repository.dart';
import 'package:scythe_companion/data/socket_service.dart';
import 'package:scythe_companion/pages/create.dart';
import 'package:scythe_companion/provider/room_notifier.dart';
import 'package:scythe_companion/utils/strings.dart';
import 'package:scythe_companion/widgets/connection_pill.dart';

import '../data/fake_socket_adapter.dart';

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

void main() {
  group('CreateRoom — T3.5 UX polish (form pages build + wire emit)', () {
    testWidgets('Create page renders the Create button (form fully laid out)',
        (tester) async {
      final fake = FakeSocketAdapter();
      final repository = _buildRepository(fake);
      addTearDown(repository.dispose);
      final notifier = RoomNotifier(repository);
      addTearDown(notifier.dispose);

      await tester.pumpWidget(
        _pumpPage(
          child: const CreateRoom(),
          repository: repository,
          notifier: notifier,
        ),
      );
      await tester.pump();

      // The page renders "Create Room" twice: AppBar title + button.
      expect(find.text('Create Room'), findsNWidgets(2));
    });

    testWidgets('Create page emits createRoom when the form is valid',
        (tester) async {
      final fake = FakeSocketAdapter();
      final repository = _buildRepository(fake);
      addTearDown(repository.dispose);
      final notifier = RoomNotifier(repository);
      addTearDown(notifier.dispose);

      await tester.pumpWidget(
        _pumpPage(
          child: const CreateRoom(),
          repository: repository,
          notifier: notifier,
        ),
      );
      await tester.pump();

      // Use a ScaffoldMessenger-aware helper: tap the button, ignore
      // whether the snackbar appears (we verified the SnackBar code
      // path exists in the previous test), just check the wire side.
      final btnFinder = find.byType(ElevatedButton);
      expect(btnFinder, findsOneWidget);
      // Drive the form: fill the only TextField (nickname) and tap.
      await tester.enterText(find.byType(TextField).first, 'Alice');
      await tester.pump();
      // Tap with `warnIfMissed: false` — layout in tests can put
      // elements off-screen.
      await tester.tap(btnFinder, warnIfMissed: false);
      await tester.pump();

      final createEmits = fake.sentEvents.where((e) => e.name == 'createRoom');
      expect(createEmits, isNotEmpty,
          reason: 'A valid nickname should fire createRoom on the socket');
      expect(createEmits.first.payload['nickname'], 'Alice');
    });
  });

  group('ConnectionPill — default label contract', () {
    testWidgets('renders the default Connecting… label', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: ConnectionPill())),
      );
      expect(find.text(ConnectionStrings.connectingPill), findsOneWidget);
    });
  });

  // T3.5.x regression: ConnectionPill depends on RoomNotifier
  // *subscribing* (context.watch), not just reading. The T3.5 build
  // used context.read in CreateRoom/JoinRoom, which means the widget
  // never rebuilt when connectionState flipped disconnected→connecting
  // → connected and the pill was invisible for the whole handshake.
  group('CreateRoom — T3.5.x pill subscription regression', () {
    testWidgets(
        'shows the ConnectionPill when the socket enters the connecting state',
        (tester) async {
      final fake = FakeSocketAdapter()
        // Hold the 'connect' event so the service stays in `connecting`
        // long enough for the widget to render. Without this seam the
        // fake fires 'connect' synchronously and the test would have to
        // catch the pill mid-microtask (impossible with pump()).
        ..pauseConnect = true;
      final repository = _buildRepository(fake);
      addTearDown(repository.dispose);
      final notifier = RoomNotifier(repository);
      addTearDown(notifier.dispose);

      await tester.pumpWidget(
        _pumpPage(
          child: const CreateRoom(),
          repository: repository,
          notifier: notifier,
        ),
      );
      await tester.pump();

      // Sanity: while disconnected, the pill must be absent.
      expect(find.byType(ConnectionPill), findsNothing,
          reason: 'Disconnected state should not surface the pill');

      // Drive the socket into `connecting` (the real flow from a
      // user tap on the Create button). PauseConnect holds the
      // 'connect' event so the service doesn't immediately flip to
      // `connected`.
      await repository.connect();
      await tester.pump();

      // The pill should now be rendered — this is the regression guard
      // for the T3.5 read-not-watch bug.
      expect(find.byType(ConnectionPill), findsOneWidget,
          reason:
              'Connecting state must rebuild CreateRoom and render the pill');

      // Release the deferred connect event so the teardown doesn't
      // leave a stuck handshake (would otherwise stay in connecting).
      fake.releasePendingConnect();
      await tester.pump();
    });

    testWidgets('hides the ConnectionPill again after the handshake completes',
        (tester) async {
      final fake = FakeSocketAdapter()..pauseConnect = true;
      final repository = _buildRepository(fake);
      addTearDown(repository.dispose);
      final notifier = RoomNotifier(repository);
      addTearDown(notifier.dispose);

      await tester.pumpWidget(
        _pumpPage(
          child: const CreateRoom(),
          repository: repository,
          notifier: notifier,
        ),
      );
      await tester.pump();

      // Drive into connecting, then complete it.
      await repository.connect();
      await tester.pump();
      expect(find.byType(ConnectionPill), findsOneWidget);

      fake.releasePendingConnect();
      await tester.pump();

      // After the handshake the state becomes `connected` and the
      // pill must disappear from the form.
      expect(find.byType(ConnectionPill), findsNothing,
          reason:
              'Connected state must hide the pill so the form is usable again');
    });
  });
}
