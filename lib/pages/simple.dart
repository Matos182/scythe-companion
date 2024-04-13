// SPDX-License-Identifier: MIT

/// [Players] class represents a player in the Scythe Coin Calculator app.

// ignore_for_file: dangling_library_doc_comments

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/players.dart';
import '../widgets/widgets.dart';
import '../utils/colors.dart';

/// [SimplePage] is a StatefulWidget representing the simple calculator page of the Scythe Coin Calculator app.
/// Users input data for a player here and can convert all items to coins

class SimplePage extends StatefulWidget {
  const SimplePage({super.key});

  @override
  State<SimplePage> createState() => _SimplePageState();
}

/// [_SimplePageState] is the state class for the [SimplePage].

class _SimplePageState extends State<SimplePage> {
  final List<TextEditingController> controllers =
      List.generate(7, (index) => TextEditingController());

  Players player = Players('Player', 0, 0, 0, 0, 0, 0, 0);
  List<Players> results = [];

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
    setState(() {});
  }

  /// [dispose] function disposes of text controllers.

  @override
  void dispose() {
    for (var controller in controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                        "Player Total Coins ${player.result.toString()}",
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: bgColorBar,
                        ),
                      ),
                      // Text fields for player data input
                      buildTextField(controllers[0], "Player", Icons.face_6,
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

                      Padding(
                        padding: const EdgeInsets.fromLTRB(7, 4, 7, 30),
                        child: ElevatedButton(
                            onPressed: convert,
                            style: const ButtonStyle(
                                elevation: MaterialStatePropertyAll(7),
                                backgroundColor:
                                    MaterialStatePropertyAll(bgColorBar),
                                foregroundColor:
                                    MaterialStatePropertyAll(buttonTextColor),
                                fixedSize:
                                    MaterialStatePropertyAll(Size(150, 50))),
                            child: const Text("Convert")),
                      ),
                    ])))));
  }
}
