// SPDX-License-Identifier: MIT

import 'dart:ui';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import '../resources/socket_methods.dart';
import '../provider/room_data_provider.dart';

Future<void> initializeService() async {
  final service = FlutterBackgroundService();
  await service.configure(
      iosConfiguration: IosConfiguration(),
      androidConfiguration: AndroidConfiguration(
          onStart: onStart, isForegroundMode: false, autoStart: true));
  service.startService();
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  if (service is AndroidServiceInstance) {
    final socketMethods = SocketMethods();
    final roomProvider = RoomDataProvider();
    roomProvider.roomDataStream.listen((roomData) async {
      if (roomData['turn']['socketID'] == socketMethods.socketClient.id) {
        AwesomeNotifications().createNotification(
          content: NotificationContent(
            id: 10,
            channelKey: 'high_importance_channel',
            title: 'It\'s YOUR turn!!!',
            body: 'Go to Game Page!!',
            largeIcon: 'assets/logo.png',
            displayOnBackground: true,
          ),
        );
      } else {
        return;
      }
    });
    //service.on('showNotification').listen((event) {});
  }
}
