// SPDX-License-Identifier: MIT

import 'package:socket_io_client/socket_io_client.dart' as i_o;
import '../env/env.dart';

class SocketClient {
  i_o.Socket? socket;
  static SocketClient? _instance;

  SocketClient._internal() {
    socket = i_o.io('http://$ipaddress2:3000', <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
      'force new connection': true
    });
    socket!.connect();
  }

  static SocketClient get instance {
    _instance ??= SocketClient._internal();
    return _instance!;
  }
}
