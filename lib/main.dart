// SPDX-License-Identifier: MIT

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import './data/game_repository.dart';
import './data/notifications.dart';
import './data/server_config.dart';
import './data/session_store.dart';
import './data/settings_repository.dart';
import './data/socket_adapter.dart';
import './data/socket_service.dart';
import './models/route_config.dart';
import './models/route_const.dart';
import './provider/room_data_provider.dart';
import './provider/room_notifier.dart';

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
  // T3.4: initialize the local notification plugin before the first
  // frame. No-op on non-Android platforms (D6); the plugin's method
  // channel is not available in the Dart test VM so the guard inside
  // NotificationService.initialize keeps widget tests green.
  final notifications = NotificationService();
  await notifications.initialize();
  runApp(MyApp(repository: repository, notifications: notifications));
}

class MyApp extends StatefulWidget {
  const MyApp({
    super.key,
    required this.repository,
    required this.notifications,
  });

  final GameRepository repository;
  final NotificationService notifications;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  final _router = MyRouter();
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();
  late final RoomNotifier _roomNotifier;
  late final NotificationService _notifications;

  /// T3.4: true when the app is not in the foreground (inactive or
  /// hidden). The foreground listener skips the notification when the
  /// user is already looking at the in-page banner + wakelock path.
  bool _appIsBackgrounded = false;

  /// One-shot context for the boot-time `rejoinSavedSession` (T3.3
  /// hand-off debt 5b). The repository silently attempts to resume a
  /// stored session; if it succeeds, we show "Rejoined room XYZ" instead
  /// of leaving the user to figure out why they're suddenly in an old
  /// game. Cleared the moment the joined-flag fires so a subsequent
  /// fresh join is unaffected.
  String? _pendingRejoinRoomCode;

  @override
  void initState() {
    super.initState();
    _roomNotifier = RoomNotifier(widget.repository);
    _notifications = widget.notifications;
    WidgetsBinding.instance.addObserver(this);
    // THE single guarded listener (audit A10): all navigation-from-socket
    // and error snackbars happen here — never inside socket callbacks
    // with a captured page context.
    _roomNotifier.addListener(_onRoomEvent);
    // T3.3: silent auto-resume of a saved session. If the user has no
    // session, this is a no-op. If rejoinRoom gets rejected by the
    // server (stale playerId, dead room), the server emits errorOccurred
    // which surfaces in the normal error-snackbar path — the user can
    // pick a different action from the home menu.
    unawaited(_attemptBootRejoin());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // T3.4: track whether the app is backgrounded. We treat both
    // `inactive` (e.g. phone ringing, split-screen) and `hidden` as
    // "backgrounded" — the notification is useful whenever the user
    // isn't actively looking at the game screen. `paused` and `detached`
    // are also backgrounded but the socket may not receive events in
    // those states on all platforms. `resumed` clears the flag.
    _appIsBackgrounded = state != AppLifecycleState.resumed;
  }

  Future<void> _attemptBootRejoin() async {
    try {
      final resumed = await widget.repository.rejoinSavedSession();
      if (!resumed) return;
      // Stash a "we're in a boot rejoin" marker; the listener
      // resolves it once the joined-flag fires.
      final session = await widget.repository.sessionStore.load();
      _pendingRejoinRoomCode = session?.roomCode;
    } catch (_) {
      // Defensive: never let a failed boot-rejoin block the UI.
    }
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
      // T3.3: if this joined event is the boot-time rejoin completing,
      // confirm it to the user. The code is best-effort — null just
      // means a generic rejoin.
      final bootCode = _pendingRejoinRoomCode;
      if (bootCode != null) {
        _pendingRejoinRoomCode = null;
        _messengerKey.currentState?.showSnackBar(
          SnackBar(content: Text('Rejoined room $bootCode')),
        );
      }
    }

    // T3.4: fire a local notification when a newTurn transition makes
    // it my turn while the app is backgrounded. The foreground path is
    // already covered by the in-page banner + wakelock (T3.3).
    if (_roomNotifier.consumeJustBecameMyTurnFlag() && _appIsBackgrounded) {
      final nickname = _roomNotifier.room.turn.nickname;
      unawaited(_notifications.showYourTurn(nickname: nickname));
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
    WidgetsBinding.instance.removeObserver(this);
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
          // T3.4: notification service for the home page permission prompt.
          Provider<NotificationService>.value(value: _notifications),
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
