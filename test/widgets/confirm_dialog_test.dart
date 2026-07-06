// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scythe_companion/utils/strings.dart';
import 'package:scythe_companion/widgets/confirm_dialog.dart';

void main() {
  group('confirmLeave', () {
    testWidgets('returns true when the user taps the confirm action',
        (tester) async {
      bool? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () async {
                    result = await confirmLeave(
                      context,
                      title: LeaveDialogStrings.gameTitle,
                      message: LeaveDialogStrings.gameMessage,
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // Dialog is up.
      expect(find.text(LeaveDialogStrings.gameTitle), findsOneWidget);
      expect(find.text(LeaveDialogStrings.gameMessage), findsOneWidget);

      // Tap confirm.
      await tester.tap(find.text(LeaveDialogStrings.confirmLabel));
      await tester.pumpAndSettle();

      expect(result, isTrue);
    });

    testWidgets('returns false when the user taps cancel', (tester) async {
      bool? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () async {
                    result = await confirmLeave(
                      context,
                      title: LeaveDialogStrings.gameTitle,
                      message: LeaveDialogStrings.gameMessage,
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text(LeaveDialogStrings.cancelLabel));
      await tester.pumpAndSettle();

      expect(result, isFalse);
    });

    testWidgets('returns false when the dialog is dismissed via barrier',
        (tester) async {
      bool? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () async {
                    result = await confirmLeave(
                      context,
                      title: LeaveDialogStrings.gameTitle,
                      message: LeaveDialogStrings.gameMessage,
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // Tap outside the dialog (barrier dismiss).
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();

      expect(result, isFalse);
    });
  });
}
