// SPDX-License-Identifier: MIT

// Smoke test: the app boots to the home menu and renders the four entry
// buttons. Replaces the dead Flutter counter-template scaffold (audit A15)
// that could never pass against the real MyApp — there is no counter and
// no `+` icon in this app.
//
// This is the minimum bar that lets CI's `flutter test` go green. T3.1
// extends this into a richer boot test that wires a FakeSocketAdapter
// through the new SocketService; this version stays dependency-free so it
// works on master as-is and survives every Phase 3 refactor.

import 'package:flutter_test/flutter_test.dart';
import 'package:scythe_companion/main.dart';

void main() {
  testWidgets('App boots to the home menu', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.text('Scythe Companion'), findsOneWidget);
    expect(find.text('Simple Convert'), findsOneWidget);
    expect(find.text('Game Results'), findsOneWidget);
    expect(find.text('Create Room'), findsOneWidget);
    expect(find.text('Join Room'), findsOneWidget);
  });
}
