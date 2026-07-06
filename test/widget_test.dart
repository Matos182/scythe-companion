// SPDX-License-Identifier: MIT

// Smoke test: the app boots with a fake socket and shows the home menu,
// and every route reachable from home renders without throwing.
// Replaces the counter-template test (audit A15) that could never pass.
//
// The navigation sweep exists because a page that reads a missing
// Provider (e.g. `context.read<GameRepository>()` before it was added to
// main.dart's MultiProvider) only crashes when the page is BUILT — a
// boot-only test cannot catch it (this exact bug shipped in the T3.2
// draft and was caught in review, not by tests).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scythe_companion/data/game_repository.dart';
import 'package:scythe_companion/data/notifications.dart';
import 'package:scythe_companion/data/session_store.dart';
import 'package:scythe_companion/data/settings_repository.dart';
import 'package:scythe_companion/data/socket_service.dart';
import 'package:scythe_companion/main.dart';

import 'data/fake_socket_adapter.dart';

void main() {
  GameRepository buildRepository() => GameRepository(
        socketService: SocketService(adapter: FakeSocketAdapter()),
        sessionStore: InMemorySessionStore(),
        settingsRepository: InMemorySettingsRepository(),
        initialServerUrl: 'http://test-server:3000',
      );

  // T3.4: MyApp now requires a NotificationService. The real plugin
  // touches a method channel that doesn't exist in the test VM, so
  // we inject a lightweight fake whose methods are no-ops.
  final notifications = _NoopNotificationService();

  testWidgets('App boots to the home menu', (WidgetTester tester) async {
    await tester.pumpWidget(
        MyApp(repository: buildRepository(), notifications: notifications));

    expect(find.text('Scythe Companion'), findsOneWidget);
    expect(find.text('Create Room'), findsOneWidget);
    expect(find.text('Join Room'), findsOneWidget);
    expect(find.text('Simple Convert'), findsOneWidget);
    expect(find.text('Game Results'), findsOneWidget);
  });

  testWidgets('Every home-menu route builds without throwing',
      (WidgetTester tester) async {
    // (button label, marker text expected on the destination page)
    const routes = [
      ('Simple Convert', 'Popularity'),
      ('Create Room', 'Create Room'),
      ('Join Room', 'Join Room'),
    ];

    for (final (button, marker) in routes) {
      // Fresh app per route: home.dart navigates with goNamed (replace,
      // not push), so there is no back stack to pop. The unique key
      // forces a NEW _MyAppState (and a new router) — pumping the same
      // widget type reuses the old State, which would still be sitting
      // on the previous route.
      await tester.pumpWidget(MyApp(
        key: UniqueKey(),
        repository: buildRepository(),
        notifications: notifications,
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text(button).first);
      await tester.pumpAndSettle();
      expect(find.text(marker), findsWidgets,
          reason: 'route "$button" should render a page showing "$marker"');
    }
  });

  testWidgets('Settings opens from the home AppBar gear (T3.2)',
      (WidgetTester tester) async {
    await tester.pumpWidget(
        MyApp(repository: buildRepository(), notifications: notifications));

    await tester.tap(find.byTooltip('Server & nickname'));
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Server URL'), findsOneWidget);
  });
}

/// Test-only stub: the real [NotificationService] calls into a method
/// channel that isn't available in the Dart test VM. This subclass
/// shadows every method with a no-op so `widget_test.dart` can pump the
/// full `MyApp` tree (including `home.dart`'s permission request).
class _NoopNotificationService extends NotificationService {
  _NoopNotificationService() : super();

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<void> showYourTurn({String? nickname}) async {}

  @override
  Future<void> cancel() async {}
}
