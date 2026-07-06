// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../data/socket_service.dart';
import '../provider/room_notifier.dart';
import '../widgets/turn.dart';
import '../widgets/waiting_lobby.dart';
import '../utils/colors.dart';

class GamePage extends StatefulWidget {
  const GamePage({super.key});

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
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
    WakelockPlus.enable();
  }

  @override
  void dispose() {
    super.dispose();
    WakelockPlus.disable();
  }

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<RoomNotifier>();
    final room = notifier.room;
    final isMyTurn = notifier.isMyTurn;
    final reconnecting =
        notifier.connectionState == SocketConnectionState.reconnecting;
    final turnRemaining =
        room.players.isNotEmpty && room.turnIndex < room.players.length
            ? room.players[room.turnIndex].remainingSec
            : 0;

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
              (room.isPaused && isMyTurn)
                  ? IconButton(
                      icon: const Icon(
                        Icons.play_arrow,
                        color: buttonTextColor,
                        size: 30,
                      ),
                      onPressed: () {
                        notifier.resume();
                      })
                  : isMyTurn
                      ? IconButton(
                          icon: const Icon(
                            Icons.pause,
                            color: buttonTextColor,
                            size: 30,
                          ),
                          onPressed: () {
                            notifier.pause();
                          })
                      : const IconButton(
                          icon: Icon(
                            Icons.play_arrow,
                            color: unavailableColor,
                            size: 30,
                          ),
                          onPressed: null)
            ]),
        body: Column(children: [
          if (reconnecting)
            Container(
              width: double.infinity,
              color: Colors.orange.shade800,
              padding: const EdgeInsets.all(6),
              child: const Text(
                'Connection lost — reconnecting…',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white),
              ),
            ),
          Expanded(
              child: room.isJoin
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
                              _printFormatedTime(turnRemaining),
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
                                    fixedSize:
                                        WidgetStatePropertyAll(Size(250, 70))),
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
                            headingTextStyle: const TextStyle(
                                color: bgColorBar, fontSize: 14),
                            dataTextStyle: const TextStyle(
                                color: bgColorBar, fontSize: 12),
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
                                  DataCell(Text(
                                      player.connected
                                          ? player.nickname
                                          : '${player.nickname} (offline)',
                                      textAlign: TextAlign.center)),
                                  DataCell(Text(
                                      _printFormatedTime(player.remainingSec),
                                      textAlign: TextAlign.center)),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    )))
        ]));
  }
}
