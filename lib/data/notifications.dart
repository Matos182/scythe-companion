// SPDX-License-Identifier: MIT

/// Local notification service wrapping `flutter_local_notifications` v19
/// (02_ARCHITECTURE "Notifications (fixes A9)").
///
/// The old app spawned a background isolate with its own socket — a phantom
/// connection that could never see UI-side room state. This service is much
/// simpler: the composition root fires [announceYourTurn] when `newTurn`
/// makes it this device's turn. Backgrounded phones always shout; the
/// Settings switch only mutes the on-screen buzz. A heads-up tray item
/// covers the case where the user is looking away. The in-page banner +
/// wakelock from T3.3 still run.
///
/// Design rules:
/// - Widgets never call this directly. The composition root in `main.dart`
///   owns the single instance and fires notifications from the guarded
///   listener (same pattern as navigation and error snackbars — A10 fix).
/// - The permission request happens on the home page (T3.4) so the user
///   sees it in context, not on a cold-boot splash.
/// - The plugin is a no-op on non-Android platforms (D6); `initialize`
///   is guarded by `Platform.isAndroid` so the method channel is never
///   touched in the Dart test VM. Haptic/system-sound still run there.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Thin wrapper so callers don't depend on the plugin singleton directly.
/// Tests can subclass and override [showYourTurn] without touching the
/// method channel.
class NotificationService {
  NotificationService({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  // T5.5: new channel id — Android ignores importance/sound/vibration
  // edits to an already-created channel, so v2 is required for heads-up.
  static const _channelId = 'scythe_turn_v2';
  static const _channelName = 'Turn Notifications';
  static const _channelDescription =
      'Notifies you when it is your turn in a Scythe multiplayer room.';
  static const _notificationId = 0;

  bool _initialized = false;

  /// Call once at startup (after `WidgetsFlutterBinding.ensureInitialized`).
  /// Safe to call multiple times — the second call is a no-op. Does nothing
  /// on non-Android platforms (D6); the plugin's method channel is not
  /// available in the Dart test VM, so this guard keeps widget tests green.
  Future<void> initialize() async {
    if (_initialized || !Platform.isAndroid) return;
    _initialized = true;

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );
  }

  /// Request the Android 13+ POST_NOTIFICATIONS runtime permission.
  /// On older Android or non-Android platforms this is a no-op (the plugin
  /// returns null/false). Returns `true` when the user granted permission.
  Future<bool> requestPermission() async {
    if (!Platform.isAndroid) return true;

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return false;

    final granted = await android.requestNotificationsPermission();
    return granted ?? false;
  }

  /// Phone-side "it's your turn" cue (T5.5). Always haptic + system
  /// alert; also posts a heads-up notification on Android so a Homed
  /// phone still shouts. Safe to call from the test VM — method-channel
  /// misses are swallowed.
  Future<void> announceYourTurn({String? nickname}) async {
    await _pulseDevice();
    await showYourTurn(nickname: nickname);
  }

  /// Show a "Your turn!" notification. Called by [announceYourTurn].
  Future<void> showYourTurn({String? nickname}) async {
    if (!_initialized) return;

    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      enableVibration: true,
      vibrationPattern: Int64List.fromList(const <int>[0, 180, 80, 180]),
      category: AndroidNotificationCategory.reminder,
      autoCancel: true,
      ticker: 'Your turn!',
      timeoutAfter: const Duration(seconds: 10).inMilliseconds,
    );
    final details = NotificationDetails(android: androidDetails);

    final title = nickname == null ? 'Your turn!' : 'Your turn, $nickname!';
    const body = 'Tap to return to the Scythe room.';

    await _plugin.show(_notificationId, title, body, details);
  }

  Future<void> _pulseDevice() async {
    try {
      await HapticFeedback.heavyImpact();
      await SystemSound.play(SystemSoundType.alert);
    } catch (_) {
      // Test VM and headless isolates have no haptic/sound channel.
    }
  }

  /// Cancel any active notification (e.g. when the user reopens the app
  /// and sees the banner — no need to keep the system tray entry).
  Future<void> cancel() async {
    if (!_initialized) return;
    await _plugin.cancel(_notificationId);
  }

  /// Notification-tap callback. For now this is a placeholder — the app
  /// is brought to the foreground by the system regardless. Deep-linking
  /// to a specific room is a T3.5 candidate.
  static void _onNotificationTapped(NotificationResponse response) {
    // Intentionally empty: the OS resumes the app's task, and the
    // composition root's rejoin logic handles the rest.
  }
}
