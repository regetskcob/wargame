import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../game/game_mode.dart';
import '../game/game_phase.dart';
import '../game/space_game.dart';
import '../game_config.dart';
import '../net/payloads/defense_payload.dart';

/// Mirrors a running round into a Live Activity on iOS: the lock screen and
/// the Dynamic Island show the countdown, the tanks still standing, the own
/// armour and kills, in a defense round the wave and the base. The native
/// side lives in `ios/Runner/LiveActivityPlugin.swift`. Does nothing on
/// other platforms, and every call fails quietly.
class LiveActivityBridge {
  LiveActivityBridge(this.game);

  final SpaceGame game;

  static const _channel = MethodChannel('wargame/live_activity');

  /// ActivityKit rations updates; the armour changes with every hit.
  static const _throttle = Duration(seconds: 1);

  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  var _running = false;
  Timer? _pending;
  DateTime _lastSent = DateTime.fromMillisecondsSinceEpoch(0);
  late final List<Listenable> _sources = [
    game.aliveCount,
    game.hpNotifier,
    game.killFeed,
    game.defense,
    game.outcome,
    game.spectatingName,
  ];

  void attach() {
    if (!supported) {
      return;
    }
    game.phase.addListener(_onPhase);
    for (final source in _sources) {
      source.addListener(_schedule);
    }
    _onPhase();
  }

  void detach() {
    if (!supported) {
      return;
    }
    game.phase.removeListener(_onPhase);
    for (final source in _sources) {
      source.removeListener(_schedule);
    }
    _pending?.cancel();
    if (_running) {
      _running = false;
      unawaited(_invoke('end', {'state': _state(), 'linger': false}));
    }
  }

  void _onPhase() {
    switch (game.phase.value) {
      case GamePhase.countdown:
        // A fresh round: start over, even if the last one still shows.
        _running = true;
        unawaited(
          _invoke('start', {
            'room': game.net.room,
            'pilot': game.myName,
            'mode': game.mode.value.name,
            'map': game.mapName.value,
            'state': _state(),
          }),
        );
      case GamePhase.playing || GamePhase.spectating:
        if (!_running) {
          _running = true;
          unawaited(
            _invoke('start', {
              'room': game.net.room,
              'pilot': game.myName,
              'mode': game.mode.value.name,
              'map': game.mapName.value,
              'state': _state(),
            }),
          );
        } else {
          _send();
        }
      case GamePhase.roundOver:
        if (_running) {
          // The result stays on the lock screen for a while.
          _running = false;
          _pending?.cancel();
          unawaited(_invoke('end', {'state': _state(), 'linger': true}));
        }
      case GamePhase.lobby || GamePhase.closed:
        if (_running) {
          _running = false;
          _pending?.cancel();
          unawaited(_invoke('end', {'state': _state(), 'linger': false}));
        }
    }
  }

  void _schedule() {
    if (!_running || _pending != null) {
      return;
    }
    final wait = _throttle - DateTime.now().difference(_lastSent);
    _pending = Timer(wait.isNegative ? Duration.zero : wait, () {
      _pending = null;
      _send();
    });
  }

  void _send() {
    if (!_running) {
      return;
    }
    _lastSent = DateTime.now();
    unawaited(_invoke('update', {'state': _state()}));
  }

  Map<String, Object?> _state() {
    final round = game.round;
    final defense = game.defense.value;
    final defending = game.mode.value == GameMode.defense && defense != null;
    // CPU tanks are listed among the participants already.
    final total = round?.participants.length ?? game.aliveCount.value;
    return {
      'phase': game.phase.value.name,
      'startsAt': round?.startedAt ?? 0,
      'alive': game.aliveCount.value,
      'total': total < game.aliveCount.value ? game.aliveCount.value : total,
      'hp': game.myMaxHp <= 0
          ? 0.0
          : (game.hpNotifier.value / game.myMaxHp).clamp(0.0, 1.0),
      'kills': game.roundStats.kills,
      'spectating': game.spectatingName.value,
      'wave': defending ? defense.wave : 0,
      'waves': GameConfig.defenseWaves,
      'baseHp': defending
          ? (defense.hp / GameConfig.baseMaxHp(defense.hq)).clamp(0.0, 1.0)
          : 0.0,
      'nextWaveAt': defending && defense.result == DefenseResult.running
          ? defense.nextWaveAt
          : 0,
      'outcome': game.outcome.value.name,
      'winner': game.winnerName.value,
    };
  }

  Future<void> _invoke(String method, Map<String, Object?> args) async {
    try {
      await _channel.invokeMethod<void>(method, args);
    } on Object {
      return;
    }
  }
}
