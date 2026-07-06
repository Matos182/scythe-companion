// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:scythe_companion/data/game_repository.dart';
import 'package:scythe_companion/data/session_store.dart';
import 'package:scythe_companion/data/settings_repository.dart';
import 'package:scythe_companion/data/socket_service.dart';
import 'package:scythe_companion/provider/room_notifier.dart';
import 'package:scythe_companion/utils/qr_payload.dart';
import 'package:scythe_companion/widgets/waiting_lobby.dart';

import '../data/fake_socket_adapter.dart';
import '../data/socket_service_test.dart' show roomJson, playerJson;

/// Builds a repository wired to [fake] with an optional bound server URL,
/// mirroring the composition root in main.dart.
GameRepository _buildRepository(FakeSocketAdapter fake, {String? serverUrl}) {
  return GameRepository(
    socketService: SocketService(adapter: fake), // no probe: skip version check
    sessionStore: InMemorySessionStore(),
    settingsRepository: InMemorySettingsRepository(),
    initialServerUrl: serverUrl,
  );
}

Widget _lobbyUnderTest(GameRepository repository, RoomNotifier notifier) {
  return MaterialApp(
    home: MultiProvider(
      providers: [
        Provider<GameRepository>.value(value: repository),
        ChangeNotifierProvider<RoomNotifier>.value(value: notifier),
      ],
      child: const Scaffold(body: SingleChildScrollView(child: LobbyPage())),
    ),
  );
}

void main() {
  testWidgets('LobbyPage shows a QR encoding the join payload', (tester) async {
    final fake = FakeSocketAdapter();
    final repository =
        _buildRepository(fake, serverUrl: 'http://10.0.0.5:3000');
    addTearDown(repository.dispose);
    final notifier = RoomNotifier(repository);
    addTearDown(notifier.dispose);

    // Connect + create, then simulate the server's createRoomSuccess
    // carrying our room code (same choreography as socket_service_test).
    await repository.createRoom(
      nickname: 'Alice',
      faction: 'Crimea',
      mat: '1',
      timerSec: 900,
    );
    fake.serverEmit(
      'createRoomSuccess',
      roomJson(
        id: 'XY7ZQR',
        players: [
          playerJson(id: 'uuid-alice', nickname: 'Alice', socketID: 'socket-1'),
        ],
      ),
    );

    await tester.pumpWidget(_lobbyUnderTest(repository, notifier));
    await tester.pump(); // let the stream event reach the notifier
    await tester.pump(); // rebuild off notifyListeners

    // Exactly one QR widget, keyed with the expected scythe:// payload.
    // (qr_flutter keeps `data` private, so the widget carries the payload
    // in its ValueKey — see _buildQrSection in waiting_lobby.dart.)
    final expectedPayload = encodeJoin(const JoinPayload(
      server: 'http://10.0.0.5:3000',
      roomCode: 'XY7ZQR',
    ));
    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.byKey(ValueKey('qr:$expectedPayload')), findsOneWidget);

    // Sanity: the on-screen room code field carries the same code.
    expect(find.text('XY7ZQR'), findsWidgets);
  });

  testWidgets('LobbyPage omits the QR when no server URL is bound',
      (tester) async {
    final fake = FakeSocketAdapter();
    // No serverUrl — simulates a repository that was never told where
    // the server lives (defensive: main.dart always passes one).
    final repository = _buildRepository(fake);
    addTearDown(repository.dispose);
    final notifier = RoomNotifier(repository);
    addTearDown(notifier.dispose);

    await tester.pumpWidget(_lobbyUnderTest(repository, notifier));
    await tester.pump();

    // No room id + no server URL → no QR. The lobby still renders.
    expect(find.byType(QrImageView), findsNothing);
    expect(find.text('Waiting for Players...'), findsOneWidget);
  });
}
