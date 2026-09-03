// SPDX-License-Identifier: MIT

import 'package:flutter_test/flutter_test.dart';
import 'package:scythe_companion/data/settings_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('SharedPrefsSettingsRepository', () {
    setUp(() {
      // SharedPreferences in-memory mock (the official test pattern).
      SharedPreferences.setMockInitialValues({});
    });

    test('load returns empty AppSettings on fresh install', () async {
      final repo = SharedPrefsSettingsRepository();
      final loaded = await repo.load();
      expect(loaded, const AppSettings());
      expect(loaded.serverUrl, isNull);
      expect(loaded.nickname, isNull);
      expect(loaded.notificationsEnabled, isTrue);
    });

    test('save → load round-trips url, nickname, and notifications', () async {
      final repo = SharedPrefsSettingsRepository();
      const written = AppSettings(
        serverUrl: 'http://192.168.1.50:3000',
        nickname: 'Alice',
        notificationsEnabled: false,
      );
      await repo.save(written);
      final loaded = await repo.load();
      expect(loaded, written);
    });

    test('save then re-save with one field null removes that key only',
        () async {
      final repo = SharedPrefsSettingsRepository();
      await repo.save(const AppSettings(
        serverUrl: 'http://x:3000',
        nickname: 'Bob',
      ));
      // Drop the nickname but keep the URL.
      await repo.save(const AppSettings(
        serverUrl: 'http://x:3000',
        nickname: null,
      ));
      final loaded = await repo.load();
      expect(loaded.serverUrl, 'http://x:3000');
      expect(loaded.nickname, isNull);
    });

    test('missing notifications key loads as enabled', () async {
      SharedPreferences.setMockInitialValues({
        'settings.serverUrl': 'http://x:3000',
      });
      final repo = SharedPrefsSettingsRepository();
      final loaded = await repo.load();
      expect(loaded.notificationsEnabled, isTrue);
      expect(loaded.serverUrl, 'http://x:3000');
    });

    test('empty-string fields are coerced to null on load', () async {
      // Belt-and-braces: if some other code path writes "" directly
      // (bypassing save()'s null-coercion), load() still treats it as
      // "not set" rather than crashing.
      SharedPreferences.setMockInitialValues({
        'settings.serverUrl': '',
        'settings.nickname': '',
      });
      final repo = SharedPrefsSettingsRepository();
      final loaded = await repo.load();
      expect(loaded, const AppSettings());
    });

    test('clear wipes both keys', () async {
      final repo = SharedPrefsSettingsRepository();
      await repo.save(const AppSettings(
        serverUrl: 'http://x:3000',
        nickname: 'Carol',
      ));
      await repo.clear();
      final loaded = await repo.load();
      expect(loaded, const AppSettings());
    });
  });

  group('InMemorySettingsRepository', () {
    test('starts empty by default', () async {
      final repo = InMemorySettingsRepository();
      expect(await repo.load(), const AppSettings());
    });

    test('save → load round-trips', () async {
      final repo = InMemorySettingsRepository();
      await repo.save(const AppSettings(nickname: 'Dee'));
      expect((await repo.load()).nickname, 'Dee');
    });

    test('clear resets to empty', () async {
      final repo = InMemorySettingsRepository(
        const AppSettings(serverUrl: 'http://x:3000'),
      );
      await repo.clear();
      expect(await repo.load(), const AppSettings());
    });
  });

  group('AppSettings value semantics', () {
    test('equality and hashCode', () {
      expect(
        const AppSettings(serverUrl: 'a', nickname: 'b'),
        const AppSettings(serverUrl: 'a', nickname: 'b'),
      );
      expect(
        const AppSettings(serverUrl: 'a', nickname: 'b').hashCode,
        const AppSettings(serverUrl: 'a', nickname: 'b').hashCode,
      );
      expect(
        const AppSettings(serverUrl: 'a', nickname: 'b'),
        isNot(const AppSettings(serverUrl: 'a', nickname: 'c')),
      );
    });

    test('copyWith replaces only the named field', () {
      const original = AppSettings(serverUrl: 'http://x', nickname: 'A');
      final updated = original.copyWith(nickname: 'B');
      expect(updated.serverUrl, 'http://x');
      expect(updated.nickname, 'B');
      expect(updated.notificationsEnabled, isTrue);
    });

    test('equality includes notificationsEnabled', () {
      expect(
        const AppSettings(notificationsEnabled: false),
        isNot(const AppSettings()),
      );
    });
  });
}
