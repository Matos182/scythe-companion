// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../data/game_repository.dart';
import '../data/socket_service.dart';
import '../models/players.dart';
import '../provider/room_notifier.dart';
import '../ui/backdrop.dart';
import '../ui/panel_card.dart';
import '../utils/qr_payload.dart';
import '../utils/strings.dart';
import '../widgets/connection_pill.dart';
import '../widgets/scrollable_center_column.dart';
import 'qr_scanner.dart';

class JoinRoom extends StatefulWidget {
  const JoinRoom({super.key});

  @override
  State<JoinRoom> createState() => _JoinRoomState();
}

class _JoinRoomState extends State<JoinRoom> {
  final _playerName = TextEditingController();
  final _roomId = TextEditingController();
  String _selectedPlayerFaction = 'Crimea';
  String _selectedPlayerMat = '1';
  bool _nicknameLoaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_nicknameLoaded) return;
    _nicknameLoaded = true;
    final repository = context.read<GameRepository>();
    repository.loadNickname().then((saved) {
      if (!mounted || saved == null || saved.isEmpty) return;
      if (_playerName.text.isEmpty) {
        setState(() => _playerName.text = saved);
      }
    });
  }

  @override
  void dispose() {
    _playerName.dispose();
    _roomId.dispose();
    super.dispose();
  }

  Future<void> _scanQr() async {
    final payload = await Navigator.of(context).push<JoinPayload>(
      MaterialPageRoute(builder: (_) => const QrScannerPage()),
    );
    if (!mounted || payload == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final repository = context.read<GameRepository>();
    await repository.setServerUrl(payload.server);
    setState(() => _roomId.text = payload.roomCode);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          '${QrScannerStrings.scannedPrefix} ${payload.roomCode} '
          '${QrScannerStrings.scannedOnSuffix} ${payload.server}',
        ),
      ),
    );
  }

  void _onJoinPressed() {
    final nickname = _playerName.text.trim();
    if (nickname.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(ValidationStrings.nicknameRequiredJoin)),
      );
      return;
    }
    final roomCode = _roomId.text.trim().toUpperCase();
    if (roomCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(ValidationStrings.roomCodeRequired)),
      );
      return;
    }
    context.read<RoomNotifier>().joinRoom(
          nickname: nickname,
          roomCode: roomCode,
          faction: _selectedPlayerFaction,
          mat: _selectedPlayerMat,
        );
  }

  @override
  Widget build(BuildContext context) {
    final connectionState = context.watch<RoomNotifier>().connectionState;
    final isConnecting = connectionState == SocketConnectionState.connecting;
    final isRetrying = connectionState == SocketConnectionState.reconnecting;
    final serverUrl = context.read<GameRepository>().currentServerUrl;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Join Room'),
        actions: [
          IconButton(
            icon: const Icon(Icons.home_rounded),
            tooltip: 'Home',
            onPressed: () => context.go('/'),
          ),
        ],
      ),
      body: ScytheBackdrop(
        child: ScrollableCenterColumn(
          padding: const EdgeInsets.all(16),
          children: [
            PanelCard(
              child: Column(
                children: <Widget>[
                  ConnectionPillSlot(
                    visible: isConnecting || isRetrying,
                    label: isRetrying ? ConnectionStrings.retryingPill : null,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _playerName,
                    decoration: const InputDecoration(
                      hintText: 'Insert Player Name',
                    ),
                    keyboardType: TextInputType.text,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _roomId,
                    decoration: const InputDecoration(
                      hintText: 'Insert Room ID',
                    ),
                    keyboardType: TextInputType.text,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      helperText: 'Player Faction',
                    ),
                    initialValue: _selectedPlayerFaction,
                    items: playerFactions
                        .map((item) => DropdownMenuItem<String>(
                              value: item,
                              child: Text(item),
                            ))
                        .toList(),
                    onChanged: (item) => setState(
                      () => _selectedPlayerFaction = item.toString(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      helperText: 'Player Mat Number',
                    ),
                    initialValue: _selectedPlayerMat,
                    items: playerMats
                        .map((item) => DropdownMenuItem<String>(
                              value: item,
                              child: Text(item),
                            ))
                        .toList(),
                    onChanged: (item) => setState(
                      () => _selectedPlayerMat = item.toString(),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      ElevatedButton(
                        onPressed: isConnecting ? null : _onJoinPressed,
                        child: const Text('Join Room'),
                      ),
                      ElevatedButton(
                        onPressed: _scanQr,
                        child: const Text('Scan QR'),
                      ),
                    ],
                  ),
                  ServerUrlFooter(serverUrl: serverUrl),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
