// SPDX-License-Identifier: MIT

// Smoke test: the app boots with a fake socket and shows the home menu.
// Replaces the counter-template test (audit A15) that could never pass.

import 'package:flutter_test/flutter_test.dart';
import 'package:scythe_companion/data/game_repository.dart';
import 'package:scythe_companion/data/session_store.dart';
import 'package:scythe_companion/data/socket_service.dart';
import 'package:scythe_companion/main.dart';

import 'data/fake_socket_adapter.dart';

void main() {
  testWidgets('App boots to the home menu', (WidgetTester tester) async {
    final repository = GameRepository(
      socketService: SocketService(adapter: FakeSocketAdapter()),
      sessionStore: InMemorySessionStore(),
    );

    await tester.pumpWidget(MyApp(repository: repository));

    expect(find.text('Scythe Companion'), findsOneWidget);
    expect(find.text('Create Room'), findsOneWidget);
    expect(find.text('Join Room'), findsOneWidget);
    expect(find.text('Simple Convert'), findsOneWidget);
    expect(find.text('Game Results'), findsOneWidget);
  });
}
