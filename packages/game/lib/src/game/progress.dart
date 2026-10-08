import 'dart:math';

import '../l10n/l10n.dart';
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

  static const _titlesDe = [
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

  static const _titlesEn = [
    'Recruit',
    'Private',
    'Lance Corporal',
    'Corporal',
    'Sergeant',
    'Staff Sergeant',
    'Warrant Officer',
    'Master Sergeant',
    'Lieutenant',
    'First Lieutenant',
    'Captain',
    'Major',
  ];

  String get title {
    final i = min(level, _titlesDe.length) - 1;
    return tr(_titlesDe[i], _titlesEn[i]);
  }
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
  const Achievement(
    this.code,
    this._titleDe,
    this._titleEn,
    this._descriptionDe,
    this._descriptionEn,
    this.earned,
  );

  final String code;
  final String _titleDe;
  final String _titleEn;
  final String _descriptionDe;
  final String _descriptionEn;

  String get title => tr(_titleDe, _titleEn);
  String get description => tr(_descriptionDe, _descriptionEn);
  final bool Function(RoundContext round) earned;

  static final all = <Achievement>[
    Achievement(
      'first_kill',
      'Erster Abschuss',
      'First kill',
      'Einen Panzer zerstört',
      'Destroyed a tank',
      (r) => r.stats.kills >= 1,
    ),
    Achievement(
      'first_win',
      'Erster Sieg',
      'First win',
      'Ein Gefecht gewonnen',
      'Won a battle',
      (r) => r.won,
    ),
    Achievement(
      'triple',
      'Dreifachschlag',
      'Triple strike',
      'Drei Abschüsse in einer Runde',
      'Three kills in one round',
      (r) => r.stats.kills >= 3,
    ),
    Achievement(
      'sharpshooter',
      'Scharfschütze',
      'Sharpshooter',
      'Mindestens 70 % Treffer bei zehn Schüssen oder mehr',
      'At least 70 % hits with ten shots or more',
      (r) => r.stats.shots >= 10 && r.stats.accuracy >= 0.7,
    ),
    Achievement(
      'close_call',
      'Haarscharf',
      'Close call',
      'Mit höchstens 15 Panzerung gewonnen',
      'Won with 15 armour or less',
      (r) => r.won && r.hpLeft > 0 && r.hpLeft <= 15,
    ),
    Achievement(
      'untouched',
      'Unantastbar',
      'Untouchable',
      'Gewonnen, ohne Schaden zu nehmen',
      'Won without taking damage',
      (r) => r.won && r.stats.damageTaken == 0,
    ),
    Achievement(
      'infantry',
      'Infanterieschreck',
      'Terror of the infantry',
      'Acht Soldaten in einer Runde überrollt',
      'Ran over eight soldiers in one round',
      (r) => r.soldiers >= 8,
    ),
    Achievement(
      'night_owl',
      'Nachteule',
      'Night owl',
      'Ein Gefecht bei Nacht gewonnen',
      'Won a battle at night',
      (r) => r.won && r.night,
    ),
    Achievement(
      'veteran',
      'Veteran',
      'Veteran',
      'Fünfzig Gefechte bestritten',
      'Fought fifty battles',
      (r) => r.totalRounds >= 50,
    ),
    Achievement(
      'all_rounder',
      'Alleskönner',
      'All-rounder',
      'Mit jedem Fahrzeug gewonnen',
      'Won with every vehicle',
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
