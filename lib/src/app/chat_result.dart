import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../game/game_config.dart';
import '../game/game_mode.dart';
import '../game/game_phase.dart';
import '../game/tank_game.dart';
import '../tv/tv_input.dart';

/// Hands the result of every finished round to the iMessage app on iOS,
/// which offers it in the chat that invited to the room. The native side,
/// `ios/Runner/ChatResultPlugin.swift`, keeps it in the shared app group.
/// Does nothing on other platforms, and every call fails quietly.
class ChatResultBridge {
  ChatResultBridge(this.game);

  final TankGame game;

  static const _channel = MethodChannel('wargame/chat_result');

  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS && !onTv;

  void attach() {
    if (supported) {
      game.phase.addListener(_onPhase);
    }
  }

  void detach() {
    if (supported) {
      game.phase.removeListener(_onPhase);
    }
  }

  void _onPhase() {
    final outcome = game.outcome.value;
    if (game.phase.value != GamePhase.roundOver ||
        outcome == RoundOutcome.none) {
      return;
    }
    final defense = game.defense.value;
    final defending = game.mode.value == GameMode.defense && defense != null;
    unawaited(
      _record({
        'room': game.net.room,
        'pilot': game.myName,
        'mode': game.mode.value.name,
        'won': outcome == RoundOutcome.won,
        'winner': game.winnerName.value,
        'kills': game.roundStats.kills,
        'wave': defending ? defense.wave : 0,
        'waves': GameConfig.defenseWaves,
      }),
    );
  }

  Future<void> _record(Map<String, Object?> result) async {
    try {
      await _channel.invokeMethod<void>('record', result);
    } on Object {
      return;
    }
  }
}
