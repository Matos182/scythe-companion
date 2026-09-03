// SPDX-License-Identifier: MIT

/// Persists user-tunable app settings: the socket.io server URL the
/// client points at and the default nickname pre-filled on create/join.
///
/// Replaces the compile-time `ServerConfig.serverUrl`
/// (`String.fromEnvironment('SCYTHE_SERVER_URL')`, audit A11). Until
/// this lands the only ways to point a built APK at a server were
/// (a) `--dart-define` at build time, or (b) the gitignored
/// `lib/env/env.dart` which broke the repo after a fresh clone.
///
/// Backend is `shared_preferences` (D4) — same store as the multiplayer
/// `SessionStore`, but a different key namespace (`settings.*`) so the
/// two never collide and a "leave session" doesn't wipe the user's
/// configured URL.
library;

import 'package:shared_preferences/shared_preferences.dart';

/// Immutable snapshot of the user's persisted settings.
///
/// `serverUrl` is non-null when the user has explicitly chosen a server
/// (typed it in Settings, scanned a QR, or the very first launch's
/// default kicked in). Callers should treat null as "use the build-time
/// default" and never pass null into the socket adapter.
///
/// `notificationsEnabled` defaults to true so existing installs keep
/// the T5.5 your-turn cue until the user turns it off in Settings.
class AppSettings {
  const AppSettings({
    this.serverUrl,
    this.nickname,
    this.notificationsEnabled = true,
  });

  final String? serverUrl;
  final String? nickname;
  final bool notificationsEnabled;

  AppSettings copyWith({
    String? serverUrl,
    String? nickname,
    bool? notificationsEnabled,
  }) =>
      AppSettings(
        serverUrl: serverUrl ?? this.serverUrl,
        nickname: nickname ?? this.nickname,
        notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      );

  @override
  bool operator ==(Object other) =>
      other is AppSettings &&
      other.serverUrl == serverUrl &&
      other.nickname == nickname &&
      other.notificationsEnabled == notificationsEnabled;

  @override
  int get hashCode => Object.hash(serverUrl, nickname, notificationsEnabled);

  @override
  String toString() =>
      'AppSettings(serverUrl: $serverUrl, nickname: $nickname, '
      'notificationsEnabled: $notificationsEnabled)';
}

abstract class SettingsRepository {
  Future<AppSettings> load();
  Future<void> save(AppSettings settings);
  Future<void> clear();
}

/// Production store backed by `shared_preferences` (D4).
///
/// Keys live under the `settings.` prefix to avoid collision with the
/// multiplayer session keys (`session.*`, see `session_store.dart`).
class SharedPrefsSettingsRepository implements SettingsRepository {
  static const _serverUrlKey = 'settings.serverUrl';
  static const _nicknameKey = 'settings.nickname';
  static const _notificationsKey = 'settings.notificationsEnabled';

  @override
  Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final url = prefs.getString(_serverUrlKey);
    final nickname = prefs.getString(_nicknameKey);
    // Missing key = leave the T5.5 default on. Only an explicit false
    // (or true) written by Settings should change it.
    final notificationsEnabled = prefs.getBool(_notificationsKey) ?? true;
    return AppSettings(
      serverUrl: (url == null || url.isEmpty) ? null : url,
      nickname: (nickname == null || nickname.isEmpty) ? null : nickname,
      notificationsEnabled: notificationsEnabled,
    );
  }

  @override
  Future<void> save(AppSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    if (settings.serverUrl == null) {
      await prefs.remove(_serverUrlKey);
    } else {
      await prefs.setString(_serverUrlKey, settings.serverUrl!);
    }
    if (settings.nickname == null) {
      await prefs.remove(_nicknameKey);
    } else {
      await prefs.setString(_nicknameKey, settings.nickname!);
    }
    await prefs.setBool(_notificationsKey, settings.notificationsEnabled);
  }

  @override
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_serverUrlKey);
    await prefs.remove(_nicknameKey);
    await prefs.remove(_notificationsKey);
  }
}

/// In-memory store for unit tests and for the first-frame render path
/// (before `SharedPreferences.getInstance()` resolves).
class InMemorySettingsRepository implements SettingsRepository {
  AppSettings _settings;

  InMemorySettingsRepository([this._settings = const AppSettings()]);

  @override
  Future<AppSettings> load() async => _settings;

  @override
  Future<void> save(AppSettings settings) async => _settings = settings;

  @override
  Future<void> clear() async => _settings = const AppSettings();
}
