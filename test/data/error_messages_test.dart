// SPDX-License-Identifier: MIT

import 'package:flutter_test/flutter_test.dart';
import 'package:scythe_companion/data/error_messages.dart';
import 'package:scythe_companion/data/socket_service.dart';

void main() {
  group('humanizeError', () {
    test('returns a user-friendly message for every T2.4 code', () {
      // Every wire code from server/src/errors.js + the client-side
      // codes from socket_service.dart must have a non-empty message.
      // If a new code is added on the server side without an entry
      // here, the fallback would still show the raw server text —
      // this test is the safety net for the "centralized strings"
      // goal (AGENTS.md C6).
      const codes = <String>[
        // Validation
        'VAL_MISSING_NICKNAME',
        'VAL_MISSING_ROOM_ID',
        'VAL_MISSING_FIELDS',
        'VAL_INVALID_TIMER',
        'VAL_INVALID_FACTION',
        'VAL_INVALID_MAT',
        'VAL_BAD_PAYLOAD',
        // State
        'STATE_ROOM_NOT_FOUND',
        'STATE_GAME_IN_PROGRESS',
        'STATE_FACTION_OR_MAT_TAKEN',
        'STATE_SINGLE_PLAYER',
        'STATE_NOT_YOUR_TURN',
        'STATE_PASS_FAILED',
        // Rejoin
        'REJOIN_NOT_FOUND',
        // Rate
        'RATE_LIMITED',
        'RATE_MAX_CONNECTIONS',
        // Server capacity
        'SERVER_MAX_ROOMS',
        // Client-only
        'PROTOCOL_MISMATCH',
        'CLIENT_CONNECT_FAILED',
        'CLIENT_BAD_PAYLOAD',
        'UNKNOWN',
      ];
      for (final code in codes) {
        final msg = humanizeError(SocketError(code: code, message: 'raw'));
        expect(msg, isNotEmpty, reason: 'no message for $code');
        expect(msg, isNot(equals('raw')),
            reason: '$code fell through to the raw server message');
      }
    });

    test('connect failure copy includes its server URL and next action', () {
      const error = SocketError(
        code: 'CLIENT_CONNECT_FAILED',
        message: 'https://scythe.guarita.site',
      );

      final message = humanizeError(error);

      expect(message, contains('https://scythe.guarita.site'));
      expect(message, contains('Settings → Test connection'));
    });

    test('falls back to the server-supplied message for unknown codes', () {
      // A future code we haven't catalogued should still surface —
      // better a developer-y sentence than a silent error.
      const error =
          SocketError(code: 'NEW_FUTURE_CODE', message: 'future copy');
      expect(humanizeError(error), 'future copy');
    });

    test('falls back to a generic message when both code and message are empty',
        () {
      const error = SocketError(code: 'NEW_FUTURE_CODE', message: '');
      final out = humanizeError(error);
      expect(out, isNotEmpty);
      // Must not be the raw empty string.
      expect(out, isNot(equals('')));
    });

    test('every message is written for a human, not a developer', () {
      // Cheap heuristic: none of our strings should contain a colon —
      // that's the developer-flavoured "code: description" pattern
      // we're explicitly replacing. (Snackbar widths are tight on
      // phones, so message length matters too.)
      const codes = <String>[
        'VAL_MISSING_NICKNAME',
        'STATE_ROOM_NOT_FOUND',
        'RATE_LIMITED',
        'SERVER_MAX_ROOMS',
        'PROTOCOL_MISMATCH',
      ];
      for (final code in codes) {
        final msg = humanizeError(SocketError(code: code, message: 'raw'));
        expect(msg, isNot(contains(':')),
            reason: '$code message still looks developer-y: "$msg"');
        expect(msg.length, lessThan(160),
            reason: '$code message is too long for a snackbar');
      }
    });
  });
}
