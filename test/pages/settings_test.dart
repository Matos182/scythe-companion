// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:scythe_companion/data/game_repository.dart';
import 'package:scythe_companion/data/session_store.dart';
import 'package:scythe_companion/data/settings_repository.dart';
import 'package:scythe_companion/data/socket_service.dart';
import 'package:scythe_companion/pages/settings.dart';

import '../data/fake_socket_adapter.dart';

void main() {
  late GameRepository repository;

  setUp(() {
    repository = GameRepository(
      socketService: SocketService(adapter: FakeSocketAdapter()),
      sessionStore: InMemorySessionStore(),
      settingsRepository: InMemorySettingsRepository(),
    );
  });

  tearDown(() {
    repository.dispose();
  });

  testWidgets('Settings page boots, Save persists to the repository',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Provider<GameRepository>.value(
          value: repository,
          child: const SettingsPage(),
        ),
      ),
    );
    // First frame + the post-frame callback that loads the saved values.
    await tester.pumpAndSettle();

    // Default placeholder is visible when there's no saved value.
    expect(find.text('Server URL'), findsOneWidget);
    expect(find.text('Default nickname'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);

    // Type into both fields. The QR-aware widget tree is heavy and
    // pumpAndSettle is racy on the TextEditingController updates;
    // explicit enterText + pump is the recommended pattern.
    await tester.enterText(
        find.byType(TextField).at(0), 'http://10.0.0.5:3000');
    await tester.enterText(find.byType(TextField).at(1), 'Alice');
    await tester.pump();

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final saved = await repository.loadSettings();
    expect(saved.serverUrl, 'http://10.0.0.5:3000');
    expect(saved.nickname, 'Alice');
  });

  testWidgets('Settings page shows "Saved." feedback after save',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Provider<GameRepository>.value(
          value: repository,
          child: const SettingsPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byType(TextField).at(0), 'http://10.0.0.5:3000');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Saved.'), findsOneWidget);
  });

  testWidgets('Settings page pre-fills from existing saved values',
      (tester) async {
    await repository.saveSettings(const AppSettings(
      serverUrl: 'http://prefilled:3000',
      nickname: 'Bob',
    ));

    await tester.pumpWidget(
      MaterialApp(
        home: Provider<GameRepository>.value(
          value: repository,
          child: const SettingsPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final urlField = tester.widget<TextField>(find.byType(TextField).at(0));
    final nameField = tester.widget<TextField>(find.byType(TextField).at(1));
    expect(urlField.controller!.text, 'http://prefilled:3000');
    expect(nameField.controller!.text, 'Bob');
  });

  testWidgets('successful connection test normalizes, saves, and applies URL',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Provider<GameRepository>.value(
          value: repository,
          child: SettingsPage(
            versionProbe: (url) async {
              expect(url, 'https://scythe.guarita.site');
              return SocketService.expectedProtocolVersion;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField).at(0),
      'scythe.guarita.site',
    );
    await tester.enterText(find.byType(TextField).at(1), 'Unsaved nickname');

    await tester.tap(find.text('Test connection'));
    await tester.pumpAndSettle();

    expect(find.text('Server OK (protocol v1) — saved.'), findsOneWidget);
    expect(repository.currentServerUrl, 'https://scythe.guarita.site');
    final saved = await repository.loadSettings();
    expect(saved.serverUrl, 'https://scythe.guarita.site');
    expect(saved.nickname, isNull,
        reason: 'Testing the server must not save the nickname field');
  });

  testWidgets('Test connection shows an unreachable server', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Provider<GameRepository>.value(
          value: repository,
          child: SettingsPage(versionProbe: (_) async => null),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField).at(0),
      '192.168.1.50:3000',
    );

    await tester.tap(find.text('Test connection'));
    await tester.pumpAndSettle();

    expect(
      find.text('Server unreachable at http://192.168.1.50:3000'),
      findsOneWidget,
    );
    expect(repository.currentServerUrl, isNull);
    expect((await repository.loadSettings()).serverUrl, isNull);
  });

  testWidgets('Test connection shows a protocol mismatch', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Provider<GameRepository>.value(
          value: repository,
          child: SettingsPage(versionProbe: (_) async => 99),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Test connection'));
    await tester.pumpAndSettle();

    expect(
      find.text('Protocol mismatch: server v99, app expects v1'),
      findsOneWidget,
    );
    expect(repository.currentServerUrl, isNull);
    expect((await repository.loadSettings()).serverUrl, isNull);
  });
}
