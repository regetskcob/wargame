import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:game/src/game/bot_level.dart';
import 'package:game/src/game_config.dart';

void main() {
  test('alone there are always some CPU tanks', () {
    final random = Random(1);
    for (var i = 0; i < 50; i++) {
      final bots = botsFor(
        solo: true,
        humans: 1,
        fill: false,
        teams: false,
        random: random,
      );
      expect(bots, inInclusiveRange(GameConfig.minBots, GameConfig.maxBots));
    }
  });

  test('with people, CPU tanks only come when asked to fill up', () {
    expect(botsFor(solo: false, humans: 2, fill: false, teams: false), 0);
    expect(
      botsFor(solo: false, humans: 2, fill: true, teams: false),
      GameConfig.fillTo - 2,
    );
    expect(botsFor(solo: false, humans: 6, fill: true, teams: false), 0);
  });

  test('filling up evens out the teams', () {
    expect(botsFor(solo: false, humans: 5, fill: true, teams: true), 1);
    expect(botsFor(solo: false, humans: 6, fill: true, teams: true), 0);
    expect(
      (3 + botsFor(solo: false, humans: 3, fill: true, teams: true)).isEven,
      isTrue,
    );
  });

  test('an unknown level falls back to the middle one', () {
    expect(BotLevel.of(null), BotLevel.normal);
    expect(BotLevel.of(99), BotLevel.normal);
    expect(BotLevel.of(BotLevel.hard.index), BotLevel.hard);
  });
}
