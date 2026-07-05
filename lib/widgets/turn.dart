// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../provider/room_data_provider.dart';
import '../resources/socket_methods.dart';
import '../utils/colors.dart';

class TurnPage extends StatefulWidget {
  const TurnPage({super.key});

  @override
  State<TurnPage> createState() => _TurnPageState();
}

class _TurnPageState extends State<TurnPage> {
  final SocketMethods _socketMethods = SocketMethods();

  @override
  void initState() {
    super.initState();
    _socketMethods.updateRoomListener(context);
    _socketMethods.turnListener(context);
  }

  @override
  Widget build(BuildContext context) {
    RoomDataProvider provider = Provider.of<RoomDataProvider>(context);
    final room = provider.room;

    return ElevatedButton(
        onPressed: room.turn.socketID == _socketMethods.socketClient.id
            ? () {
                _socketMethods.passTurn(room.id);
              }
            : null,
        style: ButtonStyle(
            elevation: const MaterialStatePropertyAll(7),
            backgroundColor: MaterialStateProperty.resolveWith<Color>((states) {
              if (states.contains(MaterialState.disabled)) {
                return unavailableColor; // Disabled color
              }
              return yourTurnColor; // Regular color
            }),
            foregroundColor: const MaterialStatePropertyAll(yourTurnText),
            fixedSize: const MaterialStatePropertyAll(Size(150, 50))),
        child: const Text("Pass Turn"));
  }
}
