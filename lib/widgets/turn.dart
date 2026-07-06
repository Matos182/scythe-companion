// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../provider/room_notifier.dart';
import '../utils/colors.dart';

class TurnPage extends StatelessWidget {
  const TurnPage({super.key});

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<RoomNotifier>();

    return ElevatedButton(
        onPressed: notifier.isMyTurn
            ? () {
                notifier.passTurn();
              }
            : null,
        style: ButtonStyle(
            elevation: const WidgetStatePropertyAll(7),
            backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
              if (states.contains(WidgetState.disabled)) {
                return unavailableColor; // Disabled color
              }
              return yourTurnColor; // Regular color
            }),
            foregroundColor: const WidgetStatePropertyAll(yourTurnText),
            fixedSize: const WidgetStatePropertyAll(Size(150, 50))),
        child: const Text("Pass Turn"));
  }
}
