// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scythe_companion/utils/strings.dart';
import 'package:scythe_companion/widgets/connection_pill.dart';

void main() {
  group('ConnectionPill', () {
    testWidgets('shows the default connecting label', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: ConnectionPill())),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text(ConnectionStrings.connectingPill), findsOneWidget);
    });

    testWidgets('honors a caller-provided label', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ConnectionPill(label: 'Custom label')),
        ),
      );

      expect(find.text('Custom label'), findsOneWidget);
      expect(find.text(ConnectionStrings.connectingPill), findsNothing);
    });
  });
}
