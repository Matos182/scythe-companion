// SPDX-License-Identifier: MIT

/// One-shot combat start cue (T5.7): heavy haptic + original local cry.
///
/// Widgets never call this. The composition root in `main.dart` fires it
/// from the guarded listener when [RoomNotifier] reports a transition
/// into combat — same consume-flag pattern as the your-turn alert (T5.5).
library;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

/// Plays the factory-klaxon cry bundled at `assets/sounds/combat_cry.wav`.
/// Tests subclass and override [fire] so the method channel is never hit.
class CombatCue {
  CombatCue({AudioPlayer? player}) : _player = player;

  AudioPlayer? _player;

  /// Heavy haptic + one short local cue. Never loops. Failures (missing
  /// plugin in the Dart test VM) are swallowed so the overlay still shows.
  Future<void> fire() async {
    try {
      await HapticFeedback.heavyImpact();
    } catch (_) {
      // Tests / unsupported host.
    }
    try {
      _player ??= AudioPlayer();
      await _player!.setReleaseMode(ReleaseMode.stop);
      await _player!.play(
        AssetSource('sounds/combat_cry.wav'),
        mode: PlayerMode.lowLatency,
      );
    } catch (_) {
      // Missing plugin or asset in tests — haptic already ran.
    }
  }

  Future<void> dispose() async {
    try {
      await _player?.dispose();
    } catch (_) {}
    _player = null;
  }
}
