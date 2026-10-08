import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tvos/flutter_tvos.dart';

import '../game/bot_level.dart';
import '../game/game_mode.dart';
import '../game/game_phase.dart';
import '../game/tank_game.dart';
import '../net/pad_link.dart';

/// Whether this is the Apple TV build. Always false elsewhere, also in the
/// browser, where `dart:io` has no platform to ask.
bool get onTv => !kIsWeb && FlutterTvosPlatform.isTvos;

/// What steers on the Apple TV right now.
enum TvPadKind {
  /// Nothing GameController knows of, the menus still take the remote.
  none,

  /// The Siri Remote: its touch surface is the stick, the click fires.
  remote,

  /// A controller with two sticks, shoulders and triggers.
  gamepad,
}

/// One reading of the controller in charge, from `GamepadPlugin.swift`.
@immutable
class TvPadState {
  const TvPadState({
    this.kind = TvPadKind.none,
    this.lx = 0,
    this.ly = 0,
    this.rx = 0,
    this.ry = 0,
    this.held = const {},
  });

  factory TvPadState.fromMap(Map<Object?, Object?> map) {
    double axis(String key) => (map[key] as num?)?.toDouble() ?? 0;
    return TvPadState(
      kind: switch (map['kind']) {
        'gamepad' => TvPadKind.gamepad,
        'remote' => TvPadKind.remote,
        _ => TvPadKind.none,
      },
      lx: axis('lx'),
      ly: axis('ly'),
      rx: axis('rx'),
      ry: axis('ry'),
      held: {
        for (final entry in map.entries)
          if (entry.value == true) entry.key! as String,
      },
    );
  }

  final TvPadKind kind;

  /// Left stick, or where the thumb rests on the remote. Up is positive.
  final double lx, ly;

  /// Right stick. Up is positive.
  final double rx, ry;

  /// Buttons held down: a, b, x, y, l1, r1, l2, r2, up, down, left, right.
  final Set<String> held;

  bool operator [](String button) => held.contains(button);
}

/// The controllers of the Apple TV, as the native side reports them.
class TvInput {
  TvInput._();

  static final instance = TvInput._();

  static const _events = EventChannel('wargame/gamepad');
  static const _methods = MethodChannel('wargame/tv');

  /// The kind of the controller in charge, for the hints on screen.
  final kind = ValueNotifier<TvPadKind>(TvPadKind.none);

  /// How many controllers are in, the Siri Remote counted. Two play a duel.
  final count = ValueNotifier<int>(0);

  /// Every controller, those with two sticks first, the remote last.
  var pads = const <TvPadState>[];

  /// The controller in charge: the first one.
  TvPadState get state => player(0);

  /// The controller of [index], the first one for 0. Nothing when there
  /// are fewer.
  TvPadState player(int index) =>
      index < pads.length ? pads[index] : const TvPadState();

  StreamSubscription<Object?>? _sub;
  final _awake = <Object>{};
  bool? _sent;

  /// Starts listening. Does nothing off the Apple TV.
  void start() {
    if (!onTv || _sub != null) {
      return;
    }
    _sub = _events.receiveBroadcastStream().listen((event) {
      if (event is Map) {
        receive(event);
      }
    }, onError: (Object _) {});
  }

  /// Takes one report of the native side: `{pads: [...]}`.
  @visibleForTesting
  void receive(Map<Object?, Object?> event) {
    final list = event['pads'];
    pads = [
      if (list is List)
        for (final pad in list)
          if (pad is Map) TvPadState.fromMap(pad),
    ];
    kind.value = state.kind;
    count.value = pads.length;
  }

  /// Keeps the screen saver away while any [who] wants it, as during a
  /// round. A duel has two games asking.
  void keepAwake(Object who, bool on) {
    if (!onTv) {
      return;
    }
    on ? _awake.add(who) : _awake.remove(who);
    final awake = _awake.isNotEmpty;
    if (_sent == awake) {
      return;
    }
    _sent = awake;
    unawaited(
      _methods.invokeMethod<void>('keepAwake', awake).catchError((Object _) {}),
    );
  }
}

/// Buttons that set off the inventory slots on a controller, in slot order.
const tvGamepadSlotButtons = ['x', 'y', 'left', 'up', 'right', 'down'];

/// Labels of [tvGamepadSlotButtons] on the slots in the HUD.
const tvGamepadSlotLabels = ['X', 'Y', '←', '↑', '→', '↓'];

/// Steers the tank with a controller or the Siri Remote.
///
/// A controller plays like the touch sticks: the left stick points where to
/// drive, the right one aims, R2 or A fire, L2 sets off the special weapon,
/// X, Y and the pad the inventory, R1 builds a gun in a defense round and
/// L1 switches the kind of gun.
///
/// The remote has one surface, so it plays like the watch: where the thumb
/// rests is where the tank drives, the turret aims and fires by itself
/// (the aim assist, which hard switches off), and a click fires the gun.
/// Play/pause sets off the special weapon, without one the first item and
/// without that builds a gun in a defense round.
class TvSteering {
  TvSteering(this._game);

  final TankGame _game;
  var _before = const TvPadState();
  var _active = false;

  /// Stick travel that counts, below it a resting thumb or a worn stick.
  static const _deadZone = 0.2;

  /// The aim stick needs a clearer push before it takes the turret.
  static const _aimZone = 0.35;

  /// Call every frame.
  void update() {
    if (!onTv) {
      return;
    }
    final game = _game;
    final input = game.touch;
    final phase = game.phase.value;
    TvInput.instance.keepAwake(
      game,
      phase == GamePhase.countdown ||
          phase == GamePhase.playing ||
          phase == GamePhase.spectating,
    );
    final state = TvInput.instance.player(game.tvPlayer);
    final before = _before;
    _before = state;
    // A paired phone steers instead: its sticks must not be overwritten.
    final phone =
        PadScreen.instance.paired.value != null &&
        identical(PadScreen.instance.game, game);
    if (phase != GamePhase.playing ||
        game.myTank == null ||
        phone ||
        state.kind == TvPadKind.none) {
      if (_active) {
        _active = false;
        input
          ..drive = null
          ..aimHeld = false
          ..aimFire = false
          ..fire = false
          ..special = false;
      }
      return;
    }
    _active = true;
    bool pressed(String button) => state[button] && !before[button];
    final hard = game.difficulty == BotLevel.hard;
    final defense = game.mode.value == GameMode.defense;
    switch (state.kind) {
      case TvPadKind.gamepad:
        input
          ..drive = stick(state.lx, state.ly, _deadZone)
          ..fire = state['r2'] || state['a']
          ..special = state['l2']
          ..assist = !hard;
        final aim = stick(state.rx, state.ry, _aimZone);
        input.aimHeld = aim != null;
        if (aim != null) {
          input.aim = atan2(aim.$1, -aim.$2);
        }
        for (var slot = 0; slot < tvGamepadSlotButtons.length; slot++) {
          if (pressed(tvGamepadSlotButtons[slot])) {
            game.useItem(slot);
          }
        }
        if (defense && pressed('r1')) {
          game.buildTower();
        }
        if (defense && pressed('l1')) {
          game.cycleTowerKind();
        }
      case TvPadKind.remote:
        final armed = game.specialNotifier.value != null;
        input
          ..drive = stick(state.lx, state.ly, _deadZone)
          ..aimHeld = false
          ..assist = !hard
          ..fire = state['a']
          ..special = armed && state['x'];
        if (!armed && pressed('x')) {
          if (game.inventory.value.isNotEmpty) {
            game.useItem(0);
          } else if (defense) {
            game.buildTower();
          }
        }
      case TvPadKind.none:
    }
  }

  /// A stick as a screen direction, y pointing down, or null inside [zone].
  @visibleForTesting
  static (double, double)? stick(double x, double y, double zone) {
    final length = sqrt(x * x + y * y);
    if (length < zone) {
      return null;
    }
    final scale = min(1.0, length) / length;
    return (x * scale, -y * scale);
  }
}

/// What the Menu button of the remote, or B on a controller, does: one step
/// back. False where there is no step back, and the Apple TV goes home.
bool tvBack(TankGame game) {
  switch (game.phase.value) {
    case GamePhase.countdown:
    case GamePhase.playing:
    case GamePhase.spectating:
      // A round cannot be paused for the others: B or a stray press on
      // Menu must not throw the player out.
      return true;
    case GamePhase.roundOver:
      game.backToLobby();
      return true;
    case GamePhase.closed:
      unawaited(game.backToStart());
      return true;
    case GamePhase.lobby:
      if (game.configuring.value) {
        game.closeSettings();
        return true;
      }
      if (!game.choosingMode.value && game.isHost.value) {
        game.changeMode();
        return true;
      }
      return false;
  }
}
