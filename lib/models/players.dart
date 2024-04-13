// SPDX-License-Identifier: MIT

/// [Players] class represents a player in the Scythe Coin Calculator app.

// ignore_for_file: dangling_library_doc_comments

class Players {
  String name = '';
  int popularity = 0;
  int stars = 0;
  int lands = 0;
  int resources = 0;
  int coins = 0;
  int buildings = 0;
  int result = 0;

  /// Constructor for initializing a player with provided attributes.
  Players(this.name, this.popularity, this.stars, this.lands, this.resources,
      this.buildings, this.coins, this.result);
}

const List<String> playerFactions = [
  'Crimea',
  'Saxony',
  'Polania',
  'Albion',
  'Nordic',
  'Rusviet',
  'Togawa'
];

const List<String> playerMats = ['1', '2', '2A', '3', '3A', '4', '5'];

const List<String> playerTimers = ['15:00', '20:00', '25:00', '30:00'];
