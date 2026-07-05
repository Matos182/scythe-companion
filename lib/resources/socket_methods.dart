// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:socket_io_client/socket_io_client.dart';
import '../models/route_const.dart';
import '../provider/room_data_provider.dart';
import '../resources/socket_client.dart';
import '../widgets/widgets.dart';

class SocketMethods {
  final _socketClient = SocketClient.instance.socket!;
  Socket get socketClient => _socketClient;

  // EMITS
  void createRoom(
      String nickname, String playerfaction, String playermat, int timer) {
    _socketClient.emit('createRoom', {
      'nickname': nickname,
      'playerfaction': playerfaction,
      'playermat': playermat,
      'timer': timer,
    });
  }

  void joinRoom(
      String nickname, String roomId, String playerfaction, String playermat) {
    _socketClient.emit('joinRoom', {
      'nickname': nickname,
      'roomId': roomId,
      'playerfaction': playerfaction,
      'playermat': playermat,
    });
  }

  void passTurn(String roomId) {
    _socketClient.emit('turn', {
      'roomId': roomId,
    });
  }

  void startGame(String roomId) {
    _socketClient.emit('startGame', {
      'roomId': roomId,
    });
  }

  void pause(String roomId) {
    _socketClient.emit('pause', {
      'roomId': roomId,
    });
  }

  void toContinue(String roomId, int atualTurn) {
    _socketClient.emit('toContinue', {
      'roomId': roomId,
      'atualTurn': atualTurn,
    });
  }

  //LISTENERS
  void createRoomSuccessListener(BuildContext context) {
    _socketClient.on('createRoomSuccess', (room) {
      Provider.of<RoomDataProvider>(context, listen: false).updateRoom(room);
      context.goNamed(RouteNames.game);
    });
  }

  void joinRoomSuccessListener(BuildContext context) {
    _socketClient.on('joinRoomSuccess', (room) {
      Provider.of<RoomDataProvider>(context, listen: false).updateRoom(room);
      context.goNamed(RouteNames.game);
    });
  }

  void errorOccurredListener(BuildContext context) {
    _socketClient.on('errorOccurred', (data) {
      showSnackBar(context, data);
    });
  }

  void updateRoomListener(BuildContext context) {
    _socketClient.on('updateRoom', (data) {
      Provider.of<RoomDataProvider>(context, listen: false).updateRoom(data);
    });
  }

  void turnListener(BuildContext context) {
    _socketClient.on('newTurn', (data) {
      Provider.of<RoomDataProvider>(context, listen: false).updateRoom(data);
      RoomDataProvider provider =
          Provider.of<RoomDataProvider>(context, listen: false);
      if (_socketClient.id == provider.room.turn.id) {
        // TODO[T3.4]: fire flutter_local_notifications "your turn" alert
      }
    });
  }

  void disposeListeners() {
    _socketClient.off('updateRoom');
    _socketClient.off('newTurn');
    _socketClient.off('errorOccurred');
    _socketClient.off('joinRoomSuccess');
    _socketClient.off('createRoomSuccess');
  }
}
