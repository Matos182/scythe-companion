// SPDX-License-Identifier: MIT

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../data/socket_service.dart';
import '../domain/models/player.dart';
import '../models/route_const.dart';
import '../provider/room_notifier.dart';
import '../ui/theme.dart';
import '../utils/strings.dart';
import '../widgets/combat_overlay.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/scrollable_center_column.dart';
import '../widgets/turn.dart';
import '../widgets/waiting_lobby.dart';

/// Multiplayer lobby and active-game screen.
class GamePage extends StatefulWidget {
  const GamePage({super.key});

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage>
    with SingleTickerProviderStateMixin {
  bool _leaveConfirmationOpen = false;
  bool _allowPop = false;
  RoomNotifier? _pulseNotifier;
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;
  bool _shouldPulse = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _pulseAnimation = Tween<double>(begin: 1, end: 1.06).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOutCubic),
    );
    WakelockPlus.enable();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final notifier = context.read<RoomNotifier>();
    if (identical(notifier, _pulseNotifier)) return;
    _pulseNotifier?.removeListener(_syncCountdownPulse);
    _pulseNotifier = notifier..addListener(_syncCountdownPulse);
    _syncCountdownPulse(rebuild: false);
  }

  void _syncCountdownPulse({bool rebuild = true}) {
    final room = _pulseNotifier?.room;
    var shouldPulse = false;
    if (room != null &&
        !room.isJoin &&
        !room.isPaused &&
        room.turnIndex >= 0 &&
        room.turnIndex < room.players.length) {
      final remaining = room.players[room.turnIndex].remainingSec;
      shouldPulse = remaining >= 0 && remaining <= 30;
    }
    if (shouldPulse == _shouldPulse) return;

    _shouldPulse = shouldPulse;
    if (shouldPulse) {
      _pulseController.repeat(reverse: true);
    } else {
      _pulseController
        ..stop()
        ..value = 0;
    }
    if (rebuild && mounted) setState(() {});
  }

  @override
  void dispose() {
    _pulseNotifier?.removeListener(_syncCountdownPulse);
    _pulseController.dispose();
    WakelockPlus.disable();
    super.dispose();
  }

  Future<void> _confirmSystemLeave(bool didPop) async {
    if (didPop || _allowPop || _leaveConfirmationOpen) return;
    _leaveConfirmationOpen = true;
    try {
      final notifier = context.read<RoomNotifier>();
      final isInGame = !notifier.room.isJoin;
      final confirmed = await confirmLeave(
        context,
        title: isInGame
            ? LeaveDialogStrings.gameTitle
            : LeaveDialogStrings.lobbyTitle,
        message: isInGame
            ? LeaveDialogStrings.gameMessage
            : LeaveDialogStrings.lobbyMessage,
      );
      if (!confirmed || !mounted) return;

      await notifier.leaveSession();
      if (mounted) context.goNamed(RouteNames.home);
    } finally {
      _leaveConfirmationOpen = false;
    }
  }

  void _popAfterExplicitLeave() {
    if (!mounted) return;
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  String _formatTime(int seconds) {
    final duration = Duration(seconds: seconds);
    final negativeSign = duration.isNegative ? '-' : '';
    String two(int n) => n.toString().padLeft(2, '0');
    final mm = two(duration.inMinutes.remainder(60).abs());
    final ss = two(duration.inSeconds.remainder(60).abs());
    return '$negativeSign$mm:$ss';
  }

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<RoomNotifier>();
    final room = notifier.room;
    final isMyTurn = notifier.isMyTurn;
    final connectionState = notifier.connectionState;
    final showOfflineBanner =
        connectionState == SocketConnectionState.reconnecting ||
            connectionState == SocketConnectionState.disconnected ||
            connectionState == SocketConnectionState.protocolMismatch;

    final content = room.isJoin
        ? const KeyedSubtree(
            key: ValueKey('lobby'),
            child: LobbyPage(),
          )
        : KeyedSubtree(
            key: const ValueKey('active-game'),
            child: _ActiveGameView(
              formatTime: _formatTime,
              pulseAnimation: _pulseAnimation,
              shouldPulse: _shouldPulse,
            ),
          );

    return PopScope<void>(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, result) {
        unawaited(_confirmSystemLeave(didPop));
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text(GameStrings.title),
          actions: [
            _PauseResumeAction(isMyTurn: isMyTurn, isPaused: room.isPaused),
            _LeaveAction(
              isInGame: !room.isJoin,
              onReadyToPop: _popAfterExplicitLeave,
            ),
          ],
        ),
        body: Column(
          children: [
            if (showOfflineBanner) _ReconnectBanner(connectionState),
            Expanded(
              child: AnimatedSwitcher(
                key: const ValueKey('lobby-game-switcher'),
                duration: const Duration(milliseconds: 280),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeOutCubic,
                transitionBuilder: (child, animation) {
                  final curved = CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  );
                  return FadeTransition(
                    opacity: curved,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.04),
                        end: Offset.zero,
                      ).animate(curved),
                      child: child,
                    ),
                  );
                },
                child: content,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReconnectBanner extends StatelessWidget {
  const _ReconnectBanner(this.connectionState);

  final SocketConnectionState connectionState;

  @override
  Widget build(BuildContext context) {
    final label = switch (connectionState) {
      SocketConnectionState.reconnecting => ConnectionStrings.reconnecting,
      SocketConnectionState.disconnected => ConnectionStrings.disconnected,
      SocketConnectionState.protocolMismatch =>
        ConnectionStrings.protocolMismatch,
      _ => ConnectionStrings.disconnected,
    };
    final isRetrying = connectionState == SocketConnectionState.reconnecting;
    return Container(
      width: double.infinity,
      color: isRetrying ? ScytheColors.warning : ScytheColors.danger,
      padding: const EdgeInsets.all(6),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: isRetrying ? ScytheColors.coal : ScytheColors.parchment,
        ),
      ),
    );
  }
}

class _PauseResumeAction extends StatelessWidget {
  const _PauseResumeAction({required this.isMyTurn, required this.isPaused});

  final bool isMyTurn;
  final bool isPaused;

  @override
  Widget build(BuildContext context) {
    final notifier = context.read<RoomNotifier>();
    if (isMyTurn && isPaused) {
      return IconButton(
        icon: const Icon(Icons.play_arrow, size: 30),
        onPressed: notifier.resume,
      );
    }
    if (isMyTurn) {
      return IconButton(
        icon: const Icon(Icons.pause, size: 30),
        onPressed: notifier.pause,
      );
    }
    return const IconButton(
      icon: Icon(Icons.play_arrow, color: ScytheColors.disabled, size: 30),
      onPressed: null,
    );
  }
}

class _ActiveGameView extends StatelessWidget {
  const _ActiveGameView({
    required this.formatTime,
    required this.pulseAnimation,
    required this.shouldPulse,
  });

  final String Function(int) formatTime;
  final Animation<double> pulseAnimation;
  final bool shouldPulse;

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<RoomNotifier>();
    final room = notifier.room;
    final turnKey = '${room.turn.id}-${room.totalTurns}';
    final showCombatControl = notifier.isMyTurn && !room.isCombatPause;

    return Stack(
      fit: StackFit.expand,
      children: [
        ScrollableCenterColumn(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 50),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeOutCubic,
                child: FittedBox(
                  key: ValueKey(turnKey),
                  child: Text(
                    "${room.turn.nickname}'s Turn  -  Round: ${room.totalTurns}",
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: ScytheColors.parchment,
                    ),
                  ),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 5),
              child: Text(
                'Turn Time Remaining:',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: ScytheColors.brass,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 5, 20, 10),
              child: Selector<RoomNotifier, int>(
                selector: (_, n) {
                  final currentRoom = n.room;
                  if (currentRoom.players.isEmpty ||
                      currentRoom.turnIndex < 0 ||
                      currentRoom.turnIndex >= currentRoom.players.length) {
                    return 0;
                  }
                  return currentRoom
                      .players[currentRoom.turnIndex].remainingSec;
                },
                builder: (_, remaining, __) => _CountdownDisplay(
                  remaining: remaining,
                  formatted: formatTime(remaining),
                  pulseAnimation: pulseAnimation,
                  shouldPulse: shouldPulse,
                ),
              ),
            ),
            if (room.isPaused && !room.isCombatPause)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                decoration: BoxDecoration(
                  border: Border.all(color: ScytheColors.warning),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  GameStrings.pausedLabel,
                  style: TextStyle(
                    color: ScytheColors.warning,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            else if (!room.isPaused)
              const TurnPage(),
            if (showCombatControl)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Tooltip(
                  message: CombatStrings.startTooltip,
                  child: OutlinedButton(
                    key: const ValueKey('combat-action'),
                    onPressed: notifier.combat,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: ScytheColors.danger,
                      side: const BorderSide(color: ScytheColors.rustDeep),
                      minimumSize: const Size(170, 48),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 22,
                          height: 22,
                          child: CustomPaint(
                            painter: CrossedBladesPainter(
                              fill: ScytheColors.brass,
                              edge: ScytheColors.rustDeep,
                            ),
                          ),
                        ),
                        SizedBox(width: 10),
                        Text(CombatStrings.start),
                      ],
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(5, 50, 10, 10),
              child: _PlayersTable(formatTime: formatTime),
            ),
          ],
        ),
        if (room.isCombatPause)
          const CombatOverlay(key: ValueKey('combat-overlay')),
      ],
    );
  }
}

class _CountdownDisplay extends StatelessWidget {
  const _CountdownDisplay({
    required this.remaining,
    required this.formatted,
    required this.pulseAnimation,
    required this.shouldPulse,
  });

  final int remaining;
  final String formatted;
  final Animation<double> pulseAnimation;
  final bool shouldPulse;

  @override
  Widget build(BuildContext context) {
    final danger = remaining < 10;
    final countdown = AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeOutCubic,
      child: Text(
        formatted,
        key: ValueKey(danger),
        style: TextStyle(
          fontSize: 30,
          fontWeight: FontWeight.bold,
          color: danger ? ScytheColors.danger : ScytheColors.parchment,
        ),
      ),
    );
    if (!shouldPulse) return countdown;
    return ScaleTransition(
      key: const ValueKey('countdown-pulse'),
      scale: pulseAnimation,
      child: countdown,
    );
  }
}

class _PlayersTable extends StatelessWidget {
  const _PlayersTable({required this.formatTime});

  final String Function(int) formatTime;

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<RoomNotifier>();
    final room = notifier.room;
    final isCreator = notifier.isCreator;
    final players = room.players;
    final turnId = room.turn.id;
    return DataTable(
      dataRowMaxHeight: 25,
      dataRowMinHeight: 20,
      columnSpacing: 40,
      columns: const [
        DataColumn(label: Center(widthFactor: 0.65, child: Text('Name'))),
        DataColumn(label: Center(widthFactor: 0.8, child: Text('Timer'))),
        // T5.4: remove affordance column — empty header, only creators
        // get cells in it.
        DataColumn(label: Text('')),
      ],
      rows: players.map<DataRow>((player) {
        final isTurn = player.id == turnId && !room.isJoin;
        final displayName = player.connected
            ? player.nickname
            : '${player.nickname} ${GameStrings.offlineSuffix}';
        return DataRow(
          // T5.4: highlight whose turn it is — glanceable from across a
          // table without reading the banner.
          color: isTurn
              ? WidgetStateProperty.all(
                  ScytheColors.brass.withValues(alpha: 0.18),
                )
              : null,
          cells: [
            DataCell(
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isTurn) ...[
                    const Icon(
                      Icons.hourglass_bottom,
                      size: 13,
                      color: ScytheColors.brass,
                    ),
                    const SizedBox(width: 4),
                  ],
                  Flexible(
                    child: Text(
                      displayName,
                      textAlign: TextAlign.center,
                      style: isTurn
                          ? const TextStyle(
                              color: ScytheColors.brass,
                              fontWeight: FontWeight.bold,
                            )
                          : null,
                    ),
                  ),
                ],
              ),
            ),
            DataCell(
              Text(
                formatTime(player.remainingSec),
                textAlign: TextAlign.center,
                style: isTurn
                    ? const TextStyle(
                        color: ScytheColors.brass,
                        fontWeight: FontWeight.bold,
                      )
                    : null,
              ),
            ),
            if (isCreator)
              DataCell(
                // Only ever offered for disconnected players — the
                // server enforces the same rule (STATE_PLAYER_CONNECTED).
                player.connected
                    ? const SizedBox.shrink()
                    : IconButton(
                        key: ValueKey('remove-player-${player.id}'),
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

class _LeaveAction extends StatelessWidget {
  const _LeaveAction({
    required this.isInGame,
    required this.onReadyToPop,
  });

  final bool isInGame;
  final VoidCallback onReadyToPop;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: const ValueKey('leave-action'),
      icon: const Icon(Icons.exit_to_app, size: 26),
      tooltip: LeaveDialogStrings.confirmLabel,
      onPressed: () async {
        final confirmed = await confirmLeave(
          context,
          title: isInGame
              ? LeaveDialogStrings.gameTitle
              : LeaveDialogStrings.lobbyTitle,
          message: isInGame
              ? LeaveDialogStrings.gameMessage
              : LeaveDialogStrings.lobbyMessage,
        );
        if (!confirmed || !context.mounted) return;
        await context.read<RoomNotifier>().leaveSession();
        if (context.mounted) onReadyToPop();
      },
    );
  }
}
