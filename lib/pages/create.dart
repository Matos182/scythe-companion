// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/players.dart';
import '../utils/colors.dart';
import '../resources/socket_methods.dart';
import '../widgets/widgets.dart';

class CreateRoom extends StatefulWidget {
  const CreateRoom({super.key});

  @override
  State<CreateRoom> createState() => _CreateRoomState();
}

class _CreateRoomState extends State<CreateRoom> {
  final _playerName = TextEditingController();
  final _socketMethods = SocketMethods();
  String _selectedPlayerFaction = 'Crimea';
  String _selectedPlayerMat = '1';
  String _selectedPlayerTimer = '15:00';
  late int _secondsPlayerTimer;

  @override
  void initState() {
    super.initState();
    _socketMethods.createRoomSuccessListener(context);
    _socketMethods.errorOccurredListener(context);
  }

  @override
  void dispose() {
    super.dispose();
    _playerName.dispose();
    //_socketMethods.disposeListeners();
  }

  @override
  Widget build(BuildContext context) {
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
                      )),
                  Padding(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 15),
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
                                child: Text(item,
                                    style: const TextStyle(
                                        color: buttonTextColor))))
                            .toList(),
                        onChanged: (item) => setState(
                            () => _selectedPlayerFaction = item.toString()),
                      )),
                  Padding(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 15),
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
                                child: Text(item,
                                    style: const TextStyle(
                                        color: buttonTextColor))))
                            .toList(),
                        onChanged: (item) => setState(
                            () => _selectedPlayerMat = item.toString()),
                      )),
                  Padding(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
                      child: DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                            helperText: 'Individual Player\'s Turn Time',
                            helperStyle: const TextStyle(color: yourTurnText),
                            filled: true,
                            fillColor: bgColorBar,
                            focusedBorder: border,
                            enabledBorder: border),
                        value: _selectedPlayerTimer,
                        items: playerTimers
                            .map((item) => DropdownMenuItem<String>(
                                value: item,
                                child: Text(item,
                                    style: const TextStyle(
                                        color: buttonTextColor))))
                            .toList(),
                        onChanged: (item) => setState(
                            () => _selectedPlayerTimer = item.toString()),
                      )),
                  Padding(
                    padding: const EdgeInsets.all(2.0),
                    child: ElevatedButton(
                        onPressed: () {
                          if (_selectedPlayerTimer == '15:00') {
                            _secondsPlayerTimer = 900;
                          } else if (_selectedPlayerTimer == '20:00') {
                            _secondsPlayerTimer = 1200;
                          } else if (_selectedPlayerTimer == '25:00') {
                            _secondsPlayerTimer = 1500;
                          } else if (_selectedPlayerTimer == '30:00') {
                            _secondsPlayerTimer = 1800;
                          }
                          _socketMethods.createRoom(
                              _playerName.text,
                              _selectedPlayerFaction,
                              _selectedPlayerMat,
                              _secondsPlayerTimer);
                        },
                        style: const ButtonStyle(
                            elevation: MaterialStatePropertyAll(7),
                            backgroundColor:
                                MaterialStatePropertyAll(bgColorBar),
                            foregroundColor:
                                MaterialStatePropertyAll(buttonTextColor),
                            fixedSize: MaterialStatePropertyAll(Size(150, 50))),
                        child: const Text("Create Room")),
                  ),
                ]))));
  }
}
