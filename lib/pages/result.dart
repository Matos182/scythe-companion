// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../domain/winner.dart';
import '../models/players.dart';
import '../provider/room_data_provider.dart';
import '../ui/panel_card.dart';
import '../ui/theme.dart';

/// [ResultPage] displays the final results of the Scythe Coin Calculator.
/// Shows the winner(s) — including ties — and a sorted score table.

class ResultPage extends StatefulWidget {
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
    final List<ScoreEntry> results = _roomDataProvider.players
        .where((player) => player.name.isNotEmpty)
        .toSet()
        .toList();

    final ranked = rankScores(results);
    final winners = findWinners(results);

    final String winnerText;
    if (winners.isEmpty) {
      winnerText = 'No results';
    } else if (winners.length == 1) {
      winnerText = 'Winner: ${winners.first.name} (${winners.first.result})';
    } else {
      final names = winners.map((w) => w.name).join(', ');
      winnerText = 'Tie! $names (${winners.first.result} each)';
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scythe Coin Calculator'),
        actions: [
          IconButton(
            icon: const Icon(Icons.home_rounded),
            tooltip: 'Home',
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
              winnerText,
              style: const TextStyle(
                color: ScytheColors.brass,
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            )),
            const SizedBox(height: 20),
            if (ranked.isNotEmpty) ...[
              Padding(
                  padding: const EdgeInsets.all(8),
                  child: PanelCard(
                    padding: const EdgeInsets.all(8),
                    child: Table(
                      border: TableBorder.all(
                        color: ScytheColors.seam,
                        style: BorderStyle.solid,
                      ),
                      children: [
                        _buildTableRow(
                          header: true,
                          children: const [
                            '#',
                            'Name',
                            'Pop',
                            'Stars',
                            'Lands',
                            'Res',
                            'Coins',
                            'Bldg',
                            'TOTAL',
                          ],
                        ),
                        for (var r in ranked)
                          _buildTableRow(children: [
                            '${r.rank}',
                            r.entry.name,
                            r.entry.popularity.toString(),
                            r.entry.stars.toString(),
                            r.entry.lands.toString(),
                            r.entry.resources.toString(),
                            r.entry.coins.toString(),
                            r.entry.buildings.toString(),
                            r.entry.result.toString(),
                          ]),
                      ],
                    ),
                  ))
            ] else
              const Text('No results found'),
          ],
        ),
      ),
    );
  }

  TableRow _buildTableRow({
    required List<String> children,
    bool header = false,
  }) {
    final textStyle = TextStyle(
      color: header ? ScytheColors.brass : ScytheColors.parchment,
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
