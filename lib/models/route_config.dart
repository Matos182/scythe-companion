// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../provider/room_data_provider.dart';
import '../pages/game.dart';
import '../pages/create.dart';
import '../pages/home.dart';
import '../pages/join.dart';
import '../pages/player_add.dart';
import '../pages/result.dart';
import '../pages/simple.dart';
import './route_const.dart';

class MyRouter {
  final GoRouter router = GoRouter(
      refreshListenable: RoomDataProvider(),
      initialLocation: '/',
      errorPageBuilder: (context, state) => MaterialPage(
          key: state.pageKey,
          child: Scaffold(appBar: AppBar(title: const Text('ERROR')))),
      routes: <RouteBase>[
        GoRoute(
            path: '/',
            builder: ((context, state) => const HomePage()),
            routes: <RouteBase>[
              GoRoute(
                  name: RouteNames.simple,
                  path: 'simple',
                  builder: ((context, state) => const SimplePage())),
              GoRoute(
                  name: RouteNames.game,
                  path: 'game',
                  builder: ((context, state) => const GamePage())),
              GoRoute(
                  name: RouteNames.addplayer,
                  path: 'addPlayer',
                  builder: ((context, state) => const PlayerAddPage()))
            ]),
        GoRoute(
            name: RouteNames.create,
            path: '/create',
            builder: ((context, state) => const CreateRoom())),
        GoRoute(
            name: RouteNames.join,
            path: '/join',
            builder: ((context, state) => const JoinRoom())),
        GoRoute(
            name: RouteNames.result,
            path: '/result',
            builder: ((context, state) => const ResultPage())),
      ]);

  void dispose() {
    router.dispose();
  }
}
