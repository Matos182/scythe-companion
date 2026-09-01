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
import '../utils/strings.dart';
import '../widgets/connection_pill.dart';
import '../widgets/scrollable_center_column.dart';

class CreateRoom extends StatefulWidget {
  const CreateRoom({super.key});

  @override
  State<CreateRoom> createState() => _CreateRoomState();
}

class _CreateRoomState extends State<CreateRoom> {
  final _playerName = TextEditingController();
  String _selectedPlayerFaction = 'Crimea';
  String _selectedPlayerMat = '1';
  String _selectedPlayerTimer = '15:00';
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
    super.dispose();
  }

  void _onCreatePressed() {
    final nickname = _playerName.text.trim();
    if (nickname.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(ValidationStrings.nicknameRequiredCreate),
        ),
      );
      return;
    }
    context.read<RoomNotifier>().createRoom(
          nickname: nickname,
          faction: _selectedPlayerFaction,
          mat: _selectedPlayerMat,
          timerSec: playerTimerSeconds(_selectedPlayerTimer),
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
        title: const Text('Create Room'),
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
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      helperText: "Individual Player's Turn Time",
                    ),
                    initialValue: _selectedPlayerTimer,
                    items: playerTimers
                        .map((item) => DropdownMenuItem<String>(
                              value: item,
                              child: Text(item),
                            ))
                        .toList(),
                    onChanged: (item) => setState(
                      () => _selectedPlayerTimer = item.toString(),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: isConnecting ? null : _onCreatePressed,
                    child: const Text('Create Room'),
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
