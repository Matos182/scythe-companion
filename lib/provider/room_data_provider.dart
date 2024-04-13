// SPDX-License-Identifier: MIT

import 'dart:async';
import 'package:flutter/material.dart';
import '../models/players.dart';

class RoomDataProvider extends ChangeNotifier {
  // Notify Listener

  Map<String, dynamic> _roomData = {};
  Map<String, dynamic> get roomData => _roomData;

  //Stream controller and stream for broadcasting roomData updates
  final StreamController<Map<String, dynamic>> _roomDataController =
      StreamController.broadcast();
  Stream<Map<String, dynamic>> get roomDataStream => _roomDataController.stream;

  void updateRoomData(Map<String, dynamic> data) {
    _roomData = data;
    _roomDataController.add(data);
    notifyListeners();
  }

  List<Players> _players = [];
  List<Players> get players => _players;

  // Update method to update roomData and notify listeners
  void updatePlayers(List<Players> data) {
    _players = data;
    notifyListeners();
  }

  int _playerCounter = 1;
  int get playerCounter => _playerCounter;

  void updateCounter(int data) {
    _playerCounter = data;
    notifyListeners();
  }

  // Dispose the stream controller when it's no longer needed
  @override
  void dispose() {
    super.dispose();
    _roomDataController.close();
  }
}
