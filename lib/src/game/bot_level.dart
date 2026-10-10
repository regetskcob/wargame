import 'dart:math';

import 'game_config.dart';
import '../l10n/l10n.dart';

/// How well the CPU tanks fight.
enum BotLevel {
  easy(
    'LEICHT',
    'EASY',
    aimError: 0.24,
    reaction: 0.8,
    think: 0.28,
    lead: 0.4,
    holdFire: 10,
  ),
  normal(
    'MITTEL',
    'NORMAL',
    aimError: 0.12,
    reaction: 0.4,
    think: 0.15,
    lead: 1,
    holdFire: 6,
  ),
  hard(
    'SCHWER',
    'HARD',
    aimError: 0.05,
    reaction: 0.18,
    think: 0.08,
    lead: 1,
    holdFire: 3,
  );

  const BotLevel(
    this._labelDe,
    this._labelEn, {
    required this.aimError,
    required this.reaction,
    required this.think,
    required this.lead,
    required this.holdFire,
  });

  final String _labelDe;
  final String _labelEn;

  String get label => tr(_labelDe, _labelEn);

  /// Largest aiming mistake in radians, before distance makes it worse.
  final double aimError;

  /// Seconds on target before the first shot.
  final double reaction;

  /// Seconds between decisions about where to drive.
  final double think;

  /// How much of the target's movement the aim leads, 0 to 1.
  final double lead;

  /// Seconds into the round before a CPU tank goes for people, unless it
  /// is hit first; other CPU tanks it fights from the start. A play test
  /// found new players destroyed within ten seconds, before they had found
  /// the sticks.
  final double holdFire;

  /// Rating a CPU tank of this level counts with.
  int get rating => switch (this) {
    BotLevel.easy => 800,
    BotLevel.normal => 1000,
    BotLevel.hard => 1200,
  };

  /// Hard bots dodge barrages and keep their distance smarter.
  bool get evasive => this == hard;

  static BotLevel of(int? index) =>
      index == null || index < 0 || index >= values.length
      ? normal
      : values[index];
}

/// How many CPU tanks join a round. Alone there are always
/// [GameConfig.minBots] to [GameConfig.maxBots]. With other people only when
/// [fill] is on: up to [fillTo] tanks in all, and in a team round one more
/// if that makes the teams even.
int botsFor({
  required bool solo,
  required int humans,
  required bool fill,
  required bool teams,
  int fillTo = GameConfig.fillTo,
  Random? random,
}) {
  if (solo) {
    final roll = (random ?? Random()).nextInt(
      GameConfig.maxBots - GameConfig.minBots + 1,
    );
    return GameConfig.minBots + roll;
  }
  if (!fill) {
    return 0;
  }
  var bots = max(0, fillTo - humans);
  if (teams && (humans + bots).isOdd) {
    bots++;
  }
  return bots;
}
