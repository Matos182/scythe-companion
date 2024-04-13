// SPDX-License-Identifier: MIT

//import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/material.dart';
//import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:provider/provider.dart';
//import 'package:vibration/vibration.dart';
import 'package:wakelock/wakelock.dart';
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
  TimeOfDay _notiInterval = TimeOfDay.now();

  triggerNoti() {
    if (TimeOfDay.now() != _notiInterval) {
      //FlutterBackgroundService().invoke("showNotification");
      AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: 10,
          channelKey: 'high_importance_channel',
          title: 'It\'s YOUR turn!!!',
          body: 'Timer: ${_printFormatedTime(_turnTimer)}',
          largeIcon: 'assets/logo.png',
          displayOnBackground: true,
        ),
      );
      _notiInterval = TimeOfDay.now();
    }
    setState(() {});
  }

  Future<void> wakeLockEnable() async {
    await Wakelock.enable();
  }

  Future<void> wakeLockDisable() async {
    await Wakelock.disable();
  }

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
    wakeLockEnable();
  }

  @override
  void dispose() {
    super.dispose();
    wakeLockDisable();
    //Vibration.cancel();
  }

  @override
  Widget build(BuildContext context) {
    RoomDataProvider room = Provider.of<RoomDataProvider>(context);
    _turnIndex = room.roomData['turnIndex'];
    _turnTimer = room.roomData['players'][_turnIndex]['timer'];

    // if (room.roomData['turn']['socketID'] == _socketMethods.socketClient.id) {
    //   triggerNoti();
    // }
    // Vibration.vibrate(
    //     pattern: [500, 300, 40000, 300], intensities: [80, 80]);

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
              (room.roomData['isPaused'] &&
                      room.roomData['turn']['socketID'] ==
                          _socketMethods.socketClient.id)
                  ? IconButton(
                      icon: const Icon(
                        Icons.play_arrow,
                        color: buttonTextColor,
                        size: 30,
                      ),
                      onPressed: () {
                        _socketMethods.toContinue(
                            room.roomData['_id'], _turnIndex);
                      })
                  : room.roomData['turn']['socketID'] ==
                          _socketMethods.socketClient.id
                      ? IconButton(
                          icon: const Icon(
                            Icons.pause,
                            color: buttonTextColor,
                            size: 30,
                          ),
                          onPressed: () {
                            _socketMethods.pause(room.roomData['_id']);
                          })
                      : const IconButton(
                          icon: Icon(
                            Icons.play_arrow,
                            color: unavailableColor,
                            size: 30,
                          ),
                          onPressed: null)
            ]),
        body: room.roomData['isJoin']
            ? const LobbyPage()
            : Center(
                child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 50),
                      child: FittedBox(
                          child: Text(
                        '${room.roomData['turn']['nickname']}\'s Turn  -  Round: ${room.roomData['totalTurns']}',
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
                  room.roomData['isPaused']
                      ? const ElevatedButton(
                          onPressed: null,
                          style: ButtonStyle(
                              elevation: MaterialStatePropertyAll(7),
                              backgroundColor: MaterialStatePropertyAll(
                                  unavailableColor), // Disabled color
                              foregroundColor:
                                  MaterialStatePropertyAll(yourTurnText),
                              fixedSize:
                                  MaterialStatePropertyAll(Size(250, 70))),
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
                      rows: room.roomData['players']
                          .map<DataRow>((dynamic player) {
                        return DataRow(
                          cells: [
                            DataCell(Text(player['nickname'],
                                textAlign: TextAlign.center)),
                            DataCell(Text(_printFormatedTime(player['timer']),
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
