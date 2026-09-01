// SPDX-License-Identifier: MIT

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../data/socket_service.dart';
import '../models/route_const.dart';
import '../provider/room_notifier.dart';
import '../utils/colors.dart';
import '../utils/strings.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/scrollable_center_column.dart';
import '../widgets/turn.dart';
import '../widgets/waiting_lobby.dart';

/// Multiplayer game screen (T3.3).
///
/// Rebuilt on the T3.1 state layer. Rules (AGENTS.md + 02_ARCHITECTURE
/// "Connection lifecycle"):
/// - All Socket/Repository access goes through [RoomNotifier] — no widget
///   imports `GameRepository`/`SocketService` directly (so the page is
///   trivially testable through a FakeSocketAdapter + injected notifier).
/// - The 1-second tick drives a narrow [Selector] sub-tree only — the
///   rest of the page (structural data, presence table, action bar)
///   doesn't rebuild every second.
/// - wakelock_plus is enabled while THIS device is seated (turns and
///   the in-progress game need an awake screen) and released on dispose.
class GamePage extends StatefulWidget {
  const GamePage({super.key});

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  // T3.4: "your turn" notifications are fired from the composition root
  // (main.dart's guarded listener) when the app is backgrounded. The
  // wakelock below keeps the screen on during your own turn, which only
  // helps while the app is foregrounded.
  bool _leaveConfirmationOpen = false;
  bool _allowPop = false;

  @override
  void initState() {
    super.initState();
    // Enable here, not on every rebuild — wakelock_plus is idempotent
    // for our purposes (refcount-based) but clearer to call once per
    // mount. dispose() mirrors with disable().
    WakelockPlus.enable();
  }

  @override
  void dispose() {
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
    // PopScope registers canPop during build. Wait for that rebuild before
    // the explicit AppBar leave action performs its existing Navigator.pop.
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
    // Show the banner for anything-not-fully-connected once the socket
    // has reached the connecting/connected lifecycle at least once —
    // we don't want it flashing during the first connect, but a drop
    // or a permanent disconnect must be loud.
    final showOfflineBanner =
        connectionState == SocketConnectionState.reconnecting ||
            connectionState == SocketConnectionState.disconnected;

    return PopScope<void>(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, result) {
        unawaited(_confirmSystemLeave(didPop));
      },
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          backgroundColor: bgColorBar,
          title: const Text(
            GameStrings.title,
            style: TextStyle(color: buttonTextColor),
          ),
          centerTitle: true,
          actions: [
            _PauseResumeAction(isMyTurn: isMyTurn, isPaused: room.isPaused),
            // T3.5: leave button (T3.5 confirm-leave dialog). Sits
            // next to the pause/resume action so a mid-turn exit is
            // explicit, not accidental.
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
              child: room.isJoin
                  ? const LobbyPage()
                  : _ActiveGameView(formatTime: _formatTime),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────

/// Orange strip telling the user the socket is unhappy. D5/triage:
/// keep this opinionated — a friend re-joining mid-turn needs the
/// affordance. Copy now lives in [ConnectionStrings] (T3.5) so it
/// shares a vocabulary with the rest of the app.
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
    return Container(
      width: double.infinity,
      color: Colors.orange.shade800,
      padding: const EdgeInsets.all(6),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white),
      ),
    );
  }
}

/// Pause/resume button in the AppBar. Gated on [isMyTurn] — only the
/// current player decides to pause their own turn. When it isn't my
/// turn the button is rendered disabled for visual completeness.
class _PauseResumeAction extends StatelessWidget {
  const _PauseResumeAction({required this.isMyTurn, required this.isPaused});

  final bool isMyTurn;
  final bool isPaused;

  @override
  Widget build(BuildContext context) {
    final notifier = context.read<RoomNotifier>();
    if (isMyTurn && isPaused) {
      return IconButton(
        icon: const Icon(Icons.play_arrow, color: buttonTextColor, size: 30),
        onPressed: notifier.resume,
      );
    }
    if (isMyTurn) {
      return IconButton(
        icon: const Icon(Icons.pause, color: buttonTextColor, size: 30),
        onPressed: notifier.pause,
      );
    }
    return const IconButton(
      icon: Icon(Icons.play_arrow, color: unavailableColor, size: 30),
      onPressed: null,
    );
  }
}

/// The in-progress (post-start) game view: banner + countdown + pass
/// button + presence table. Pure layout — owns no listeners, reads
/// from the notifier through [TurnCountdown] (tick) and the regular
/// Provider.watch (everything else).
class _ActiveGameView extends StatelessWidget {
  const _ActiveGameView({required this.formatTime});

  final String Function(int) formatTime;

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<RoomNotifier>();
    final room = notifier.room;

    return ScrollableCenterColumn(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 50),
          child: FittedBox(
            child: Text(
              "${room.turn.nickname}'s Turn  -  Round: ${room.totalTurns}",
              style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold,
                color: bgColorBar,
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
              color: bgColorBar,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 5, 20, 10),
          // Selector: rebuild ONLY when the active player's remaining
          // seconds change (T3.1 hand-off debt item 4). The outer
          // page keeps watching the notifier for structural events
          // (turn swap, pause, presence) without tearing down this
          // subtree every tick.
          child: Selector<RoomNotifier, int>(
            selector: (_, n) {
              final r = n.room;
              if (r.players.isEmpty ||
                  r.turnIndex < 0 ||
                  r.turnIndex >= r.players.length) {
                return 0;
              }
              return r.players[r.turnIndex].remainingSec;
            },
            builder: (_, remaining, __) => Text(
              formatTime(remaining),
              style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold,
                color: bgColorBar,
              ),
            ),
          ),
        ),
        room.isPaused
            ? const ElevatedButton(
                onPressed: null,
                style: ButtonStyle(
                  elevation: WidgetStatePropertyAll(7),
                  backgroundColor: WidgetStatePropertyAll(unavailableColor),
                  foregroundColor: WidgetStatePropertyAll(yourTurnText),
                  fixedSize: WidgetStatePropertyAll(Size(250, 70)),
                ),
                child: Text(
                  'GAME IS PAUSED!',
                  style: TextStyle(fontSize: 18),
                ),
              )
            : const TurnPage(),
        Padding(
          padding: const EdgeInsets.fromLTRB(5, 50, 10, 10),
          child: _PlayersTable(formatTime: formatTime),
        ),
      ],
    );
  }
}

/// Per-player remainingSec + presence row. Uses context.watch on the
/// notifier — Selector would be ideal but TurnState.turnIndex changes
/// don't broadcast a per-player delta on their own; the whole table
/// rebuilding is fine because it's bounded (≤ 7 rows) and only fires
/// on real server events, not every tick.
class _PlayersTable extends StatelessWidget {
  const _PlayersTable({required this.formatTime});

  final String Function(int) formatTime;

  @override
  Widget build(BuildContext context) {
    final players = context.watch<RoomNotifier>().room.players;
    return DataTable(
      dataRowMaxHeight: 25,
      dataRowMinHeight: 20,
      columnSpacing: 40,
      headingTextStyle: const TextStyle(color: bgColorBar, fontSize: 14),
      dataTextStyle: const TextStyle(color: bgColorBar, fontSize: 12),
      columns: const [
        DataColumn(
          label: Center(widthFactor: 0.65, child: Text('Name')),
        ),
        DataColumn(
          label: Center(widthFactor: 0.8, child: Text('Timer')),
        ),
      ],
      rows: players.map<DataRow>((player) {
        final displayName = player.connected
            ? player.nickname
            : '${player.nickname} ${GameStrings.offlineSuffix}';
        return DataRow(
          cells: [
            DataCell(Text(displayName, textAlign: TextAlign.center)),
            DataCell(Text(formatTime(player.remainingSec),
                textAlign: TextAlign.center)),
          ],
        );
      }).toList(),
    );
  }
}

/// T3.5: explicit "leave" action in the AppBar. Distinct from the
/// pause/resume icon so the cost is visible. Confirms with the user
/// before tearing down their seat (in-game) or quitting the lobby
/// (pre-game). Lobby uses a softer message because no game state
/// exists yet.
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
      icon: const Icon(Icons.exit_to_app, color: buttonTextColor, size: 26),
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
        // context.read is safe post-confirmation; the navigation guard
        // in main.dart ensures no double-fire, and the navigator key
        // isn't required here (we pop explicitly).
        await context.read<RoomNotifier>().leaveSession();
        if (context.mounted) onReadyToPop();
      },
    );
  }
}
