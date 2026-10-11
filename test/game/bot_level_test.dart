import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:wargame/src/game/bot_brain.dart';
import 'package:wargame/src/game/bot_level.dart';
import 'package:wargame/src/game/components/tank_painter.dart';
import 'package:wargame/src/game/game_config.dart';
import 'package:wargame/src/game/tank_stats.dart';
import 'package:wargame/src/game/map_theme.dart';
import 'package:wargame/src/game/weather.dart';

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
    expect(botsFor(solo: false, humans: 6, fill: true, teams: false), 6);
  });

  test('at least as many CPU tanks as people whenever they come', () {
    final random = Random(2);
    for (var humans = 1; humans <= 4; humans++) {
      for (final teams in [false, true]) {
        expect(
          botsFor(solo: false, humans: humans, fill: true, teams: teams),
          greaterThanOrEqualTo(humans),
        );
      }
      for (var i = 0; i < 30; i++) {
        expect(
          botsFor(
            solo: true,
            humans: humans,
            fill: false,
            teams: false,
            random: random,
          ),
          greaterThanOrEqualTo(humans),
        );
      }
    }
  });

  test('filling up evens out the teams', () {
    expect(botsFor(solo: false, humans: 5, fill: true, teams: true), 5);
    expect(botsFor(solo: false, humans: 6, fill: true, teams: true), 6);
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

  test('CPU tanks fire at people only as far as those can see', () {
    final night = const Conditions(
      sky: Sky.clear,
      night: true,
      theme: MapTheme.forest,
    ).vision!;
    for (final type in TankType.values) {
      final stats = TankStats.of(type);
      expect(BotBrain.reach(stats, vision: night), lessThanOrEqualTo(night));
      expect(
        BotBrain.reach(stats),
        stats.bulletSpeed * GameConfig.bulletTtl * 0.9,
        reason: 'by day and at other CPU tanks as far as the shells fly',
      );
    }
  });

  test('CPU tanks drive the starter vehicles on every level', () {
    for (final level in BotLevel.values) {
      final random = Random(1);
      for (var i = 0; i < 50; i++) {
        final style = GameConfig.randomStyle(
          random,
          maxLevel: level.maxVehicleLevel,
        );
        expect(GameConfig.typeOf(style).level, 1);
      }
    }
  });

  test('normal and hard CPU tanks fire slower than people', () {
    expect(BotLevel.easy.fireFactor, 1);
    expect(BotLevel.normal.fireFactor, greaterThan(1));
    expect(BotLevel.hard.fireFactor, greaterThan(1));
    expect(BotLevel.hard.humanPull, greaterThan(BotLevel.easy.humanPull));
  });
}
