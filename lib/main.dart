// SPDX-License-Identifier: MIT

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
