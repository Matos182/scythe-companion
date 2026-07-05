// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../domain/score_calculator.dart';
import '../domain/models/score_input.dart';
import '../models/players.dart';
import '../widgets/score_form.dart';
import '../utils/colors.dart';

/// [SimplePage] is a StatefulWidget representing the simple calculator page.
/// Users input data for a single player and convert all items to coins.

class SimplePage extends StatefulWidget {
  const SimplePage({super.key});

  @override
  State<SimplePage> createState() => _SimplePageState();
}

class _SimplePageState extends State<SimplePage> {
  final _formKey = GlobalKey<FormState>();
  final List<TextEditingController> controllers =
      List.generate(7, (index) => TextEditingController());

  ScoreEntry player = ScoreEntry('Player', 0, 0, 0, 0, 0, 0, 0);

  void convert() {
    if (!_formKey.currentState!.validate()) return;

    player.name = controllers[0].text;
    player.popularity = int.tryParse(controllers[1].text) ?? 0;
    player.stars = int.tryParse(controllers[2].text) ?? 0;
    player.lands = int.tryParse(controllers[3].text) ?? 0;
    final rawResources = int.tryParse(controllers[4].text) ?? 0;
    player.resources = (rawResources / 2).truncate();
    player.buildings = int.tryParse(controllers[5].text) ?? 0;
    player.coins = int.tryParse(controllers[6].text) ?? 0;

    player.result = coinsFor(ScoreInput(
      name: player.name,
      popularity: player.popularity,
      stars: player.stars,
      lands: player.lands,
      resources: rawResources,
      buildings: player.buildings,
      coins: player.coins,
    ));
    setState(() {});
  }

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
                      Form(
                        key: _formKey,
                        child: ScoreForm(
                          controllers: controllers,
                          onSubmit: convert,
                        ),
                      ),
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
