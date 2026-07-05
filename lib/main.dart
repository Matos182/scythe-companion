// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import './models/route_config.dart';
import './provider/room_data_provider.dart';

// TODO[T3.4]: initialize flutter_local_notifications here (channel setup,
// Android 13+ POST_NOTIFICATIONS permission flow). The old awesome_notifications
// setup + background service were removed in T0.4 — full replacement lands in T3.4.

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
