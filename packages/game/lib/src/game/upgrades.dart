import 'dart:math';
import 'dart:ui';

import '../game_config.dart';
import '../l10n/l10n.dart';

/// What credits buy for the tank in a defense round. Each comes in three
/// steps, up to [GameConfig.upgradeMaxLevel] in the extension, and is gone
/// when the round ends.
enum UpgradeKind {
  /// Thicker armour: every hit does less damage.
  armor('PANZERUNG', 'ARMOUR', Color(0xFF90A4AE)),

  /// A better gun: every shell does more damage.
  gun('KANONE', 'CANNON', Color(0xFFEF5350)),

  /// A stronger engine: a higher top speed.
  engine('MOTOR', 'ENGINE', Color(0xFF66BB6A)),

  /// More rounds in the magazine.
  magazine('MAGAZIN', 'MAGAZINE', Color(0xFF4FC3F7));

  const UpgradeKind(this._labelDe, this._labelEn, this.color);

  final String _labelDe;
  final String _labelEn;
  String get label => tr(_labelDe, _labelEn);
  final Color color;

  /// What the next step costs, coming from [level].
  int costFrom(int level) => GameConfig.upgradeBaseCost * (level + 1);

  /// Factor on damage taken, damage dealt, top speed or magazine size.
  double factorAt(int level) => switch (this) {
    // The steps of the extension shield less, so a tank never shrugs off
    // everything.
    UpgradeKind.armor => 1 - 0.15 * min(level, 3) - 0.1 * max(0, level - 3),
    UpgradeKind.gun => 1 + 0.15 * level,
    UpgradeKind.engine => 1 + 0.08 * level,
    UpgradeKind.magazine => 1 + 0.3 * level,
  };

  /// One line on what the next step does.
  String get effect => switch (this) {
    UpgradeKind.armor => tr('-15 % Schaden', '-15 % damage'),
    UpgradeKind.gun => tr('+15 % Schaden', '+15 % damage'),
    UpgradeKind.engine => tr('+8 % Tempo', '+8 % speed'),
    UpgradeKind.magazine => tr('+30 % Munition', '+30 % ammunition'),
  };
}
