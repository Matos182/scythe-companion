// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../data/game_repository.dart';
import '../domain/models/player.dart';
import '../provider/room_notifier.dart';
import '../ui/panel_card.dart';
import '../ui/theme.dart';
import '../utils/qr_payload.dart';
import '../utils/strings.dart';

class LobbyPage extends StatefulWidget {
  const LobbyPage({super.key});

  @override
  State<LobbyPage> createState() => _LobbyPageState();
}

class _LobbyPageState extends State<LobbyPage> {
  List<Widget> _buildQrSection(String serverUrl, String roomCode) {
    final payload = encodeJoin(JoinPayload(
      server: serverUrl,
      roomCode: roomCode,
    ));
    return [
      const SizedBox(height: 16),
      Container(
        padding: const EdgeInsets.all(8),
        color: ScytheColors.parchment,
        child: QrImageView(
          key: ValueKey('qr:$payload'),
          data: payload,
          version: QrVersions.auto,
          size: 180,
          backgroundColor: ScytheColors.parchment,
          dataModuleStyle: const QrDataModuleStyle(
            color: ScytheColors.coal,
          ),
          eyeStyle: const QrEyeStyle(color: ScytheColors.coal),
        ),
      ),
      const SizedBox(height: 8),
      const Text(
        'Scan to join',
        style: TextStyle(
          color: ScytheColors.parchmentDim,
          fontStyle: FontStyle.italic,
          fontSize: 12,
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<RoomNotifier>();
    final room = notifier.room;
    final isCreator = notifier.isCreator;
    final repository = context.read<GameRepository>();
    final serverUrl = repository.currentServerUrl;
    final roomCode = room.id;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'Waiting for Players...',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: ScytheColors.parchment,
            fontSize: 20,
          ),
        ),
        const SizedBox(height: 50),
        SizedBox(
          width: double.infinity,
          child: PanelCard(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
            child: SelectableText(
              roomCode.isEmpty ? '—' : roomCode,
              key: const ValueKey('lobby-room-code'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: ScytheColors.brass,
                fontWeight: FontWeight.w700,
                fontSize: 22,
                letterSpacing: 6,
              ),
            ),
          ),
        ),
        if (roomCode.isNotEmpty && serverUrl != null)
          ..._buildQrSection(serverUrl, roomCode),
        if (room.players.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Text(
              EmptyStateStrings.noPlayers,
              style: TextStyle(
                fontStyle: FontStyle.italic,
                color: ScytheColors.parchmentDim,
              ),
            ),
          ),
        DataTable(
          dataRowMaxHeight: 35,
          dataRowMinHeight: 20,
          columnSpacing: 40,
          columns: const <DataColumn>[
            DataColumn(label: Center(widthFactor: 0.7, child: Text('Name'))),
            DataColumn(
              label: Center(widthFactor: 0.8, child: Text('Faction')),
            ),
            DataColumn(label: Center(widthFactor: 0.5, child: Text('Mat'))),
            // T5.4: remove affordance column — empty header, only
            // creators get cells in it.
            DataColumn(label: Text('')),
          ],
          rows: room.players.map<DataRow>((player) {
            final displayName = player.connected
                ? player.nickname
                : '${player.nickname} ${GameStrings.offlineSuffix}';
            return DataRow(
              cells: <DataCell>[
                DataCell(
                  Text(
                    displayName,
                    textAlign: TextAlign.center,
                    style: player.connected
                        ? null
                        : const TextStyle(color: ScytheColors.disabled),
                  ),
                ),
                DataCell(
                  Text(
                    player.playerfaction,
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      color: player.connected ? null : ScytheColors.disabled,
                    ),
                  ),
                ),
                DataCell(
                  Text(
                    player.playermat,
                    style: player.connected
                        ? null
                        : const TextStyle(color: ScytheColors.disabled),
                  ),
                ),
                if (isCreator)
                  DataCell(
                    // Only for disconnected players — the server enforces
                    // the same rule (STATE_PLAYER_CONNECTED).
                    player.connected
                        ? const SizedBox.shrink()
                        : IconButton(
                            key: ValueKey('lobby-remove-${player.id}'),
                            visualDensity: VisualDensity.compact,
                            iconSize: 18,
                            padding: EdgeInsets.zero,
                            tooltip: 'Remove player',
                            icon: const Icon(
                              Icons.person_remove,
                              color: ScytheColors.danger,
                            ),
                            onPressed: () =>
                                _confirmRemove(context, notifier, player),
                          ),
                  )
                else
                  const DataCell(SizedBox.shrink()),
              ],
            );
          }).toList(),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(7, 50, 7, 7),
          child: ElevatedButton(
            onPressed: notifier.isCreator ? notifier.startGame : null,
            style: const ButtonStyle(
              fixedSize: WidgetStatePropertyAll(Size(190, 60)),
            ),
            child: const Text('Start Game'),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmRemove(
    BuildContext context,
    RoomNotifier notifier,
    Player player,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove player'),
        content: Text(
          'Remove ${player.nickname} and free their faction/mat for '
          'someone else?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      notifier.removePlayer(player.id);
    }
  }
}
