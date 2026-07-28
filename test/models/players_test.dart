// SPDX-License-Identifier: MIT

import 'package:scythe_companion/models/players.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('playerTimerSeconds — audit F1 regression', () {
    test('every playerTimers option converts to a positive duration', () {
      // The bug this replaces was a late-int if/else chain in create.dart:
      // an option present in the dropdown but missing from the chain left
      // the variable unassigned → LateInitializationError on Create.
      // Parsing the label means the two can never drift apart again.
      for (final label in playerTimers) {
        final seconds = playerTimerSeconds(label);
        expect(seconds, greaterThan(0), reason: '$label produced $seconds');
      }
    });

    test('known labels map to the documented values', () {
      expect(playerTimerSeconds('15:00'), 900);
      expect(playerTimerSeconds('20:00'), 1200);
      expect(playerTimerSeconds('25:00'), 1500);
      expect(playerTimerSeconds('30:00'), 1800);
    });

    test('a new option added to playerTimers needs no change here', () {
      // Proves the fragility is gone: labels that were never in the old
      // if/else chain still convert correctly.
      expect(playerTimerSeconds('45:00'), 2700);
      expect(playerTimerSeconds('05:30'), 330);
      expect(playerTimerSeconds('1:00'), 60);
    });

    test('malformed labels fall back instead of throwing', () {
      expect(playerTimerSeconds(''), 900);
      expect(playerTimerSeconds('20'), 900);
      expect(playerTimerSeconds('abc:def'), 900);
      expect(playerTimerSeconds('10:20:30'), 900);
      expect(playerTimerSeconds('bogus', fallback: 1200), 1200);
    });
  });
}
