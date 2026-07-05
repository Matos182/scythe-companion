// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scythe_companion/widgets/score_form.dart';

void main() {
  group('ScoreForm widget validation', () {
    late List<TextEditingController> controllers;
    late GlobalKey<FormState> formKey;

    setUp(() {
      controllers = List.generate(7, (_) => TextEditingController());
      formKey = GlobalKey<FormState>();
    });

    tearDown(() {
      for (final c in controllers) {
        c.dispose();
      }
    });

    /// Helper: pump the form, fill [fieldIndex] with [text] and all other
    /// fields with valid defaults, validate, and return whether the form
    /// is valid. Since Form.validate() checks ALL fields, we must fill
    /// all fields with valid values before testing one field's invalid input.
    Future<bool> validateField(
      WidgetTester tester,
      int fieldIndex,
      String text,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Form(
              key: formKey,
              child: ScoreForm(controllers: controllers),
            ),
          ),
        ),
      );

      // Fill all fields with valid defaults
      final defaults = ['Alice', '10', '5', '8', '10', '0', '0'];
      for (var i = 0; i < 7; i++) {
        await tester.enterText(find.byType(TextFormField).at(i), defaults[i]);
      }
      // Override the target field
      await tester.enterText(find.byType(TextFormField).at(fieldIndex), text);
      await tester.pumpAndSettle();

      return formKey.currentState!.validate();
    }

    testWidgets('empty player name is invalid', (tester) async {
      final valid = await validateField(tester, 0, '');
      expect(valid, isFalse);
    });

    testWidgets('whitespace-only player name is invalid', (tester) async {
      final valid = await validateField(tester, 0, '   ');
      expect(valid, isFalse);
    });

    testWidgets('popularity > 18 is invalid', (tester) async {
      final valid = await validateField(tester, 1, '19');
      expect(valid, isFalse);
    });

    testWidgets('negative stars is invalid', (tester) async {
      final valid = await validateField(tester, 2, '-5');
      expect(valid, isFalse);
    });

    testWidgets('non-numeric input is invalid', (tester) async {
      final valid = await validateField(tester, 3, 'abc');
      expect(valid, isFalse);
    });

    testWidgets('valid player name is accepted', (tester) async {
      final valid = await validateField(tester, 0, 'Bob');
      expect(valid, isTrue);
    });

    testWidgets('popularity 0 is valid boundary', (tester) async {
      final valid = await validateField(tester, 1, '0');
      expect(valid, isTrue);
    });

    testWidgets('popularity 18 is valid boundary', (tester) async {
      final valid = await validateField(tester, 1, '18');
      expect(valid, isTrue);
    });

    testWidgets('zero is valid for numeric fields', (tester) async {
      final valid = await validateField(tester, 4, '0');
      expect(valid, isTrue);
    });

    testWidgets('all valid fields pass', (tester) async {
      // Test with the defaults themselves — should be valid
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Form(
              key: formKey,
              child: ScoreForm(controllers: controllers),
            ),
          ),
        ),
      );

      final defaults = ['Alice', '10', '5', '8', '10', '0', '0'];
      for (var i = 0; i < 7; i++) {
        await tester.enterText(find.byType(TextFormField).at(i), defaults[i]);
      }
      await tester.pumpAndSettle();

      expect(formKey.currentState!.validate(), isTrue);
    });
  });
}
