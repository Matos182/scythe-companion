// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/game_repository.dart';
import '../data/server_config.dart';
import '../data/settings_repository.dart';
import '../data/socket_service.dart';
import '../utils/colors.dart';

/// User-facing settings (T3.2). One server URL field + one nickname
/// field, both persisted to `shared_preferences` (D4) and read on
/// subsequent launches.
///
/// Lives at `/settings`, reachable from the home AppBar's gear icon so
/// a player can re-point the app at a friend's LAN server without
/// rebuilding the APK (audit A11).
class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    this.versionProbe = healthzVersionProbe,
  });

  /// Injectable so widget tests never make a network request.
  final Future<int?> Function(String serverUrl) versionProbe;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _serverUrlController = TextEditingController();
  final _nicknameController = TextEditingController();
  bool _loaded = false;
  bool _saving = false;
  bool _testingConnection = false;
  String? _errorText;
  String? _infoText;

  @override
  void dispose() {
    _serverUrlController.dispose();
    _nicknameController.dispose();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    final repository = context.read<GameRepository>();
    final saved = await repository.loadSettings();
    final initial = saved.serverUrl ?? ServerConfig.serverUrl;
    if (!_loaded && mounted) {
      _serverUrlController.text = initial;
      _nicknameController.text = saved.nickname ?? '';
      setState(() => _loaded = true);
    }
  }

  Future<void> _testConnection() async {
    if (_testingConnection) return;
    final normalizedUrl =
        GameRepository.normalizeServerUrl(_serverUrlController.text) ??
            GameRepository.normalizeServerUrl(ServerConfig.serverUrl)!;
    setState(() {
      _testingConnection = true;
      _errorText = null;
      _infoText = null;
    });

    int? version;
    try {
      version = await widget.versionProbe(normalizedUrl);
    } catch (_) {
      version = null;
    }
    if (!mounted) return;

    setState(() {
      _testingConnection = false;
      if (version == null) {
        _errorText = 'Server unreachable at $normalizedUrl';
      } else if (version != SocketService.expectedProtocolVersion) {
        _errorText = 'Protocol mismatch: server v$version, app expects '
            'v${SocketService.expectedProtocolVersion}';
      } else {
        _infoText = 'Server OK (protocol v$version)';
      }
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _errorText = null;
      _infoText = null;
    });
    final repository = context.read<GameRepository>();
    final url = _serverUrlController.text;
    final nickname = _nicknameController.text;
    try {
      await repository.saveSettings(
        AppSettings(
          serverUrl: url.isEmpty ? null : url,
          nickname: nickname.isEmpty ? null : nickname,
        ),
      );
      if (!mounted) return;
      setState(() => _infoText = 'Saved.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorText = 'Could not save: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Load saved values exactly once after the first build — pre-pump
    // the controllers with the persisted nickname + URL.
    if (!_loaded) {
      // Defer to the next frame so we can use context.read safely.
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadInitial());
    }

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColorBar,
        title: const Text(
          'Settings',
          style: TextStyle(color: buttonTextColor),
        ),
        centerTitle: true,
      ),
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/background.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Server URL',
                  style: TextStyle(
                    color: buttonTextColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Where friends host the game. Leave blank to use the '
                  'build-time default. Examples: '
                  'http://192.168.1.50:3000 or https://play.example.com',
                  style: TextStyle(color: buttonTextColor, fontSize: 12),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _serverUrlController,
                  style: const TextStyle(color: buttonTextColor),
                  decoration: const InputDecoration(
                    hintText: 'http://your-server:3000',
                    hintStyle: TextStyle(color: buttonTextColor),
                    filled: true,
                    fillColor: bgColorBar,
                  ),
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                  enableSuggestions: false,
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: _testingConnection ? null : _testConnection,
                  style: const ButtonStyle(
                    elevation: WidgetStatePropertyAll(7),
                    backgroundColor: WidgetStatePropertyAll(bgColorBar),
                    foregroundColor: WidgetStatePropertyAll(buttonTextColor),
                    fixedSize: WidgetStatePropertyAll(Size(150, 50)),
                  ),
                  child: Text(
                    _testingConnection ? 'Testing…' : 'Test connection',
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Default nickname',
                  style: TextStyle(
                    color: buttonTextColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Pre-fills the create/join page so you don\'t retype it '
                  'every game.',
                  style: TextStyle(color: buttonTextColor, fontSize: 12),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _nicknameController,
                  style: const TextStyle(color: buttonTextColor),
                  decoration: const InputDecoration(
                    hintText: 'Player name',
                    hintStyle: TextStyle(color: buttonTextColor),
                    filled: true,
                    fillColor: bgColorBar,
                  ),
                  keyboardType: TextInputType.text,
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 24),
                if (_errorText != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      _errorText!,
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  ),
                if (_infoText != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      _infoText!,
                      style: const TextStyle(color: Colors.greenAccent),
                    ),
                  ),
                ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: const ButtonStyle(
                    elevation: WidgetStatePropertyAll(7),
                    backgroundColor: WidgetStatePropertyAll(bgColorBar),
                    foregroundColor: WidgetStatePropertyAll(buttonTextColor),
                    fixedSize: WidgetStatePropertyAll(Size(150, 50)),
                  ),
                  child: Text(_saving ? 'Saving…' : 'Save'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
