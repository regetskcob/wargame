import 'dart:math';

import 'components/tank_painter.dart';
import 'round_stats.dart';

/// Experience turns into ranks: every rank needs a little more than the last.
class Rank {
  const Rank._(this.level, this.xp);

  factory Rank.of(int xp) {
    final level = 1 + sqrt(max(0, xp) / _step).floor();
    return Rank._(level, xp);
  }

  static const _step = 120;

  final int level;
  final int xp;

  /// Experience needed to reach [level].
  static int xpFor(int level) => _step * (level - 1) * (level - 1);

  int get floor => xpFor(level);
  int get next => xpFor(level + 1);

  /// How far to the next rank, 0 to 1.
  double get progress => (xp - floor) / (next - floor);

  static const _titles = [
    'Rekrut',
    'Gefreiter',
    'Obergefreiter',
    'Hauptgefreiter',
    'Unteroffizier',
    'Feldwebel',
    'Oberfeldwebel',
    'Hauptfeldwebel',
    'Leutnant',
    'Oberleutnant',
    'Hauptmann',
    'Major',
  ];

  String get title => _titles[min(level, _titles.length) - 1];
}

/// What happened to the local player in a finished round, to decide which
/// badges they earned.
class RoundContext {
  const RoundContext({
    required this.stats,
    required this.won,
    required this.hpLeft,
    required this.soldiers,
    required this.night,
    required this.tankType,
    this.totalRounds = 0,
    this.tanksWithWins = const {},
  });

  final RoundStats stats;
  final bool won;

  /// Health at the end of the round, 0 when the tank was destroyed.
  final double hpLeft;
  final int soldiers;
  final bool night;
  final TankType tankType;

  /// Rounds recorded in total, this one included.
  final int totalRounds;

  /// Vehicles the player has won a round with, this one included.
  final Set<TankType> tanksWithWins;
}

/// A badge a player can earn once.
class Achievement {
  const Achievement(this.code, this.title, this.description, this.earned);

  final String code;
  final String title;
  final String description;
  final bool Function(RoundContext round) earned;

  static final all = <Achievement>[
    Achievement(
      'first_kill',
      'Erster Abschuss',
      'Einen Panzer zerstört',
      (r) => r.stats.kills >= 1,
    ),
    Achievement(
      'first_win',
      'Erster Sieg',
      'Ein Gefecht gewonnen',
      (r) => r.won,
    ),
    Achievement(
      'triple',
      'Dreifachschlag',
      'Drei Abschüsse in einer Runde',
      (r) => r.stats.kills >= 3,
    ),
    Achievement(
      'sharpshooter',
      'Scharfschütze',
      'Mindestens 70 % Treffer bei zehn Schüssen oder mehr',
      (r) => r.stats.shots >= 10 && r.stats.accuracy >= 0.7,
    ),
    Achievement(
      'close_call',
      'Haarscharf',
      'Mit höchstens 15 Panzerung gewonnen',
      (r) => r.won && r.hpLeft > 0 && r.hpLeft <= 15,
    ),
    Achievement(
      'untouched',
      'Unantastbar',
      'Gewonnen, ohne Schaden zu nehmen',
      (r) => r.won && r.stats.damageTaken == 0,
    ),
    Achievement(
      'infantry',
      'Infanterieschreck',
      'Acht Soldaten in einer Runde überrollt',
      (r) => r.soldiers >= 8,
    ),
    Achievement(
      'night_owl',
      'Nachteule',
      'Ein Gefecht bei Nacht gewonnen',
      (r) => r.won && r.night,
    ),
    Achievement(
      'veteran',
      'Veteran',
      'Fünfzig Gefechte bestritten',
      (r) => r.totalRounds >= 50,
    ),
    Achievement(
      'all_rounder',
      'Alleskönner',
      'Mit jedem Fahrzeug gewonnen',
      (r) => r.tanksWithWins.containsAll(TankType.values),
    ),
  ];

  static Achievement? byCode(String code) {
    for (final achievement in all) {
      if (achievement.code == code) {
        return achievement;
      }
    }
    return null;
  }

  /// Badges [round] earns that are not in [owned] yet.
  static List<Achievement> newlyEarned(RoundContext round, Set<String> owned) =>
      [
        for (final achievement in all)
          if (!owned.contains(achievement.code) && achievement.earned(round))
            achievement,
      ];
}
