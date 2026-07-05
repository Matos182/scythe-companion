// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../resources/socket_methods.dart';
import '../widgets/turn.dart';
import '../provider/room_data_provider.dart';
import '../widgets/waiting_lobby.dart';
import '../utils/colors.dart';

class GamePage extends StatefulWidget {
  const GamePage({super.key});

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  final _socketMethods = SocketMethods();
  late int _turnIndex;
  late int _turnTimer;
  // TODO[T3.4]: implement "your turn" local notification via flutter_local_notifications

  String _printFormatedTime(int seconds) {
    Duration duration = Duration(seconds: seconds);
    String negativeSign = duration.isNegative ? '-' : '';
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60).abs());
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60).abs());
    return "$negativeSign$twoDigitMinutes:$twoDigitSeconds";
  }

  @override
  void initState() {
    super.initState();
    _socketMethods.updateRoomListener(context);
    _socketMethods.turnListener(context);
    WakelockPlus.enable();
  }

  @override
  void dispose() {
    super.dispose();
    WakelockPlus.disable();
  }

  @override
  Widget build(BuildContext context) {
    RoomDataProvider provider = Provider.of<RoomDataProvider>(context);
    final room = provider.room;
    _turnIndex = room.turnIndex;
    _turnTimer = room.players.isNotEmpty ? room.players[_turnIndex].timer : 0;

    return Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
            backgroundColor: bgColorBar,
            title: const Text(
              "Scythe Game",
              style: TextStyle(color: buttonTextColor),
            ),
            centerTitle: true,
            actions: [
              (room.isPaused &&
                      room.turn.socketID == _socketMethods.socketClient.id)
                  ? IconButton(
                      icon: const Icon(
                        Icons.play_arrow,
                        color: buttonTextColor,
                        size: 30,
                      ),
                      onPressed: () {
                        _socketMethods.resume(room.id, _turnIndex);
                      })
                  : room.turn.socketID == _socketMethods.socketClient.id
                      ? IconButton(
                          icon: const Icon(
                            Icons.pause,
                            color: buttonTextColor,
                            size: 30,
                          ),
                          onPressed: () {
                            _socketMethods.pause(room.id);
                          })
                      : const IconButton(
                          icon: Icon(
                            Icons.play_arrow,
                            color: unavailableColor,
                            size: 30,
                          ),
                          onPressed: null)
            ]),
        body: room.isJoin
            ? const LobbyPage()
            : Center(
                child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 50),
                      child: FittedBox(
                          child: Text(
                        '${room.turn.nickname}\'s Turn  -  Round: ${room.totalTurns}',
                        style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                          color: bgColorBar,
                        ),
                      ))),
                  Container(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 5),
                      child: const Text(
                        'Turn Time Remaining:',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: bgColorBar,
                        ),
                      )),
                  Container(
                      padding: const EdgeInsets.fromLTRB(20, 5, 20, 10),
                      child: Text(
                        // ignore: unnecessary_string_interpolations
                        '${_printFormatedTime(_turnTimer)}',
                        style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                          color: bgColorBar,
                        ),
                      )),
                  room.isPaused
                      ? const ElevatedButton(
                          onPressed: null,
                          style: ButtonStyle(
                              elevation: WidgetStatePropertyAll(7),
                              backgroundColor: WidgetStatePropertyAll(
                                  unavailableColor), // Disabled color
                              foregroundColor:
                                  WidgetStatePropertyAll(yourTurnText),
                              fixedSize: WidgetStatePropertyAll(Size(250, 70))),
                          child: Text(
                            "GAME IS PAUSED!",
                            style: TextStyle(fontSize: 18),
                          ))
                      : const TurnPage(),
                  Container(
                    alignment: Alignment.bottomCenter,
                    padding: const EdgeInsets.fromLTRB(5, 50, 10, 10),
                    child: DataTable(
                      dataRowMaxHeight: 25,
                      dataRowMinHeight: 20,
                      columnSpacing: 40,
                      headingTextStyle:
                          const TextStyle(color: bgColorBar, fontSize: 14),
                      dataTextStyle:
                          const TextStyle(color: bgColorBar, fontSize: 12),
                      columns: const [
                        DataColumn(
                            label: Center(
                                widthFactor: 0.65,
                                child: Text(
                                  'Name',
                                ))),
                        DataColumn(
                            label: Center(
                                widthFactor: 0.8,
                                child: Text(
                                  'Timer',
                                ))),
                      ],
                      rows: room.players.map<DataRow>((player) {
                        return DataRow(
                          cells: [
                            DataCell(Text(player.nickname,
                                textAlign: TextAlign.center)),
                            DataCell(Text(_printFormatedTime(player.timer),
                                textAlign: TextAlign.center)),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ],
              )));
  }
}
