// SPDX-License-Identifier: MIT

//  __/\\\\____________/\\\\_____/\\\\\\\\\_____/\\\\\\\\\\\\\\\_______/\\\\\__________/\\\\\\\\\\\___
//   _\/\\\\\\________/\\\\\\___/\\\\\\\\\\\\\__\///////\\\/////______/\\\///\\\______/\\\/////////\\\_
//    _\/\\\//\\\____/\\\//\\\__/\\\/////////\\\_______\/\\\_________/\\\/__\///\\\___\//\\\______\///__
//     _\/\\\\///\\\/\\\/_\/\\\_\/\\\_______\/\\\_______\/\\\________/\\\______\//\\\___\////\\\_________
//      _\/\\\__\///\\\/___\/\\\_\/\\\\\\\\\\\\\\\_______\/\\\_______\/\\\_______\/\\\______\////\\\______
//       _\/\\\____\///_____\/\\\_\/\\\/////////\\\_______\/\\\_______\//\\\______/\\\__________\////\\\___
//        _\/\\\_____________\/\\\_\/\\\_______\/\\\_______\/\\\________\///\\\__/\\\_____/\\\______\//\\\__
//         _\/\\\_____________\/\\\_\/\\\_______\/\\\_______\/\\\__________\///\\\\\/_____\///\\\\\\\\\\\/___
//          _\///______________\///__\///________\///________\///_____________\/////_________\///////////_____
//           ___             __         __  _
//          / _ \_______ ___/ __ ______/ /_(____  ___  ___
//         / ___/ __/ _ / _  / // / __/ __/ / _ \/ _ \(_-<
//        /_/  /_/  \___\_,_/\_,_/\__/\__/_/\___/_//_/___/

/// @title: Scythe Coin Calculator
/// @description: A Flutter application for calculating scores in the board game Scythe.
/// @author: Designed by Fabio Matos
/// @version: 0.3.5

// ignore_for_file: dangling_library_doc_comments

import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import './models/route_config.dart';
import './provider/room_data_provider.dart';
import 'resources/back_services.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeService();
  AwesomeNotifications().initialize(null, [
    NotificationChannel(
      channelGroupKey: 'high_importance_channel',
      channelKey: 'high_importance_channel',
      channelName: 'Group 1',
      channelDescription: 'Notification Channel',
      defaultColor: const Color(0xff029031),
      enableLights: true,
      enableVibration: true,
      ledColor: const Color(0xff029031),
      importance: NotificationImportance.Max,
      channelShowBadge: true,
      playSound: true,
      criticalAlerts: true,
    )
  ]);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
        create: (context) => RoomDataProvider(),
        child: MaterialApp.router(
          title: 'Scythe Companion',
          routerConfig: MyRouter().router,
        ));
  }
}
