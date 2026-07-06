// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../provider/room_notifier.dart';
import '../utils/colors.dart';

class LobbyPage extends StatefulWidget {
  const LobbyPage({super.key});

  @override
  State<LobbyPage> createState() => _LobbyPageState();
}

class _LobbyPageState extends State<LobbyPage> {
  late TextEditingController roomIdController;

  @override
  void initState() {
    super.initState();
    roomIdController = TextEditingController(
      text: context.read<RoomNotifier>().room.id,
    );
  }

  @override
  void dispose() {
    super.dispose();
    roomIdController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<RoomNotifier>();
    final room = notifier.room;
    // Keep the read-only field in sync when the room arrives after
    // initState (e.g. slow create round-trip).
    if (roomIdController.text != room.id) {
      roomIdController.text = room.id;
    }

    return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Text(
        'Waiting for Players...',
        style: TextStyle(
            fontWeight: FontWeight.bold, color: bgColorBar, fontSize: 20),
      ),
      const SizedBox(height: 50),
      Container(
          decoration: const BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: bgColorBar,
                blurRadius: 5,
                spreadRadius: 2,
              )
            ],
          ),
          child: TextField(
              readOnly: true,
              controller: roomIdController,
              textAlign: TextAlign.center,
              decoration: const InputDecoration(
                hintStyle: TextStyle(color: buttonTextColor),
                fillColor: bgColorBar,
                filled: true,
              ))),
      DataTable(
        dataRowMaxHeight: 35,
        dataRowMinHeight: 20,
        columnSpacing: 40,
        headingTextStyle: const TextStyle(
            fontWeight: FontWeight.bold, color: bgColorBar, fontSize: 16),
        dataTextStyle: const TextStyle(
          color: bgColorBar,
          fontSize: 14,
        ),
        columns: const <DataColumn>[
          DataColumn(
              label: Center(
                  widthFactor: 0.7,
                  child: Text(
                    'Name',
                  ))),
          DataColumn(
              label: Center(
                  widthFactor: 0.8,
                  child: Text(
                    'Faction',
                  ))),
          DataColumn(
              label: Center(
                  widthFactor: 0.5,
                  child: Text(
                    'Mat',
                  ))),
        ],
        rows: room.players.map<DataRow>((player) {
          return DataRow(
            cells: <DataCell>[
              DataCell(Text(
                player.nickname,
                textAlign: TextAlign.center,
              )),
              DataCell(Text(
                player.playerfaction,
                style: const TextStyle(fontStyle: FontStyle.italic),
              )),
              DataCell(Text(player.playermat)),
            ],
          );
        }).toList(),
      ),
      Container(
        padding: const EdgeInsets.fromLTRB(7, 50, 7, 7),
        child: ElevatedButton(
            onPressed: notifier.isCreator
                ? () {
                    notifier.startGame();
                  }
                : null,
            style: ButtonStyle(
                elevation: const WidgetStatePropertyAll(7),
                backgroundColor:
                    WidgetStateProperty.resolveWith<Color>((states) {
                  if (states.contains(WidgetState.disabled)) {
                    return unavailableColor; // Disabled color
                  }
                  return bgColorBar; // Regular color
                }),
                foregroundColor: const WidgetStatePropertyAll(buttonTextColor),
                fixedSize: const WidgetStatePropertyAll(Size(150, 50))),
            child: const Text("Start Game")),
      ),
    ]);
  }
}
