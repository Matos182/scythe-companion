// SPDX-License-Identifier: MIT

import 'package:flutter_test/flutter_test.dart';
import 'package:scythe_companion/utils/qr_payload.dart';

void main() {
  group('encodeJoin → decodeJoin round-trip', () {
    test('plain http://LAN:port round-trips intact', () {
      const original = JoinPayload(
        server: 'http://192.168.1.50:3000',
        roomCode: 'AB3KMN',
      );
      final encoded = encodeJoin(original);
      expect(encoded,
          'scythe://join?server=http%3A%2F%2F192.168.1.50%3A3000&room=AB3KMN');
      final decoded = decodeJoin(encoded);
      expect(decoded, original);
    });

    test('https URL round-trips intact', () {
      const original = JoinPayload(
        server: 'https://play.example.com',
        roomCode: 'XY7ZQR',
      );
      final encoded = encodeJoin(original);
      final decoded = decodeJoin(encoded);
      expect(decoded, original);
    });

    test('room code is uppercased on decode', () {
      const original = JoinPayload(
        server: 'http://localhost:3000',
        roomCode: 'ab3kmn',
      );
      final encoded = encodeJoin(original);
      // Encode preserves case (server is the only URL-encoded field);
      // decode normalises to upper to match RoomStore's alphabet.
      expect(encoded.contains('room=ab3kmn'), isTrue);
      final decoded = decodeJoin(encoded);
      expect(decoded?.roomCode, 'AB3KMN');
    });

    test('server value with reserved chars is encoded', () {
      const original = JoinPayload(
        server: 'http://x/?y=z&w=v',
        roomCode: 'AB3KMN',
      );
      final encoded = encodeJoin(original);
      // The reserved chars inside the server value must be
      // percent-encoded: exactly one literal '?' (the query separator)
      // and exactly one literal '&' (between server= and room=) survive.
      expect('?'.allMatches(encoded).length, 1);
      expect('&'.allMatches(encoded).length, 1);
      final decoded = decodeJoin(encoded);
      expect(decoded, original);
    });
  });

  group('decodeJoin — rejections', () {
    test('null when scheme is wrong (https)', () {
      expect(
        decodeJoin('https://join?server=http%3A%2F%2Fx&room=AB'),
        isNull,
      );
    });

    test('null when scheme is wrong (plain text)', () {
      expect(decodeJoin('hello world'), isNull);
    });

    test('null when host is not "join"', () {
      expect(
        decodeJoin('scythe://other?server=http%3A%2F%2Fx&room=AB'),
        isNull,
      );
    });

    test('null when server param missing', () {
      expect(
        decodeJoin('scythe://join?room=AB3KMN'),
        isNull,
      );
    });

    test('null when room param missing', () {
      expect(
        decodeJoin('scythe://join?server=http%3A%2F%2Fx'),
        isNull,
      );
    });

    test('null when both params are empty', () {
      expect(
        decodeJoin('scythe://join?server=&room='),
        isNull,
      );
    });

    test('null on garbage input', () {
      expect(decodeJoin(''), isNull);
      expect(decodeJoin(':::'), isNull);
      expect(decodeJoin('scythe://'), isNull);
    });
  });
}
