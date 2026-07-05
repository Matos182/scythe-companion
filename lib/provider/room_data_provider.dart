// SPDX-License-Identifier: MIT

import 'dart:async';
import 'package:flutter/material.dart';
import '../domain/models/room.dart';
import '../models/players.dart';

class RoomDataProvider extends ChangeNotifier {
  // Notify Listener

  Room _room = const Room();
  Room get room => _room;

  /// Raw payload kept for the adapter seam — T2.1 may need to inspect
  /// fields not yet mapped to typed models. Remove when all fields are
  /// typed and the server protocol is stable.
  Map<String, dynamic> get roomData => _room.toJson();

  //Stream controller and stream for broadcasting room updates
  final StreamController<Room> _roomController = StreamController.broadcast();
  Stream<Room> get roomStream => _roomController.stream;

  void updateRoom(Map<String, dynamic> data) {
    _room = Room.fromJson(data);
    _roomController.add(_room);
    notifyListeners();
  }

  List<ScoreEntry> _players = [];
  List<ScoreEntry> get players => _players;

  // Update method to update players list and notify listeners
  void updatePlayers(List<ScoreEntry> data) {
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
    _roomController.close();
  }
}
