// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import '../models/players.dart';

/// Offline calculator state: score entries + player counter.
///
/// Multiplayer room state moved to [RoomNotifier] (T3.1) — this provider
/// now only serves the "Game Results" / "Simple Convert" flows.
class RoomDataProvider extends ChangeNotifier {
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
}
