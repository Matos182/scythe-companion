// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import './data/game_repository.dart';
import './data/server_config.dart';
import './data/session_store.dart';
import './data/settings_repository.dart';
import './data/socket_adapter.dart';
import './data/socket_service.dart';
import './models/route_config.dart';
import './models/route_const.dart';
import './provider/room_data_provider.dart';
import './provider/room_notifier.dart';

// TODO[T3.4]: initialize flutter_local_notifications here (channel setup,
// Android 13+ POST_NOTIFICATIONS permission flow). The old awesome_notifications
// setup + background service were removed in T0.4 — full replacement lands in T3.4.

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Composition root: the socket/session wiring is built ONCE here and
  // handed down — widgets never construct services (02_ARCHITECTURE).
  //
  // Server URL resolution order (T3.2):
  //   1. shared_preferences `settings.serverUrl` (Settings page / QR scan
  //      persisted it on a previous run);
  //   2. compile-time `ServerConfig.serverUrl`
  //      (`--dart-define=SCYTHE_SERVER_URL=…` or the localhost fallback).
  // The await is a one-time platform-channel read (~ms) before the first
  // frame — same pattern the Flutter docs use for startup config.
  final settingsRepository = SharedPrefsSettingsRepository();
  final settings = await settingsRepository.load();
  final initialUrl = settings.serverUrl ?? ServerConfig.serverUrl;
  final socketService = SocketService(
    adapter: IoSocketAdapter(initialUrl),
    versionProbe: () => healthzVersionProbe(initialUrl),
  );
  final repository = GameRepository(
    socketService: socketService,
    sessionStore: SharedPrefsSessionStore(),
    settingsRepository: settingsRepository,
    initialServerUrl: initialUrl,
  );
  runApp(MyApp(repository: repository));
}

class MyApp extends StatefulWidget {
  const MyApp({super.key, required this.repository});

  final GameRepository repository;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _router = MyRouter();
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();
  late final RoomNotifier _roomNotifier;

  @override
  void initState() {
    super.initState();
    _roomNotifier = RoomNotifier(widget.repository);
    // THE single guarded listener (audit A10): all navigation-from-socket
    // and error snackbars happen here — never inside socket callbacks
    // with a captured page context.
    _roomNotifier.addListener(_onRoomEvent);
  }

  void _onRoomEvent() {
    if (!mounted) return;

    if (_roomNotifier.consumeJoinedFlag()) {
      final location =
          _router.router.routerDelegate.currentConfiguration.uri.path;
      // Rejoin success while already on the game screen must not
      // re-navigate (the old client double-navigated, A10).
      if (location != '/game') {
        _router.router.goNamed(RouteNames.game);
      }
    }

    final error = _roomNotifier.lastError;
    if (error != null) {
      _roomNotifier.clearError();
      _messengerKey.currentState?.showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    }
  }

  @override
  void dispose() {
    _roomNotifier.removeListener(_onRoomEvent);
    _roomNotifier.dispose();
    widget.repository.dispose();
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
        providers: [
          // The repository itself (T3.2): pages read it for settings,
          // nickname pre-fill, server URL (QR), and adapter swaps.
          Provider<GameRepository>.value(value: widget.repository),
          // Multiplayer state (T3.1).
          ChangeNotifierProvider.value(value: _roomNotifier),
          // Offline calculator state (score entries).
          ChangeNotifierProvider(create: (_) => RoomDataProvider()),
        ],
        child: MaterialApp.router(
          title: 'Scythe Companion',
          scaffoldMessengerKey: _messengerKey,
          routerConfig: _router.router,
        ));
  }
}
