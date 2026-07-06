// SPDX-License-Identifier: MIT

/// T3.2 seam tests: runtime server switching.
///
/// Covers the three moving parts the QR/settings flow depends on:
///  - SocketService.swapAdapter (transport + version-probe swap),
///  - GameRepository.saveSettings (persist + conditional apply),
///  - GameRepository.setServerUrl (normalize + persist + apply).
///
/// NOTE: repository-level tests assert on persistence and
/// `currentServerUrl` only — they never call `connect()` after a swap,
/// because `_applyServerUrl` builds a real `IoSocketAdapter`
/// (construction is network-free with autoConnect:false, connecting is
/// not).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:scythe_companion/data/game_repository.dart';
import 'package:scythe_companion/data/session_store.dart';
import 'package:scythe_companion/data/settings_repository.dart';
import 'package:scythe_companion/data/socket_service.dart';

import 'fake_socket_adapter.dart';

void main() {
  group('SocketService.swapAdapter', () {
    test('re-registers handlers on the new adapter and disposes the old one',
        () {
      final first = FakeSocketAdapter();
      final service = SocketService(adapter: first);
      expect(first.handlerCount('connect'), 1);

      final second = FakeSocketAdapter();
      service.swapAdapter(second);

      // New adapter got the full handler set (A10: registered once, at
      // the service level).
      expect(second.handlerCount('connect'), 1);
      expect(second.handlerCount('updateRoom'), 1);
      expect(second.handlerCount('errorOccurred'), 1);
      // Old adapter was disposed: its handlers are gone.
      expect(first.handlerCount('connect'), 0);

      service.dispose();
    });

    test('resets state to disconnected and connects via the new adapter',
        () async {
      final first = FakeSocketAdapter();
      final service = SocketService(adapter: first);
      await service.connect();
      expect(service.state, SocketConnectionState.connected);

      final second = FakeSocketAdapter();
      service.swapAdapter(second);
      expect(service.state, SocketConnectionState.disconnected);

      await service.connect();
      expect(second.connectCalls, 1);
      expect(service.state, SocketConnectionState.connected);

      service.dispose();
    });

    test('swaps the version probe so the NEW server is validated', () async {
      // Old server: compatible (v1). New server: incompatible (v99).
      final first = FakeSocketAdapter();
      final service = SocketService(
        adapter: first,
        versionProbe: () async => 1,
      );
      await service.connect();
      expect(service.state, SocketConnectionState.connected);

      final second = FakeSocketAdapter();
      service.swapAdapter(second, versionProbe: () async => 99);

      await service.connect();
      expect(service.state, SocketConnectionState.protocolMismatch);
      expect(second.connectCalls, 0); // hard-blocked before the socket opens

      service.dispose();
    });
  });

  group('GameRepository server URL persistence', () {
    late FakeSocketAdapter fake;
    late InMemorySettingsRepository settings;
    late GameRepository repository;

    setUp(() {
      fake = FakeSocketAdapter();
      settings = InMemorySettingsRepository();
      repository = GameRepository(
        socketService: SocketService(adapter: fake),
        sessionStore: InMemorySessionStore(),
        settingsRepository: settings,
        initialServerUrl: 'http://old-server:3000',
      );
    });

    tearDown(() => repository.dispose());

    test('setServerUrl normalizes, persists, and updates currentServerUrl',
        () async {
      final applied =
          await repository.setServerUrl('new-server:3000/'); // no scheme, has /
      expect(applied, 'http://new-server:3000');
      expect(repository.currentServerUrl, 'http://new-server:3000');
      final saved = await settings.load();
      expect(saved.serverUrl, 'http://new-server:3000');
    });

    test('saveSettings with a URL persists it and rebinds the adapter',
        () async {
      final applied = await repository.saveSettings(
        const AppSettings(serverUrl: 'http://friend:3000', nickname: 'Alice'),
      );
      expect(applied, 'http://friend:3000');
      expect(repository.currentServerUrl, 'http://friend:3000');
      final saved = await settings.load();
      expect(saved.serverUrl, 'http://friend:3000');
      expect(saved.nickname, 'Alice');
    });

    test('saveSettings with a blank URL keeps and persists the current one',
        () async {
      final applied = await repository.saveSettings(
        const AppSettings(serverUrl: '   ', nickname: 'Bob'),
      );
      expect(applied, 'http://old-server:3000');
      expect(repository.currentServerUrl, 'http://old-server:3000');
      final saved = await settings.load();
      // Persisted, so the next launch's main() restores the URL the
      // user was actually playing on.
      expect(saved.serverUrl, 'http://old-server:3000');
      expect(saved.nickname, 'Bob');
    });

    test('saveSettings with the SAME URL does not swap the adapter', () async {
      await repository.saveSettings(
        const AppSettings(serverUrl: 'http://old-server:3000'),
      );
      // The original fake is still the live adapter: its handlers were
      // never cleared by a dispose.
      expect(fake.handlerCount('connect'), 1);
    });
  });
}
