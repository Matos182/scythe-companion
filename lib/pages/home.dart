// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/route_const.dart';
import '../utils/colors.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // TODO[T3.4]: request POST_NOTIFICATIONS permission here via
  // flutter_local_notifications (replaces the old awesome_notifications check).

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          backgroundColor: bgColorBar,
          title: const Text(
            "Scythe Companion",
            style: TextStyle(color: buttonTextColor),
          ),
          centerTitle: true,
        ),
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
                      padding: const EdgeInsets.all(7.0),
                      child: ElevatedButton(
                          onPressed: () {
                            context.goNamed(RouteNames.simple);
                          },
                          style: const ButtonStyle(
                              elevation: WidgetStatePropertyAll(7),
                              backgroundColor:
                                  WidgetStatePropertyAll(bgColorBar),
                              foregroundColor:
                                  WidgetStatePropertyAll(buttonTextColor),
                              fixedSize: WidgetStatePropertyAll(Size(150, 50))),
                          child: const Text("Simple Convert")),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(7.0),
                      child: ElevatedButton(
                          onPressed: () {
                            context.goNamed(RouteNames.addplayer);
                          },
                          style: const ButtonStyle(
                              elevation: WidgetStatePropertyAll(7),
                              backgroundColor:
                                  WidgetStatePropertyAll(bgColorBar),
                              foregroundColor:
                                  WidgetStatePropertyAll(buttonTextColor),
                              fixedSize: WidgetStatePropertyAll(Size(150, 50))),
                          child: const Text("Game Results")),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(7.0),
                      child: ElevatedButton(
                          onPressed: () {
                            context.goNamed(RouteNames.create);
                          },
                          style: const ButtonStyle(
                              elevation: WidgetStatePropertyAll(7),
                              backgroundColor:
                                  WidgetStatePropertyAll(bgColorBar),
                              foregroundColor:
                                  WidgetStatePropertyAll(buttonTextColor),
                              fixedSize: WidgetStatePropertyAll(Size(150, 50))),
                          child: const Text("Create Room")),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(7.0),
                      child: ElevatedButton(
                          onPressed: () {
                            context.goNamed(RouteNames.join);
                          },
                          style: const ButtonStyle(
                              elevation: WidgetStatePropertyAll(7),
                              backgroundColor:
                                  WidgetStatePropertyAll(bgColorBar),
                              foregroundColor:
                                  WidgetStatePropertyAll(buttonTextColor),
                              fixedSize: WidgetStatePropertyAll(Size(150, 50))),
                          child: const Text("Join Room")),
                    ),
                  ]),
            )));
  }
}
