// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../models/route_const.dart';
import '../models/players.dart';
import '../provider/room_data_provider.dart';
import '../widgets/widgets.dart';
import '../utils/colors.dart';

/// [PlayerAddPage] is a StatefulWidget that allows users to input data for each player.
/// It collects information such as player name, popularity, stars, lands, resources,
/// building coins, and coins. Users can add up to 7 players.

class PlayerAddPage extends StatefulWidget {
  const PlayerAddPage({super.key});

  @override
  State<PlayerAddPage> createState() =>
      _PlayerAddPageState(); // I prefered to use logic in 'createState'
}

/// [_PlayerAddPageState] is the state class for the [PlayerAddPage].

class _PlayerAddPageState extends State<PlayerAddPage> {
  late List<TextEditingController> controllers;
  late int playerCounter;
  late Players player;
  late List<Players> results;

  @override
  void initState() {
    super.initState();
    controllers = List.generate(7, (index) => TextEditingController());
    playerCounter =
        Provider.of<RoomDataProvider>(context, listen: false).playerCounter;
    results = Provider.of<RoomDataProvider>(context, listen: false).players;
    player = Players('', 0, 0, 0, 0, 0, 0, 0);
  }

  @override
  void dispose() {
    for (var controller in controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  /// [convert] function extracts data from text controllers, calculates the player's score,
  /// and adds the player's data to the results list.

  void convert() {
    player.name = controllers[0].text;
    player.popularity = int.tryParse(controllers[1].text) ?? 0;
    player.stars = int.tryParse(controllers[2].text) ?? 0;
    player.lands = int.tryParse(controllers[3].text) ?? 0;
    player.resources =
        ((int.tryParse(controllers[4].text) ?? 0) / 2).truncate();
    player.buildings = int.tryParse(controllers[5].text) ?? 0;
    player.coins = int.tryParse(controllers[6].text) ?? 0;

    if (player.name == '') {
      showSnackBar(context, 'Please, insert a valid Player Name!');
      return;
    }

    if (player.result == 0) {
      showSnackBar(context, 'Please, insert the Results!');
      return;
    }

    if (player.popularity < 7) {
      player.result = player.stars * 3 +
          player.lands * 2 +
          player.resources +
          player.buildings +
          player.coins;
    } else if (player.popularity >= 7 && player.popularity < 13) {
      player.result = player.stars * 4 +
          player.lands * 3 +
          player.resources * 2 +
          player.buildings +
          player.coins;
    } else {
      player.result = player.stars * 5 +
          player.lands * 4 +
          player.resources * 3 +
          player.buildings +
          player.coins;
    }
    results.add(Players(
        player.name,
        player.popularity,
        player.stars,
        player.lands,
        player.resources,
        player.buildings,
        player.coins,
        player.result));
    Provider.of<RoomDataProvider>(context, listen: false)
        .updatePlayers(results);
    setState(() {});

    playerCounter++;
    Provider.of<RoomDataProvider>(context, listen: false)
        .updateCounter(playerCounter);
    context.pushNamed(RouteNames.addplayer);
  }

  /// [dispose] function disposes of text controllers.

  @override
  Widget build(BuildContext context) {
    final roomDataProvider = Provider.of<RoomDataProvider>(context);
    final results = roomDataProvider.players;

    return Scaffold(
        backgroundColor: bgColorBar,
        appBar: AppBar(
            backgroundColor: bgColorBar,
            title: const Text("Scythe Coin Calculator",
                style: TextStyle(color: buttonTextColor)),
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
                          color: bgColorBar,
                        ),
                      ),
                      // Text fields for player data input
                      buildTextField(
                          controllers[0],
                          "Player ${playerCounter.toString()}",
                          Icons.face_6,
                          TextInputType.name),
                      buildTextField(controllers[1], "Popularity",
                          Icons.favorite, TextInputType.number),
                      buildTextField(controllers[2], "Stars", Icons.star,
                          TextInputType.number),
                      buildTextField(controllers[3], "Lands", Icons.hexagon,
                          TextInputType.number),
                      buildTextField(controllers[4], "Resources",
                          Icons.my_library_add_rounded, TextInputType.number),
                      buildTextField(controllers[5], "Building Coins",
                          Icons.home_filled, TextInputType.number),
                      buildTextField(controllers[6], "Coins", Icons.circle,
                          TextInputType.number),
                      Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(7, 3, 7, 35),
                              child: ElevatedButton(
                                  onPressed: playerCounter < 7
                                      ? () {
                                          convert();
                                        }
                                      : null,
                                  style: ButtonStyle(
                                      elevation:
                                          const MaterialStatePropertyAll(7),
                                      backgroundColor: MaterialStateProperty
                                          .resolveWith<Color>((states) {
                                        if (states
                                            .contains(MaterialState.disabled)) {
                                          return const Color.fromARGB(255, 122,
                                              120, 119); // Disabled color
                                        }
                                        return bgColorBar; // Regular color
                                      }),
                                      foregroundColor:
                                          const MaterialStatePropertyAll(
                                              buttonTextColor),
                                      fixedSize: const MaterialStatePropertyAll(
                                          Size(150, 50))),
                                  child: const Text("Add Player")),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(7, 3, 7, 35),
                              child: ElevatedButton(
                                  onPressed: results.isNotEmpty
                                      ? () {
                                          convert();
                                          results.map((e) => null);
                                          Provider.of<RoomDataProvider>(context,
                                                  listen: false)
                                              .updatePlayers(results);
                                          context.pushNamed(RouteNames.result);
                                        }
                                      : null,
                                  style: ButtonStyle(
                                      elevation:
                                          const MaterialStatePropertyAll(7),
                                      backgroundColor: MaterialStateProperty
                                          .resolveWith<Color>((states) {
                                        if (states
                                            .contains(MaterialState.disabled)) {
                                          return const Color.fromARGB(255, 122,
                                              120, 119); // Disabled color
                                        }
                                        return bgColorBar; // Regular color
                                      }),
                                      foregroundColor:
                                          const MaterialStatePropertyAll(
                                              buttonTextColor),
                                      fixedSize: const MaterialStatePropertyAll(
                                          Size(150, 50))),
                                  child: const Text("Show Results")),
                            )
                          ])
                    ])))));
  }
}
