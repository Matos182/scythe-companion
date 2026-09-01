// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../domain/score_calculator.dart';
import '../domain/models/score_input.dart';
import '../models/route_const.dart';
import '../models/players.dart';
import '../provider/room_data_provider.dart';
import '../ui/backdrop.dart';
import '../ui/theme.dart';
import '../widgets/score_form.dart';

/// [PlayerAddPage] allows users to input data for each player.
/// Collects name, popularity, stars, lands, resources, building coins,
/// and coins. Users can add up to 7 players.

class PlayerAddPage extends StatefulWidget {
  const PlayerAddPage({super.key});

  @override
  State<PlayerAddPage> createState() => _PlayerAddPageState();
}

class _PlayerAddPageState extends State<PlayerAddPage> {
  final _formKey = GlobalKey<FormState>();
  late List<TextEditingController> controllers;
  late int playerCounter;
  late List<ScoreEntry> results;

  @override
  void initState() {
    super.initState();
    controllers = List.generate(7, (index) => TextEditingController());
    playerCounter =
        Provider.of<RoomDataProvider>(context, listen: false).playerCounter;
    results = Provider.of<RoomDataProvider>(context, listen: false).players;
  }

  @override
  void dispose() {
    for (var controller in controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  /// [convert] validates the form, calculates the player's score,
  /// and adds the entry to the results list.
  void convert() {
    if (!_formKey.currentState!.validate()) return;

    final name = controllers[0].text;
    final popularity = int.tryParse(controllers[1].text) ?? 0;
    final stars = int.tryParse(controllers[2].text) ?? 0;
    final lands = int.tryParse(controllers[3].text) ?? 0;
    final rawResources = int.tryParse(controllers[4].text) ?? 0;
    final buildings = int.tryParse(controllers[5].text) ?? 0;
    final coins = int.tryParse(controllers[6].text) ?? 0;
    final resources = (rawResources / 2).truncate();

    final result = coinsFor(ScoreInput(
      name: name,
      popularity: popularity,
      stars: stars,
      lands: lands,
      resources: rawResources,
      buildings: buildings,
      coins: coins,
    ));

    results.add(ScoreEntry(
        name, popularity, stars, lands, resources, buildings, coins, result));
    Provider.of<RoomDataProvider>(context, listen: false)
        .updatePlayers(results);

    playerCounter++;
    Provider.of<RoomDataProvider>(context, listen: false)
        .updateCounter(playerCounter);

    // Clear fields for next entry
    for (var c in controllers) {
      c.clear();
    }

    context.pushNamed(RouteNames.addplayer);
  }

  @override
  Widget build(BuildContext context) {
    final roomDataProvider = Provider.of<RoomDataProvider>(context);
    final results = roomDataProvider.players;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scythe Coin Calculator'),
        actions: [
          IconButton(
            icon: const Icon(Icons.home_rounded),
            tooltip: 'Home',
            onPressed: () => context.go('/'),
          ),
        ],
      ),
      body: ScytheBackdrop(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          scrollDirection: Axis.vertical,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(
                  "Player ${playerCounter.toString()} Score",
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: ScytheColors.brass,
                  ),
                ),
                Form(
                  key: _formKey,
                  child: ScoreForm(controllers: controllers),
                ),
                Wrap(
                  alignment: WrapAlignment.center,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(7, 3, 7, 35),
                      child: ElevatedButton(
                        onPressed: playerCounter < 7 ? convert : null,
                        child: const Text('Add Player'),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(7, 3, 7, 35),
                      child: ElevatedButton(
                        onPressed: results.isNotEmpty
                            ? () {
                                convert();
                                Provider.of<RoomDataProvider>(context,
                                        listen: false)
                                    .updatePlayers(results);
                                context.pushNamed(RouteNames.result);
                              }
                            : null,
                        child: const Text('Show Results'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
