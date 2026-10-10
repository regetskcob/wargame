// Every message a game sends, bent field by field into what a client that
// does not play by the rules could send instead (wrong types, endless and
// huge numbers, long strings and lists, other players' ids), and handed to
// a game in the middle of a round. Nothing may throw, while the message is
// taken or in the frames after it.
@Timeout(Duration(minutes: 4))
library;

import 'dart:convert';
import 'dart:ui';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wargame/src/game/bot_level.dart';
import 'package:wargame/src/game/components/power_up.dart';
import 'package:wargame/src/game/game_config.dart';
import 'package:wargame/src/game/game_mode.dart';
import 'package:wargame/src/game/tank_game.dart';
import 'package:wargame/src/net/net_events.dart';
import 'package:wargame/src/net/net_service.dart';

import '../helpers/fakes.dart';

/// Keeps what the game puts on the wire, as the wire hands it over.
class _RecordingNet extends FakeNet {
  _RecordingNet({super.isHost});

  final sent = <NetEvent, Map<String, dynamic>>{};

  @override
  void transmit(NetEvent event, Map<String, dynamic> payload) =>
      sent.putIfAbsent(
        event,
        () => jsonDecode(jsonEncode(payload)) as Map<String, dynamic>,
      );
}

Future<TankGame> _round(NetService net, GameMode mode) async {
  net.othersPresent = true;
  final game = await loadedGame(net: net);
  game
    ..update(0)
    ..chooseMode(mode)
    ..fillWithBots.value = true
    ..botLevel.value = BotLevel.hard;
  final now = clock.now().millisecondsSinceEpoch;
  game.startRound(
    seed: 7,
    startedAt: mode == GameMode.defense
        ? now - GameConfig.firstWaveSeconds * 1000
        : now - 1,
  );
  game.update(0);
  return game;
}

Future<void> _frames(
  TankGame game,
  int count, {
  void Function(int)? input,
}) async {
  for (var frame = 0; frame < count; frame++) {
    input?.call(frame);
    game.update(1 / 30);
    await Future<void>.delayed(Duration.zero);
    if (frame % 5 == 0) {
      final recorder = PictureRecorder();
      game.render(Canvas(recorder));
      recorder.endRecording().dispose();
    }
  }
}

const _evil = <Object?>[
  null,
  'x',
  true,
  -1,
  1e308,
  -1e308,
  double.infinity,
  9007199254740993,
  3.5,
  <Object?>[],
  <String, Object?>{},
  'me',
  'host',
];

/// [base] with one field, or one field one level down, replaced.
Iterable<Map<String, dynamic>> _bent(Map<String, dynamic> base) sync* {
  Map<String, dynamic> copy() =>
      jsonDecode(jsonEncode(base)) as Map<String, dynamic>;
  for (final key in base.keys) {
    for (final value in _evil) {
      yield copy()..[key] = value;
      final inner = base[key];
      if (inner is Map<String, dynamic>) {
        for (final innerKey in inner.keys) {
          final bent = copy();
          (bent[key] as Map<String, dynamic>)[innerKey] = value;
          yield bent;
        }
      }
      if (inner is List && inner.isNotEmpty && inner.first is Map) {
        for (final innerKey in (inner.first as Map<String, dynamic>).keys) {
          final bent = copy();
          ((bent[key] as List).first as Map<String, dynamic>)[innerKey] = value;
          yield bent;
        }
      }
    }
    yield copy()..[key] = 'A' * 20000;
    yield copy()..[key] = List.filled(5000, 1);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final mode in [GameMode.multi, GameMode.defense, GameMode.flag]) {
    test('bent messages of ${mode.name} break no game', () async {
      final errors = <Object>[];
      final previous = FlutterError.onError;
      FlutterError.onError = (details) => errors.add(details.exception);
      addTearDown(() => FlutterError.onError = previous);

      // A game that plays the mode and sends everything it can.
      final senderNet = _RecordingNet(isHost: true);
      final sender = await _round(senderNet, mode);
      final items = PowerUpType.values.toList();
      await _frames(
        sender,
        450,
        input: (frame) {
          sender.touch
            ..thrust = true
            ..left = frame % 90 < 30
            ..fire = frame.isEven
            ..special = frame % 60 == 0;
          if (frame % 20 == 0 && items.isNotEmpty) {
            sender.inventory.add(items.removeLast());
            sender.useItem(0);
          }
        },
      );
      expect(senderNet.sent.length, greaterThan(8));

      for (final victimHost in [true, false]) {
        final net = _RecordingNet(isHost: victimHost);
        final victim = await _round(net, mode);
        net.listenWithoutChannel();
        for (final MapEntry(key: event, value: payload)
            in senderNet.sent.entries) {
          final base = Map<String, dynamic>.of(payload)..['id'] = 'eve';
          for (final bent in _bent(base)) {
            if (bent['id'] != 'me') {
              net.deliverForTest(event, bent);
            }
          }
          try {
            await _frames(victim, 4);
          } on Object catch (error) {
            errors.add('${event.name}: $error');
          }
        }
      }
      expect(errors, isEmpty);
    });
  }
}
