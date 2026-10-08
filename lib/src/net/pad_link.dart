import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../game/bot_level.dart';
import '../game/game_mode.dart';
import '../game/tank_game.dart';
import '../game/touch_input.dart';
import 'payloads/pad_payload.dart';
import 'room.dart';

/// Pairing a phone as the gamepad of the game on a computer or tablet.
///
/// The screen opens a channel of its own under a fresh code and shows it as
/// a QR code. The phone scans it, joins the same channel and sends what its
/// sticks hold many times a second. The screen plays that as its own touch
/// controls and sends back how the tank is doing. Presence tells either side
/// whether the other is still there. Nothing of this goes through the room:
/// the other players never see the phone.

const _alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

/// Length of a pairing code, longer than a room code: whoever knows it
/// steers the tank.
const padCodeLength = 8;

String newPadCode() {
  final random = Random.secure();
  return [
    for (var i = 0; i < padCodeLength; i++)
      _alphabet[random.nextInt(_alphabet.length)],
  ].join();
}

/// Reads a pairing code from what was typed or scanned: the bare code, or a
/// link with `?pad=CODE`. Null when neither fits.
String? padCodeFrom(String text) {
  final trimmed = text.trim();
  final uri = Uri.tryParse(trimmed);
  final candidate = uri != null && uri.hasScheme
      ? uri.queryParameters['pad'] ?? ''
      : trimmed;
  // Gaps, dashes and whatever invisible marks a keyboard or the clipboard
  // slips in fall away.
  final code = candidate.toUpperCase().replaceAll(RegExp('[^A-Z0-9]'), '');
  return _code.hasMatch(code) ? code : null;
}

final _code = RegExp('^[$_alphabet]{$padCodeLength}\$');

/// Link the QR code carries: the browser game with the code in the
/// address, built like the room links. The camera of a phone with the app
/// opens the app, any other phone the game in its browser, as a controller
/// either way.
String padLink(String code) =>
    Uri.parse(roomLink('-')).replace(queryParameters: {'pad': code}).toString();

/// The code split in halves, easier to read off and type.
String spacedPadCode(String code) =>
    '${code.substring(0, code.length ~/ 2)} '
    '${code.substring(code.length ~/ 2)}';

enum _Event { pad, act, status }

/// The side both ends share: one Broadcast channel per code, with presence
/// to see the other end.
abstract class _PadChannel {
  _PadChannel(this.role, [this._ownClient]);

  /// `screen` or `pad`, tracked in the presence.
  final String role;

  final id = [
    for (var i = 0; i < 16; i++) Random().nextInt(16).toRadixString(16),
  ].join();

  RealtimeChannel? _channel;
  final _subscriptions = <StreamSubscription<void>>[];
  Timer? _retry;
  String? _code;
  String _name = '';

  final SupabaseClient? _ownClient;

  SupabaseClient get _client => _ownClient ?? Supabase.instance.client;

  /// Joins the channel of [code] and keeps rejoining it after a drop.
  Future<void> _connect(String code, String name) async {
    await _leave();
    _code = code;
    _name = name;
    final channel = _client.channel(
      'pad-$code',
      options: const RealtimeChannelConfig(self: false),
    );
    _channel = channel;
    for (final event in _Event.values) {
      _subscriptions.add(
        channel.onBroadcast(event: event.name).listen((json) {
          // Anybody on the channel can send anything: what does not parse
          // is dropped.
          try {
            _receive(event, json);
          } on Object catch (error) {
            debugPrint('Dropped pad ${event.name}: $error');
          }
        }),
      );
    }
    void sync() => _peersChanged([
      for (final state in channel.presenceState())
        for (final presence in state.presences)
          if (presence.payload['role'] is String &&
              presence.payload['role'] != role &&
              presence.payload['id'] is String)
            (
              presence.payload['id'] as String,
              presence.payload['name'] is String
                  ? presence.payload['name'] as String
                  : '',
            ),
    ]);
    _subscriptions
      ..add(channel.onPresenceSync.listen((_) => sync()))
      ..add(channel.onPresenceJoin.listen((_) => sync()))
      ..add(channel.onPresenceLeave.listen((_) => sync()))
      ..add(
        channel.onStatusChange.listen((change) async {
          if (change.status == RealtimeSubscribeStatus.subscribed) {
            await channel.track({'role': role, 'id': id, 'name': _name});
          } else if (change.status == RealtimeSubscribeStatus.channelError ||
              change.status == RealtimeSubscribeStatus.closed) {
            _scheduleRetry();
          }
        }),
      );
    channel.subscribe();
  }

  void _scheduleRetry() {
    final code = _code;
    if (code == null || _retry != null) {
      return;
    }
    _retry = Timer(const Duration(seconds: 2), () {
      _retry = null;
      if (_code == code) {
        unawaited(_connect(code, _name));
      }
    });
  }

  void _send(_Event event, Map<String, dynamic> payload) {
    final channel = _channel;
    if (channel != null) {
      unawaited(
        channel.sendBroadcastMessage(event: event.name, payload: payload),
      );
    }
  }

  Future<void> _leave() async {
    _retry?.cancel();
    _retry = null;
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    final channel = _channel;
    _channel = null;
    if (channel != null) {
      await _client.removeChannel(channel);
    }
  }

  /// Leaves the channel for good.
  Future<void> _close() async {
    _code = null;
    await _leave();
  }

  void _receive(_Event event, Map<String, dynamic> json);

  /// Ids and names of the other end's presences.
  void _peersChanged(List<(String, String)> peers);
}

/// The computer or tablet the game runs on, waiting for a phone or steered
/// by one. One for the whole page: the pairing outlives a new room.
class PadScreen extends _PadChannel {
  PadScreen._() : super('screen');

  static final instance = PadScreen._();

  /// Code of the open pairing, null while there is none.
  final code = ValueNotifier<String?>(null);

  /// Name of the phone that steers, null while none is paired.
  final paired = ValueNotifier<String?>(null);

  /// The game the phone steers. Set by the app shell, also for a new room.
  TankGame? game;

  String? _padId;
  Timer? _tick;
  DateTime _lastInput = DateTime(0);
  String? _lastStatus;
  DateTime _lastStatusAt = DateTime(0);

  /// The phone stops counting when nothing came from it for this long, so a
  /// tank whose phone dropped out does not drive on by itself.
  static const _silence = Duration(milliseconds: 900);

  TouchInput? get _input => game?.touch;

  /// Opens a pairing, or takes up the one from before a reload.
  Future<void> open() async {
    final existing = code.value ?? storedPadCode();
    final fresh = existing ?? newPadCode();
    rememberPadCode(fresh);
    code.value = fresh;
    _tick ??= Timer.periodic(
      const Duration(milliseconds: 100),
      (_) => _onTick(),
    );
    await _connect(fresh, 'screen');
  }

  /// Takes up a pairing this page had before it loaded another room.
  Future<void> resume() async {
    if (storedPadCode() != null) {
      await open();
    }
  }

  /// Ends the pairing. The phone sees the screen leave.
  Future<void> close() async {
    rememberPadCode(null);
    code.value = null;
    _tick?.cancel();
    _tick = null;
    _release();
    _padId = null;
    paired.value = null;
    await _close();
  }

  @override
  void _peersChanged(List<(String, String)> peers) {
    final current = peers.where((p) => p.$1 == _padId).firstOrNull;
    if (current != null) {
      paired.value = current.$2;
      return;
    }
    // The first phone takes over, a second one waits until it leaves.
    _release();
    final next = peers.firstOrNull;
    _padId = next?.$1;
    paired.value = next?.$2;
  }

  @override
  void _receive(_Event event, Map<String, dynamic> json) {
    if (json['id'] != _padId || _padId == null) {
      return;
    }
    switch (event) {
      case _Event.pad:
        final pad = PadInput.tryParse(json);
        final input = _input;
        if (pad == null || input == null) {
          return;
        }
        _lastInput = DateTime.now();
        input
          ..drive = pad.drive
          ..aimHeld = pad.aimHeld
          ..aimFire = pad.aimFire
          ..special = pad.special
          ..assist = pad.assist;
        if (pad.aim != null) {
          input.aim = pad.aim;
        }
      case _Event.act:
        final action = PadAction.tryParse(json);
        final game = this.game;
        if (action == null || game == null) {
          return;
        }
        switch (action.kind) {
          case PadActionKind.item:
            game.useItem(action.slot);
          case PadActionKind.build:
            game.buildTower();
          case PadActionKind.cycle:
            game.cycleTowerKind();
        }
      case _Event.status:
    }
  }

  /// Lets go of everything the phone held. The aim stays, as after lifting
  /// the thumb off the touch stick.
  void _release() {
    _input
      ?..drive = null
      ..aimHeld = false
      ..aimFire = false
      ..special = false;
  }

  void _onTick() {
    if (_padId == null) {
      return;
    }
    final now = DateTime.now();
    if (now.difference(_lastInput) > _silence) {
      _release();
    }
    final game = this.game;
    if (game == null) {
      return;
    }
    final status = statusOf(game).toJson();
    final text = status.toString();
    // Changes go out at once, the rest now and then as a sign of life.
    if (text != _lastStatus ||
        now.difference(_lastStatusAt) > const Duration(seconds: 1)) {
      _lastStatus = text;
      _lastStatusAt = now;
      _send(_Event.status, status);
    }
  }

  /// What the phone shows of [game].
  static PadStatus statusOf(TankGame game) {
    final tank = game.myTank;
    final defense = game.mode.value == GameMode.defense;
    final special = game.specialNotifier.value;
    return PadStatus(
      phase: game.phase.value,
      name: game.myName,
      hp: game.myMaxHp <= 0
          ? 0
          : (game.hpNotifier.value / game.myMaxHp).clamp(0, 1),
      ammo: tank?.ammo ?? game.ammoNotifier.value,
      magazine: tank?.magazine ?? game.myMagazine,
      special: special?.$1,
      charges: special?.$2 ?? 0,
      items: [for (final slot in game.inventory.value) (slot.type, slot.count)],
      defense: defense,
      credits: defense ? game.credits.value : 0,
      tower: defense ? game.towerChoice.value : null,
      assist: game.difficulty != BotLevel.hard,
    );
  }
}

/// The phone as a gamepad: sends its sticks to the screen of [code] and
/// hears back how the tank is doing.
class PadRemote extends _PadChannel {
  /// [client] stands in for the app's own, in a test that plays both ends.
  PadRemote(this.code, {SupabaseClient? client}) : super('pad', client);

  final String code;

  /// Written by the touch controls on the phone, read out and sent.
  final input = TouchInput();

  /// What the screen last told about the tank, null until it did.
  final status = ValueNotifier<PadStatus?>(null);

  /// Whether the screen is on the channel.
  final screenOnline = ValueNotifier<bool>(false);

  Timer? _tick;
  String? _lastSent;
  DateTime _lastSentAt = DateTime(0);

  Future<void> start(String name) async {
    _tick ??= Timer.periodic(
      const Duration(milliseconds: 50),
      (_) => _onTick(),
    );
    await _connect(code, name);
  }

  Future<void> stop() async {
    _tick?.cancel();
    _tick = null;
    await _close();
  }

  void act(PadActionKind kind, [int slot = 0]) =>
      _send(_Event.act, PadAction(id: id, kind: kind, slot: slot).toJson());

  void _onTick() {
    if (!screenOnline.value) {
      return;
    }
    final pad = PadInput(
      id: id,
      drive: input.drive,
      aim: input.aim,
      aimHeld: input.aimHeld,
      aimFire: input.aimFire,
      special: input.special,
      assist: input.assist,
    ).toJson();
    final text = pad.toString();
    final now = DateTime.now();
    // About twenty a second while the thumbs move, a few a second to keep
    // the screen from letting go while they rest.
    if (text != _lastSent ||
        now.difference(_lastSentAt) > const Duration(milliseconds: 300)) {
      _lastSent = text;
      _lastSentAt = now;
      _send(_Event.pad, pad);
    }
  }

  @override
  void _peersChanged(List<(String, String)> peers) {
    screenOnline.value = peers.isNotEmpty;
  }

  @override
  void _receive(_Event event, Map<String, dynamic> json) {
    if (event == _Event.status) {
      final parsed = PadStatus.tryParse(json);
      if (parsed != null) {
        status.value = parsed;
      }
    }
  }
}
