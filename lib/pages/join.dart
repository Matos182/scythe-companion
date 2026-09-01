// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../data/game_repository.dart';
import '../data/socket_service.dart';
import '../models/players.dart';
import '../provider/room_notifier.dart';
import '../utils/colors.dart';
import '../utils/qr_payload.dart';
import '../utils/strings.dart';
import '../widgets/connection_pill.dart';
import '../widgets/scrollable_center_column.dart';
import '../widgets/widgets.dart';
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
    super.dispose();
    _playerName.dispose();
    _roomId.dispose();
  }

  /// T3.2: launch the QR scanner, take the first `scythe://join?…`
  /// payload we see, and:
  ///   1) repoint the socket adapter at the embedded server URL
  ///      (so the upcoming joinRoom hits the right server);
  ///   2) fill the room-code field;
  ///   3) surface a confirmation snackbar so the user sees what happened.
  /// We DON'T auto-tap Join — the user still picks faction/mat and
  /// confirms. This matches the existing flow and avoids surprises.
  Future<void> _scanQr() async {
    final payload = await Navigator.of(context).push<JoinPayload>(
      MaterialPageRoute(builder: (_) => const QrScannerPage()),
    );
    if (!mounted || payload == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final repository = context.read<GameRepository>();
    // Set the URL first; if it differs from the current one, the
    // adapter swap (T3.2) gives the next joinRoom the right host.
    await repository.setServerUrl(payload.server);
    setState(() {
      _roomId.text = payload.roomCode;
    });
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          '${QrScannerStrings.scannedPrefix} ${payload.roomCode} '
          '${QrScannerStrings.scannedOnSuffix} ${payload.server}',
        ),
      ),
    );
  }

  /// T3.5: client-side validation for both the nickname and the
  /// room code. The server will reject empty/blanks with the
  /// matching VAL_* envelope, but a local snackbar gives faster
  /// feedback and avoids the round-trip + envelope hop.
  void _onJoinPressed() {
    final nickname = _playerName.text.trim();
    if (nickname.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(ValidationStrings.nicknameRequiredJoin),
        ),
      );
      return;
    }
    final roomCode = _roomId.text.trim().toUpperCase();
    if (roomCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(ValidationStrings.roomCodeRequired),
        ),
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
    // Surface both the initial handshake and socket.io retries (parity with
    // Create). Must be `watch` so the widget rebuilds on state changes.
    final connectionState = context.watch<RoomNotifier>().connectionState;
    final isConnecting = connectionState == SocketConnectionState.connecting;
    final isRetrying = connectionState == SocketConnectionState.reconnecting;
    final serverUrl = context.read<GameRepository>().currentServerUrl;

    return Scaffold(
      backgroundColor: bgColorBar,
      appBar: AppBar(
        backgroundColor: bgColorBar,
        title: const Text(
          "Join Room",
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
              padding: const EdgeInsets.fromLTRB(20, 50, 20, 7),
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
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 7),
              child: TextField(
                controller: _roomId,
                style: const TextStyle(color: buttonTextColor),
                decoration: InputDecoration(
                  hintText: 'Insert Room ID',
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
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 7),
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
                          child: Text(item.toString(),
                              style: const TextStyle(color: buttonTextColor)),
                        ))
                    .toList(),
                onChanged: (item) =>
                    setState(() => _selectedPlayerFaction = item.toString()),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 7),
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
                          child: Text(item.toString(),
                              style: const TextStyle(color: buttonTextColor)),
                        ))
                    .toList(),
                onChanged: (item) =>
                    setState(() => _selectedPlayerMat = item.toString()),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(2.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: isConnecting ? null : _onJoinPressed,
                    style: const ButtonStyle(
                      elevation: WidgetStatePropertyAll(7),
                      backgroundColor: WidgetStatePropertyAll(bgColorBar),
                      foregroundColor: WidgetStatePropertyAll(buttonTextColor),
                      fixedSize: WidgetStatePropertyAll(Size(150, 50)),
                    ),
                    child: const Text("Join Room"),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _scanQr,
                    style: const ButtonStyle(
                      elevation: WidgetStatePropertyAll(7),
                      backgroundColor: WidgetStatePropertyAll(bgColorBar),
                      foregroundColor: WidgetStatePropertyAll(buttonTextColor),
                      fixedSize: WidgetStatePropertyAll(Size(150, 50)),
                    ),
                    child: const Text("Scan QR"),
                  ),
                ],
              ),
            ),
            ServerUrlFooter(serverUrl: serverUrl),
          ],
        ),
      ),
    );
  }
}
