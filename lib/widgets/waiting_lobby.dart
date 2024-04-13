// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../provider/room_data_provider.dart';
import '../resources/socket_methods.dart';
import '../utils/colors.dart';

class LobbyPage extends StatefulWidget {
  const LobbyPage({super.key});

  @override
  State<LobbyPage> createState() => _LobbyPageState();
}

class _LobbyPageState extends State<LobbyPage> {
  final _socketMethods = SocketMethods();
  late TextEditingController roomIdController;

  @override
  void initState() {
    super.initState();
    _socketMethods.updateRoomListener(context);
    //_socketMethods.errorOccurredListener(context);
    roomIdController = TextEditingController(
      text:
          Provider.of<RoomDataProvider>(context, listen: false).roomData['_id'],
    );
  }

  @override
  void dispose() {
    super.dispose();
    roomIdController.dispose();
    //_socketMethods.disposeListeners();
  }

  @override
  Widget build(BuildContext context) {
    RoomDataProvider room = Provider.of<RoomDataProvider>(context);

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
        rows: room.roomData['players'].map<DataRow>((dynamic player) {
          return DataRow(
            cells: <DataCell>[
              DataCell(Text(
                player['nickname'],
                textAlign: TextAlign.center,
              )),
              DataCell(Text(
                player['playerfaction'],
                style: const TextStyle(fontStyle: FontStyle.italic),
              )),
              DataCell(Text(player['playermat'])),
            ],
          );
        }).toList(),
      ),
      Container(
        padding: const EdgeInsets.fromLTRB(7, 50, 7, 7),
        child: ElevatedButton(
            onPressed: room.roomData['creator']['socketID'] ==
                    _socketMethods.socketClient.id
                ? () {
                    _socketMethods.startGame(room.roomData['_id']);
                  }
                : null,
            style: ButtonStyle(
                elevation: const MaterialStatePropertyAll(7),
                backgroundColor:
                    MaterialStateProperty.resolveWith<Color>((states) {
                  if (states.contains(MaterialState.disabled)) {
                    return unavailableColor; // Disabled color
                  }
                  return bgColorBar; // Regular color
                }),
                foregroundColor:
                    const MaterialStatePropertyAll(buttonTextColor),
                fixedSize: const MaterialStatePropertyAll(Size(150, 50))),
            child: const Text("Start Game")),
      ),
    ]);
  }
}
