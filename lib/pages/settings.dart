// SPDX-License-Identifier: MIT

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../data/game_repository.dart';
import '../data/server_config.dart';
import '../data/settings_repository.dart';
import '../data/socket_service.dart';
import '../models/route_const.dart';
import '../ui/backdrop.dart';
import '../ui/panel_card.dart';
import '../ui/theme.dart';
import '../utils/strings.dart';

/// Runtime server and nickname settings.
class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    this.versionProbe = healthzVersionProbe,
  });

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
  bool _notificationsEnabled = true;
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
      _notificationsEnabled = saved.notificationsEnabled;
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

    if (version == null) {
      setState(() {
        _testingConnection = false;
        _errorText = 'Server unreachable at $normalizedUrl';
      });
      return;
    }
    if (version != SocketService.expectedProtocolVersion) {
      setState(() {
        _testingConnection = false;
        _errorText = 'Protocol mismatch: server v$version, app expects '
            'v${SocketService.expectedProtocolVersion}';
      });
      return;
    }

    try {
      final savedUrl =
          await context.read<GameRepository>().setServerUrl(normalizedUrl);
      if (!mounted) return;
      _serverUrlController.text = savedUrl;
      setState(() {
        _testingConnection = false;
        _infoText = SettingsStrings.probeSaved(version!);
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _testingConnection = false;
        _errorText = 'Could not save server: $error';
      });
    }
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
          notificationsEnabled: _notificationsEnabled,
        ),
      );
      if (!mounted) return;
      setState(() => _infoText = 'Saved.');
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorText = 'Could not save: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _onNotificationsChanged(bool value) {
    setState(() => _notificationsEnabled = value);
    unawaited(_persistNotifications(value));
  }

  Future<void> _persistNotifications(bool value) async {
    try {
      await context.read<GameRepository>().setNotificationsEnabled(value);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _notificationsEnabled = !value;
        _errorText = 'Could not save: $error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadInitial());
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ScytheBackdrop(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: PanelCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Server URL',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  const Text(
                    'Where friends host the game. Leave blank to use the '
                    'build-time default. Examples: '
                    'http://192.168.1.50:3000 or https://play.example.com',
                    style: TextStyle(
                      color: ScytheColors.parchmentDim,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _serverUrlController,
                    decoration: const InputDecoration(
                      hintText: 'http://your-server:3000',
                    ),
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                    enableSuggestions: false,
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: _testingConnection ? null : _testConnection,
                    child: Text(
                      _testingConnection ? 'Testing…' : 'Test connection',
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text('Default nickname',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  const Text(
                    'Pre-fills the create/join page so you don\'t retype it '
                    'every game.',
                    style: TextStyle(
                      color: ScytheColors.parchmentDim,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _nicknameController,
                    decoration: const InputDecoration(hintText: 'Player name'),
                    keyboardType: TextInputType.text,
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              SettingsStrings.notificationsTitle,
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            SizedBox(height: 6),
                            Text(
                              SettingsStrings.notificationsSubtitle,
                              style: TextStyle(
                                color: ScytheColors.parchmentDim,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        key: const Key('settings-turn-alerts'),
                        value: _notificationsEnabled,
                        onChanged: _onNotificationsChanged,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  if (_errorText != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        _errorText!,
                        style: const TextStyle(color: ScytheColors.danger),
                      ),
                    ),
                  if (_infoText != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        _infoText!,
                        style: const TextStyle(color: ScytheColors.teslaGlow),
                      ),
                    ),
                  ElevatedButton(
                    onPressed: _saving ? null : _save,
                    child: Text(_saving ? 'Saving…' : 'Save'),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () => context.goNamed(RouteNames.about),
                    icon: const Icon(Icons.info_outline),
                    label: const Text(SettingsStrings.aboutTileTitle),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
