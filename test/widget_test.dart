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

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:scythe_companion/data/game_repository.dart';
import 'package:scythe_companion/data/notifications.dart';
import 'package:scythe_companion/data/session_store.dart';
import 'package:scythe_companion/data/settings_repository.dart';
import 'package:scythe_companion/data/socket_service.dart';
import 'package:scythe_companion/main.dart';
import 'package:scythe_companion/models/route_const.dart';

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
      // Use a fresh app per route. The unique key forces a NEW
      // _MyAppState (and a new router) — pumping the same widget type reuses
      // the old State, which would still be sitting on the previous route.
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

  testWidgets('create, join, settings, and result expose a back button',
      (tester) async {
    for (final routeName in [
      RouteNames.create,
      RouteNames.join,
      RouteNames.settings,
    ]) {
      await tester.pumpWidget(MyApp(
        key: UniqueKey(),
        repository: buildRepository(),
        notifications: notifications,
      ));
      await tester.pumpAndSettle();

      tester.element(find.text('Scythe Companion').first).goNamed(routeName);
      await tester.pumpAndSettle();

      expect(find.byType(BackButton), findsOneWidget,
          reason: '$routeName should be nested under home');
    }

    await tester.pumpWidget(MyApp(
      key: UniqueKey(),
      repository: buildRepository(),
      notifications: notifications,
    ));
    await tester.pumpAndSettle();
    tester
        .element(find.text('Scythe Companion').first)
        .goNamed(RouteNames.addplayer);
    await tester.pumpAndSettle();
    unawaited(tester
        .element(find.text('Player 1 Score'))
        .pushNamed(RouteNames.result));
    await tester.pumpAndSettle();

    expect(find.byType(BackButton), findsOneWidget);
  });

  testWidgets('goNamed create then back returns to home', (tester) async {
    await tester.pumpWidget(
        MyApp(repository: buildRepository(), notifications: notifications));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ElevatedButton, 'Create Room'));
    await tester.pumpAndSettle();
    expect(find.byType(BackButton), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(find.text('Simple Convert'), findsOneWidget);
    expect(find.text('Game Results'), findsOneWidget);
  });

  testWidgets('result back returns to the players form', (tester) async {
    await tester.pumpWidget(
        MyApp(repository: buildRepository(), notifications: notifications));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ElevatedButton, 'Game Results'));
    await tester.pumpAndSettle();
    unawaited(tester
        .element(find.text('Player 1 Score'))
        .pushNamed(RouteNames.result));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(find.text('Player 1 Score'), findsOneWidget);
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
