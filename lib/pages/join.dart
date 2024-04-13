import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/players.dart';
import '../resources/socket_methods.dart';
import '../utils/colors.dart';
import '../widgets/widgets.dart';

class JoinRoom extends StatefulWidget {
  const JoinRoom({super.key});

  @override
  State<JoinRoom> createState() => _JoinRoomState();
}

class _JoinRoomState extends State<JoinRoom> {
  final _playerName = TextEditingController();
  final _roomId = TextEditingController();
  final _socketMethods = SocketMethods();
  String _selectedPlayerFaction = 'Crimea';
  String _selectedPlayerMat = '1';

  @override
  void initState() {
    super.initState();
    _socketMethods.joinRoomSuccessListener(context);
    _socketMethods.errorOccurredListener(context);
  }

  @override
  void dispose() {
    super.dispose();
    _playerName.dispose();
    _roomId.dispose();
    //_socketMethods.disposeListeners();
  }

  @override
  Widget build(BuildContext context) {
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
                  icon: const Icon(Icons.recycling_rounded,
                      color: buttonTextColor),
                  onPressed: () {
                    context.go('/');
                  }),
            ]),
        body: Container(
            decoration: const BoxDecoration(
                image: DecorationImage(
                    image: AssetImage("assets/background.png"),
                    fit: BoxFit.cover)),
            child: Center(
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
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
                      )),
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
                      )),
                  Padding(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 7),
                      child: DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                            helperText: 'Player Faction',
                            helperStyle: const TextStyle(color: yourTurnText),
                            filled: true,
                            fillColor: bgColorBar,
                            focusedBorder: border,
                            enabledBorder: border),
                        value: _selectedPlayerFaction,
                        items: playerFactions
                            .map((item) => DropdownMenuItem<String>(
                                value: item,
                                child: Text(item.toString(),
                                    style: const TextStyle(
                                        color: buttonTextColor))))
                            .toList(),
                        onChanged: (item) => setState(
                            () => _selectedPlayerFaction = item.toString()),
                      )),
                  Padding(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 7),
                      child: DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                            helperText: 'Player Mat Number',
                            helperStyle: const TextStyle(color: yourTurnText),
                            filled: true,
                            fillColor: bgColorBar,
                            focusedBorder: border,
                            enabledBorder: border),
                        value: _selectedPlayerMat,
                        items: playerMats
                            .map((item) => DropdownMenuItem<String>(
                                value: item,
                                child: Text(item.toString(),
                                    style: const TextStyle(
                                        color: buttonTextColor))))
                            .toList(),
                        onChanged: (item) => setState(
                            () => _selectedPlayerMat = item.toString()),
                      )),
                  Padding(
                    padding: const EdgeInsets.all(2.0),
                    child: ElevatedButton(
                        onPressed: () {
                          _socketMethods.joinRoom(
                              _playerName.text,
                              _roomId.text,
                              _selectedPlayerFaction,
                              _selectedPlayerMat);
                        },
                        style: const ButtonStyle(
                            elevation: MaterialStatePropertyAll(7),
                            backgroundColor:
                                MaterialStatePropertyAll(bgColorBar),
                            foregroundColor:
                                MaterialStatePropertyAll(buttonTextColor),
                            fixedSize: MaterialStatePropertyAll(Size(150, 50))),
                        child: const Text("Join Room")),
                  ),
                ]))));
  }
}
