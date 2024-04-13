// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../provider/room_data_provider.dart';
import '../utils/colors.dart';
import '../models/players.dart';

/// [ResultPage] displays the final results of the Scythe Coin Calculator.

class ResultPage extends StatefulWidget {
  /// Constructor to initialize [ResultPage] with a list of results.
  const ResultPage({super.key});

  @override
  State<ResultPage> createState() => _ResultPageState();
}

class _ResultPageState extends State<ResultPage> {
  late RoomDataProvider _roomDataProvider;

  @override
  Widget build(BuildContext context) {
    _roomDataProvider = Provider.of<RoomDataProvider>(context, listen: false);
    // Filter out empty or repeated named players
    List<Players> results = _roomDataProvider.players
        .where((player) => player.name.isNotEmpty)
        .toSet()
        .toList();
    // Sort the results list based on the result property in descending order
    results.sort((a, b) => b.result.compareTo(a.result));

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColorBar,
        title: const Text(
          "Scythe Coin Calculator",
          style: TextStyle(color: boxTextColor),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(
              Icons.recycling_rounded,
              color: buttonTextColor,
            ),
            onPressed: () {
              context.go('/');
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            FittedBox(
                child: Text(
              'Final Score - Winner:  ${results.first.name}',
              style: const TextStyle(
                color: bgColorBar,
                fontSize: 24,
              ),
            )),
            const SizedBox(
                height: 20), // Padding some space from the winner and the table
            // Build the dynamic table based on sorted results list
            if (results.isNotEmpty) ...[
              Padding(
                  padding: const EdgeInsets.all(8),
                  child: Table(
                    border: TableBorder.all(
                      color: bgColorBar,
                      style: BorderStyle.solid,
                      width: 3,
                    ),
                    children: [
                      // Table header
                      _buildTableRow(
                        header: true,
                        children: const [
                          'Player Name',
                          'Popularity',
                          'Stars',
                          'Lands',
                          'Resources',
                          'Coins',
                          'Building Coins',
                          'TOTAL COINS',
                        ],
                      ),
                      // Table rows for each Result
                      for (var result in results)
                        _buildTableRow(children: [
                          result.name,
                          result.popularity.toString(),
                          result.stars.toString(),
                          result.lands.toString(),
                          result.resources.toString(),
                          result.coins.toString(),
                          result.buildings.toString(),
                          result.result.toString(),
                        ]),
                    ],
                  ))
            ] else
              const Text('No results found'),
          ],
        ),
      ),
    );
  }

  // Function to build a TableRow with optional header styling
  TableRow _buildTableRow({
    required List<String> children,
    bool header = false,
  }) {
    final textStyle = TextStyle(
      color: bgColorBar,
      fontSize: header ? 12.5 : 11,
      fontWeight: header ? FontWeight.bold : FontWeight.normal,
    );

    return TableRow(
      children: children.map((text) {
        return TableCell(
          child: Container(
            padding: const EdgeInsets.all(4.0),
            child: Center(
              child: Text(
                text,
                style: textStyle,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
