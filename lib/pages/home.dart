// SPDX-License-Identifier: MIT

import 'package:awesome_notifications/awesome_notifications.dart';
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
  @override
  void initState() {
    AwesomeNotifications().isNotificationAllowed().then((isAllowed) async {
      if (!isAllowed) {
        await AwesomeNotifications().requestPermissionToSendNotifications();
      }
    });
    super.initState();
  }

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
                              elevation: MaterialStatePropertyAll(7),
                              backgroundColor:
                                  MaterialStatePropertyAll(bgColorBar),
                              foregroundColor:
                                  MaterialStatePropertyAll(buttonTextColor),
                              fixedSize:
                                  MaterialStatePropertyAll(Size(150, 50))),
                          child: const Text("Simple Convert")),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(7.0),
                      child: ElevatedButton(
                          onPressed: () {
                            //GoRouter.of(context).go('/result');
                            context.goNamed(RouteNames.addplayer);
                          },
                          style: const ButtonStyle(
                              elevation: MaterialStatePropertyAll(7),
                              backgroundColor:
                                  MaterialStatePropertyAll(bgColorBar),
                              foregroundColor:
                                  MaterialStatePropertyAll(buttonTextColor),
                              fixedSize:
                                  MaterialStatePropertyAll(Size(150, 50))),
                          child: const Text("Game Results")),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(7.0),
                      child: ElevatedButton(
                          onPressed: () {
                            context.goNamed(RouteNames.create);
                          },
                          style: const ButtonStyle(
                              elevation: MaterialStatePropertyAll(7),
                              backgroundColor:
                                  MaterialStatePropertyAll(bgColorBar),
                              foregroundColor:
                                  MaterialStatePropertyAll(buttonTextColor),
                              fixedSize:
                                  MaterialStatePropertyAll(Size(150, 50))),
                          child: const Text("Create Room")),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(7.0),
                      child: ElevatedButton(
                          onPressed: () {
                            context.goNamed(RouteNames.join);
                          },
                          style: const ButtonStyle(
                              elevation: MaterialStatePropertyAll(7),
                              backgroundColor:
                                  MaterialStatePropertyAll(bgColorBar),
                              foregroundColor:
                                  MaterialStatePropertyAll(buttonTextColor),
                              fixedSize:
                                  MaterialStatePropertyAll(Size(150, 50))),
                          child: const Text("Join Room")),
                    ),
                  ]),
            )));
  }
}
