import 'dart:ui';

import '../game_config.dart';

/// What credits buy for the tank in a defense round. Each comes in
/// [GameConfig.upgradeMaxLevel] steps and is gone when the round ends.
enum UpgradeKind {
  /// Thicker armour: every hit does less damage.
  armor('PANZERUNG', Color(0xFF90A4AE)),

  /// A better gun: every shell does more damage.
  gun('KANONE', Color(0xFFEF5350)),

  /// A stronger engine: a higher top speed.
  engine('MOTOR', Color(0xFF66BB6A)),

  /// More rounds in the magazine.
  magazine('MAGAZIN', Color(0xFF4FC3F7));

  const UpgradeKind(this.label, this.color);

  final String label;
  final Color color;

  /// What the next step costs, coming from [level].
  int costFrom(int level) => GameConfig.upgradeBaseCost * (level + 1);

  /// Factor on damage taken, damage dealt, top speed or magazine size.
  double factorAt(int level) => switch (this) {
    UpgradeKind.armor => 1 - 0.15 * level,
    UpgradeKind.gun => 1 + 0.15 * level,
    UpgradeKind.engine => 1 + 0.08 * level,
    UpgradeKind.magazine => 1 + 0.3 * level,
  };

  /// One line on what the next step does.
  String get effect => switch (this) {
    UpgradeKind.armor => '-15 % Schaden',
    UpgradeKind.gun => '+15 % Schaden',
    UpgradeKind.engine => '+8 % Tempo',
    UpgradeKind.magazine => '+30 % Munition',
  };
}
