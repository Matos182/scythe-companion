// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../pages/create.dart';
import '../pages/game.dart';
import '../pages/home.dart';
import '../pages/join.dart';
import '../pages/player_add.dart';
import '../pages/result.dart';
import '../pages/settings.dart';
import '../pages/simple.dart';
import './route_const.dart';

/// Router wiring for the whole app (go_router, D3/E4).
///
/// One nested tree: every destination hangs off the home `/` route so
/// navigating by name still builds a poppable home → destination stack.
/// Navigation is always by *name* (`context.goNamed(RouteNames.x)`) so the
/// paths stay in one place — see `route_const.dart`.
class MyRouter {
  final GoRouter router = GoRouter(
      initialLocation: '/',
      errorPageBuilder: (context, state) => MaterialPage(
          key: state.pageKey,
          child: Scaffold(appBar: AppBar(title: const Text('ERROR')))),
      routes: <RouteBase>[
        GoRoute(
            name: RouteNames.home,
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
                  builder: ((context, state) => const PlayerAddPage())),
              GoRoute(
                  name: RouteNames.create,
                  path: 'create',
                  builder: ((context, state) => const CreateRoom())),
              GoRoute(
                  name: RouteNames.join,
                  path: 'join',
                  builder: ((context, state) => const JoinRoom())),
              GoRoute(
                  name: RouteNames.result,
                  path: 'result',
                  builder: ((context, state) => const ResultPage())),
              GoRoute(
                  name: RouteNames.settings,
                  path: 'settings',
                  builder: ((context, state) => const SettingsPage())),
            ]),
      ]);

  void dispose() {
    router.dispose();
  }
}
