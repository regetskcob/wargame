import 'dart:async';
import 'dart:math';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../game/bot_level.dart';
import '../game/game_config.dart';
import '../game/game_mode.dart';
import '../game/tank_game.dart';
import '../game/touch_input.dart';
import 'payloads/pad_payload.dart';
import 'retry_backoff.dart';
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

/// Decides when a stream of snapshots goes out: a change at most every
/// [gap], an unchanged one again after [keepalive] as a sign of life. A
/// change that comes too soon is not lost, it goes out once the gap has
/// passed, as whatever the snapshot is by then. Every message on a pad
/// channel counts twice against the project's Realtime limit, sent and
/// delivered.
class SendGate {
  SendGate({required this.gap, required this.keepalive});

  final Duration gap;
  final Duration keepalive;
  String? _last;
  DateTime? _lastAt;

  bool shouldSend(String snapshot) {
    final now = clock.now();
    final lastAt = _lastAt;
    final since = lastAt == null ? keepalive : now.difference(lastAt);
    if ((snapshot != _last && since >= gap) || since >= keepalive) {
      _last = snapshot;
      _lastAt = now;
      return true;
    }
    return false;
  }
}

/// The code split in halves, easier to read off and type.
String spacedPadCode(String code) =>
    '${code.substring(0, code.length ~/ 2)} '
    '${code.substring(code.length ~/ 2)}';

enum _Event { pad, act, status }

/// The side both ends share: one Broadcast channel per code, with presence
/// to see the other end. Every phone that knows it also gets a lane of its
/// own, `pad-<code>-<phone>`, for its sticks and the screen's status: on the
/// shared channel every message also reached the other phones of a duel,
/// and Realtime counts each delivery. Ends without lanes stay on the shared
/// channel.
abstract class _PadChannel {
  _PadChannel(this.role, [this._ownClient]);

  /// `screen` or `pad`, tracked in the presence.
  final String role;

  final id = [
    for (var i = 0; i < 16; i++) Random().nextInt(16).toRadixString(16),
  ].join();

  RealtimeChannel? _channel;
  final _subscriptions = <StreamSubscription<void>>[];
  final _lanes = <String, RealtimeChannel>{};
  final _laneSubscriptions = <String, List<StreamSubscription<void>>>{};

  /// Ids of the other ends that talk on lanes.
  var _laneIds = <String>{};
  Timer? _retry;
  final _backoff = RetryBackoff();
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
    void sync() {
      final others = [
        for (final state in channel.presenceState())
          for (final presence in state.presences)
            if (presence.payload['role'] is String &&
                presence.payload['role'] != role &&
                presence.payload['id'] is String)
              presence.payload,
      ];
      _laneIds = {
        for (final other in others)
          if (other['lane'] == true) other['id'] as String,
      };
      _peersChanged([
        for (final other in others)
          (
            other['id'] as String,
            other['name'] is String ? other['name'] as String : '',
          ),
      ]);
    }

    _subscriptions
      ..add(channel.onPresenceSync.listen((_) => sync()))
      ..add(channel.onPresenceJoin.listen((_) => sync()))
      ..add(channel.onPresenceLeave.listen((_) => sync()))
      ..add(
        channel.onStatusChange.listen((change) async {
          if (change.status == RealtimeSubscribeStatus.subscribed) {
            _backoff.reset();
            await channel.track({
              'role': role,
              'id': id,
              'name': _name,
              'lane': true,
            });
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
    _retry = Timer(_backoff.next(), () {
      _retry = null;
      if (_code == code) {
        fireAndForget(_connect(code, _name), 'Rejoining pad channel');
      }
    });
  }

  /// Opens the lane [lane] next to the shared channel, once connected.
  void _openLane(String lane) {
    final code = _code;
    if (_channel == null || code == null || _lanes.containsKey(lane)) {
      return;
    }
    final channel = _client.channel(
      'pad-$code-$lane',
      options: const RealtimeChannelConfig(self: false),
    );
    _lanes[lane] = channel;
    _laneSubscriptions[lane] = [
      for (final event in _Event.values)
        channel.onBroadcast(event: event.name).listen((json) {
          // A screen hears only the lane's own phone on it.
          if (role == 'screen' && json['id'] != lane) {
            return;
          }
          try {
            _receive(event, json);
          } on Object catch (error) {
            debugPrint('Dropped pad ${event.name}: $error');
          }
        }),
    ];
    channel.subscribe();
  }

  Future<void> _closeLane(String lane) async {
    for (final subscription in _laneSubscriptions.remove(lane) ?? const []) {
      await subscription.cancel();
    }
    final channel = _lanes.remove(lane);
    if (channel != null) {
      await _client.removeChannel(channel);
    }
  }

  /// Sees every message this end sends and the lane it is meant for (null
  /// for the shared channel), for the tests.
  @visibleForTesting
  void Function(String event, Map<String, dynamic> payload, String? lane)?
  onSend;

  void _send(_Event event, Map<String, dynamic> payload, {String? lane}) {
    onSend?.call(event.name, payload, lane);
    final channel = (lane == null ? null : _lanes[lane]) ?? _channel;
    if (channel != null) {
      fireAndForget(
        channel.sendBroadcastMessage(event: event.name, payload: payload),
        'Sending pad ${event.name}',
      );
    }
  }

  Future<void> _leave() async {
    _retry?.cancel();
    _retry = null;
    for (final lane in _lanes.keys.toList()) {
      await _closeLane(lane);
    }
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
    _backoff.reset();
    await _leave();
  }

  void _receive(_Event event, Map<String, dynamic> json);

  /// Ids and names of the other end's presences.
  void _peersChanged(List<(String, String)> peers);
}

/// The computer, tablet or television the game runs on, waiting for phones
/// or steered by them. One for the whole page: the pairing outlives a new
/// room.
///
/// The first phone steers [game]. Further phones wait, unless a duel on the
/// Apple TV hands them a game of their own with [route]: then two phones on
/// one code steer the two halves.
class PadScreen extends _PadChannel {
  PadScreen._() : super('screen');

  static final instance = PadScreen._();

  /// Code of the open pairing, null while there is none.
  final code = ValueNotifier<String?>(null);

  /// Name of the first phone, the one that steers [game], null while none
  /// is paired.
  final paired = ValueNotifier<String?>(null);

  /// Ids and names of every phone on the code, in the order they came.
  final phones = ValueNotifier<List<(String, String)>>(const []);

  /// The game the first phone steers. Set by the app shell, also for a new
  /// room.
  TankGame? get game => _game;
  set game(TankGame? value) {
    if (identical(value, _game)) {
      return;
    }
    _game?.padSteered.value = false;
    _game = value;
    _updateSteered();
  }

  TankGame? _game;

  /// The Realtime budget had no room for the phones: they wait and steer
  /// nothing until a slot is free. Asked again once a minute.
  final busy = ValueNotifier<bool>(false);
  Timer? _slotTimer;

  final _routes = <String, TankGame>{};
  final _lastInput = <String, DateTime>{};
  final _statusGates = <String, SendGate>{};
  Timer? _tick;

  /// The status changes with every shot and every hit: a few times a second
  /// is plenty for the phone's display.
  static const statusGap = Duration(milliseconds: 250);
  static const statusKeepalive = Duration(seconds: 1);
  static const tickInterval = Duration(milliseconds: 100);

  /// The phone stops counting when nothing came from it for this long, so a
  /// tank whose phone dropped out does not drive on by itself.
  static const _silence = Duration(milliseconds: 900);

  /// The game the phone [padId] steers, null while it waits.
  TankGame? gameOf(String padId) => busy.value ? null : _targetOf(padId);

  /// The game the phone [padId] is meant for, budget or not.
  TankGame? _targetOf(String padId) =>
      _routes[padId] ??
      (phones.value.firstOrNull?.$1 == padId && _routes.isEmpty ? _game : null);

  /// Tells every game whether a phone is paired for it, budget or not, so a
  /// room with a phone plays without CPU tanks and makes room for it.
  void _updateSteered() {
    for (final target in {?_game, ..._routes.values}) {
      target.padSteered.value = phones.value.any(
        (phone) => identical(_targetOf(phone.$1), target),
      );
    }
  }

  /// Takes the phones' slot of the Realtime budget: a phone and its screen
  /// cost [GameConfig.padLoad] messages a second, each on its own lane.
  Future<void> _claimSlot() async {
    final pairing = code.value;
    final slots = (_game ?? _routes.values.firstOrNull)?.slots;
    if (pairing == null || slots == null) {
      return;
    }
    final steering = [
      for (final (padId, _) in phones.value)
        if (_targetOf(padId) != null) padId,
    ];
    var ok = true;
    if (steering.isNotEmpty) {
      // A room with a phone drops its CPU tanks for it, except in defense:
      // its lower slot first, so the phones find the room it makes.
      for (final target in {for (final padId in steering) _targetOf(padId)}) {
        await target?.refreshRoomSlot();
      }
      ok = await slots.claim(
        'pad-$pairing',
        steering.length * GameConfig.padLoad,
      );
    }
    if (busy.value != !ok) {
      busy.value = !ok;
      if (!ok) {
        for (final padId in steering) {
          _release(_targetOf(padId));
        }
      }
      _updateSteered();
    }
  }

  /// Lets a test play the presences of phones, [lanes] those that talk on
  /// lanes of their own.
  @visibleForTesting
  void debugPeers(
    List<(String, String)> peers, {
    Set<String> lanes = const {},
  }) {
    _laneIds = lanes;
    _peersChanged(peers);
  }

  /// Lets a test claim the phones' slot at once.
  @visibleForTesting
  Future<void> debugClaimSlot() => _claimSlot();

  /// Lets a test run one tick of the status to the phones.
  @visibleForTesting
  void debugTick() => _onTick();

  /// Whether a phone steers [target] right now.
  bool steers(TankGame target) =>
      phones.value.any((phone) => identical(gameOf(phone.$1), target));

  /// Lets a test play the messages of phones.
  @visibleForTesting
  void debugPadInput(Map<String, dynamic> json) => _receive(_Event.pad, json);

  /// Hands the phone [padId] to [target], as a duel does for its halves.
  void route(String padId, TankGame target) {
    _release(gameOf(padId));
    _routes[padId] = target;
    _statusGates.remove(padId);
    _updateSteered();
    unawaited(_claimSlot());
  }

  /// Every phone back to the way without a duel: the first steers [game].
  void clearRoutes() {
    for (final target in _routes.values) {
      _release(target);
      target.padSteered.value = false;
    }
    _routes.clear();
    _statusGates.clear();
    _updateSteered();
    unawaited(_claimSlot());
  }

  /// Opens a pairing, or takes up the one from before a reload.
  Future<void> open() async {
    final existing = code.value ?? storedPadCode();
    final fresh = existing ?? newPadCode();
    rememberPadCode(fresh);
    code.value = fresh;
    _tick ??= Timer.periodic(tickInterval, (_) => _onTick());
    _slotTimer ??= Timer.periodic(
      const Duration(minutes: 1),
      (_) => unawaited(_claimSlot()),
    );
    await _connect(fresh, 'screen');
  }

  /// Takes up a pairing this page had before it loaded another room.
  Future<void> resume() async {
    if (storedPadCode() != null) {
      await open();
    }
  }

  /// Ends the pairing. The phones see the screen leave.
  Future<void> close() async {
    rememberPadCode(null);
    code.value = null;
    _tick?.cancel();
    _tick = null;
    _slotTimer?.cancel();
    _slotTimer = null;
    for (final phone in phones.value) {
      _release(gameOf(phone.$1));
    }
    for (final target in _routes.values) {
      target.padSteered.value = false;
    }
    _routes.clear();
    _statusGates.clear();
    phones.value = const [];
    paired.value = null;
    busy.value = false;
    _updateSteered();
    await _close();
  }

  @override
  void _peersChanged(List<(String, String)> peers) {
    final before = phones.value;
    // Who was here keeps the place, newcomers queue up behind.
    final next = [
      for (final phone in before) ...peers.where((peer) => peer.$1 == phone.$1),
      for (final peer in peers)
        if (!before.any((phone) => phone.$1 == peer.$1)) peer,
    ];
    for (final phone in before) {
      if (!next.any((peer) => peer.$1 == phone.$1)) {
        _release(gameOf(phone.$1));
        _routes.remove(phone.$1);
        _lastInput.remove(phone.$1);
        _statusGates.remove(phone.$1);
      }
    }
    if (next.firstOrNull?.$1 != before.firstOrNull?.$1) {
      // Another phone steers the game now: it starts from rest.
      _release(_game);
    }
    phones.value = next;
    paired.value = next.firstOrNull?.$2;
    for (final (padId, _) in next) {
      if (_laneIds.contains(padId)) {
        _openLane(padId);
      }
    }
    for (final lane in _lanes.keys.toList()) {
      if (!next.any((phone) => phone.$1 == lane)) {
        unawaited(_closeLane(lane));
      }
    }
    _updateSteered();
    unawaited(_claimSlot());
  }

  @override
  void _receive(_Event event, Map<String, dynamic> json) {
    final padId = json['id'];
    if (padId is! String) {
      return;
    }
    final target = gameOf(padId);
    if (target == null) {
      return;
    }
    switch (event) {
      case _Event.pad:
        final pad = PadInput.tryParse(json);
        if (pad == null) {
          return;
        }
        _lastInput[padId] = clock.now();
        final input = target.touch
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
        if (action == null) {
          return;
        }
        switch (action.kind) {
          case PadActionKind.item:
            target.useItem(action.slot);
          case PadActionKind.build:
            target.buildTower();
          case PadActionKind.cycle:
            target.cycleTowerKind();
        }
      case _Event.status:
    }
  }

  /// Lets go of everything a phone held in [target]. The aim stays, as after
  /// lifting the thumb off the touch stick.
  static void _release(TankGame? target) {
    target?.touch
      ?..drive = null
      ..aimHeld = false
      ..aimFire = false
      ..special = false;
  }

  void _onTick() {
    final now = clock.now();
    for (final (padId, _) in phones.value) {
      final target = gameOf(padId);
      if (target == null) {
        continue;
      }
      final last = _lastInput[padId] ?? DateTime(0);
      if (now.difference(last) > _silence) {
        _release(target);
      }
      // Each phone hears about its own tank only.
      final status = statusOf(target).toJson()..['to'] = padId;
      final gate = _statusGates.putIfAbsent(
        padId,
        () => SendGate(gap: statusGap, keepalive: statusKeepalive),
      );
      if (gate.shouldSend(status.toString())) {
        _send(
          _Event.status,
          status,
          lane: _laneIds.contains(padId) ? padId : null,
        );
      }
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

  /// The sticks are read this often, and a change goes out at most every
  /// [inputGap]: twelve and a half a second while the thumbs move, about
  /// three a second while they rest.
  static const tickInterval = Duration(milliseconds: 40);
  static const inputGap = Duration(milliseconds: 80);
  static const inputKeepalive = Duration(milliseconds: 300);
  final _inputGate = SendGate(gap: inputGap, keepalive: inputKeepalive);

  /// Steps the sticks are rounded to, so a resting thumb's tremor is no
  /// change: a sixteenth of the stick, a sixty-fourth of a radian.
  static const driveSteps = 16;
  static const aimSteps = 64;

  Future<void> start(String name) async {
    _tick ??= Timer.periodic(tickInterval, (_) => tick());
    await _connect(code, name);
  }

  Future<void> stop() async {
    _tick?.cancel();
    _tick = null;
    await _close();
  }

  /// The own lane, once the screen talks on lanes.
  String? get _lane => _laneIds.isEmpty ? null : id;

  void act(PadActionKind kind, [int slot = 0]) => _send(
    _Event.act,
    PadAction(id: id, kind: kind, slot: slot).toJson(),
    lane: _lane,
  );

  /// Reads the sticks and sends them when it is time.
  @visibleForTesting
  void tick() {
    if (!screenOnline.value) {
      return;
    }
    final drive = input.drive;
    final aim = input.aim;
    final pad = PadInput(
      id: id,
      drive: drive == null
          ? null
          : (_round(drive.$1, driveSteps), _round(drive.$2, driveSteps)),
      aim: aim == null ? null : _round(aim, aimSteps),
      aimHeld: input.aimHeld,
      aimFire: input.aimFire,
      special: input.special,
      assist: input.assist,
    ).toJson();
    if (_inputGate.shouldSend(pad.toString())) {
      _send(_Event.pad, pad, lane: _lane);
    }
  }

  static double _round(double value, int steps) =>
      (value * steps).roundToDouble() / steps;

  @override
  void _peersChanged(List<(String, String)> peers) {
    screenOnline.value = peers.isNotEmpty;
    if (_laneIds.isEmpty) {
      unawaited(_closeLane(id));
    } else {
      _openLane(id);
    }
  }

  /// Lets a test play the screen's presence, with or without lanes.
  @visibleForTesting
  void debugScreen({required bool lanes}) {
    _laneIds = lanes ? {'screen'} : {};
    _peersChanged([('screen', '')]);
  }

  @override
  void _receive(_Event event, Map<String, dynamic> json) {
    if (event == _Event.status) {
      // A screen with two phones on the code tells each about its own tank.
      final to = json['to'];
      if (to is String && to != id) {
        return;
      }
      final parsed = PadStatus.tryParse(json);
      if (parsed != null) {
        status.value = parsed;
      }
    }
  }
}
