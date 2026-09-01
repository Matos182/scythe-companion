// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../data/game_repository.dart';
import '../data/socket_service.dart';
import '../models/players.dart';
import '../utils/colors.dart';
import '../utils/strings.dart';
import '../provider/room_notifier.dart';
import '../widgets/connection_pill.dart';
import '../widgets/scrollable_center_column.dart';
import '../widgets/widgets.dart';

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

  /// T3.2: pre-fill the nickname from the persisted settings so the
  /// user doesn't retype it every game. Runs in didChangeDependencies
  /// (not initState) because Provider lookup needs an inherited-widget
  /// context; the _nicknameLoaded guard makes it one-shot.
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
    super.dispose();
    _playerName.dispose();
  }

  /// T3.5: client-side nickname validation. Mirrors the server's
  /// VAL_MISSING_NICKNAME code path; a local snackbar gives faster
  /// feedback than a round-trip + error envelope.
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
    // Surface both the initial handshake and socket.io retries above the
    // form. This MUST be `watch`, not `read`: without subscribing, the
    // widget never rebuilds as the connection state changes.
    final connectionState = context.watch<RoomNotifier>().connectionState;
    final isConnecting = connectionState == SocketConnectionState.connecting;
    final isRetrying = connectionState == SocketConnectionState.reconnecting;
    final serverUrl = context.read<GameRepository>().currentServerUrl;

    return Scaffold(
      backgroundColor: bgColorBar,
      appBar: AppBar(
        backgroundColor: bgColorBar,
        title: const Text(
          "Create Room",
          style: TextStyle(color: buttonTextColor),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.home_rounded, color: buttonTextColor),
            tooltip: 'Home',
            onPressed: () {
              context.go('/');
            },
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage("assets/background.png"),
            fit: BoxFit.cover,
          ),
        ),
        child: ScrollableCenterColumn(
          children: <Widget>[
            if (isConnecting || isRetrying)
              ConnectionPill(
                label: isRetrying ? ConnectionStrings.retryingPill : null,
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 50),
              child: TextField(
                controller: _playerName,
                style: const TextStyle(color: buttonTextColor),
                decoration: InputDecoration(
                  hintText: 'Insert Player Name',
                  hintStyle: const TextStyle(color: buttonTextColor),
                  filled: true,
                  fillColor: bgColorBar,
                  focusedBorder: border,
                  enabledBorder: border,
                ),
                keyboardType: TextInputType.text,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 15),
              child: DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  helperText: 'Player Faction',
                  helperStyle: const TextStyle(color: yourTurnText),
                  filled: true,
                  fillColor: bgColorBar,
                  focusedBorder: border,
                  enabledBorder: border,
                ),
                initialValue: _selectedPlayerFaction,
                items: playerFactions
                    .map((item) => DropdownMenuItem<String>(
                          value: item,
                          child: Text(item,
                              style: const TextStyle(color: buttonTextColor)),
                        ))
                    .toList(),
                onChanged: (item) =>
                    setState(() => _selectedPlayerFaction = item.toString()),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 15),
              child: DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  helperText: 'Player Mat Number',
                  helperStyle: const TextStyle(color: yourTurnText),
                  filled: true,
                  fillColor: bgColorBar,
                  focusedBorder: border,
                  enabledBorder: border,
                ),
                initialValue: _selectedPlayerMat,
                items: playerMats
                    .map((item) => DropdownMenuItem<String>(
                          value: item,
                          child: Text(item,
                              style: const TextStyle(color: buttonTextColor)),
                        ))
                    .toList(),
                onChanged: (item) =>
                    setState(() => _selectedPlayerMat = item.toString()),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
              child: DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  helperText: "Individual Player's Turn Time",
                  helperStyle: const TextStyle(color: yourTurnText),
                  filled: true,
                  fillColor: bgColorBar,
                  focusedBorder: border,
                  enabledBorder: border,
                ),
                initialValue: _selectedPlayerTimer,
                items: playerTimers
                    .map((item) => DropdownMenuItem<String>(
                          value: item,
                          child: Text(item,
                              style: const TextStyle(color: buttonTextColor)),
                        ))
                    .toList(),
                onChanged: (item) =>
                    setState(() => _selectedPlayerTimer = item.toString()),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(2.0),
              child: ElevatedButton(
                onPressed: isConnecting ? null : _onCreatePressed,
                style: const ButtonStyle(
                  elevation: WidgetStatePropertyAll(7),
                  backgroundColor: WidgetStatePropertyAll(bgColorBar),
                  foregroundColor: WidgetStatePropertyAll(buttonTextColor),
                  fixedSize: WidgetStatePropertyAll(Size(150, 50)),
                ),
                child: const Text("Create Room"),
              ),
            ),
            ServerUrlFooter(serverUrl: serverUrl),
          ],
        ),
      ),
    );
  }
}
