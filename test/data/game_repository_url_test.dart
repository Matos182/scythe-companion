// SPDX-License-Identifier: MIT

import 'package:flutter_test/flutter_test.dart';
import 'package:scythe_companion/data/game_repository.dart';

void main() {
  group('GameRepository.normalizeServerUrl', () {
    test('defaults a bare domain to HTTPS', () {
      expect(
        GameRepository.normalizeServerUrl('scythe.guarita.site'),
        'https://scythe.guarita.site',
      );
    });

    test('defaults an IPv4 literal to HTTP', () {
      expect(
        GameRepository.normalizeServerUrl('192.168.1.50:3000'),
        'http://192.168.1.50:3000',
      );
    });

    test('defaults localhost to HTTP', () {
      expect(
        GameRepository.normalizeServerUrl('localhost:3000'),
        'http://localhost:3000',
      );
    });

    test('defaults a dot-local host to HTTP', () {
      expect(
        GameRepository.normalizeServerUrl('scythe-box.local:3000'),
        'http://scythe-box.local:3000',
      );
    });

    test('preserves an explicit HTTP scheme', () {
      expect(
        GameRepository.normalizeServerUrl('http://play.example.com'),
        'http://play.example.com',
      );
    });

    test('preserves an explicit HTTPS scheme', () {
      expect(
        GameRepository.normalizeServerUrl('https://play.example.com'),
        'https://play.example.com',
      );
    });

    test('strips surrounding whitespace and a trailing slash', () {
      expect(
        GameRepository.normalizeServerUrl('  https://play.example.com/  '),
        'https://play.example.com',
      );
    });

    test('returns null for blank input', () {
      expect(GameRepository.normalizeServerUrl('   '), isNull);
    });
  });
}
