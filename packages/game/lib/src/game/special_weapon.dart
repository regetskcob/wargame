import 'dart:ui';

import '../game_config.dart';
import '../l10n/l10n.dart';

/// Weapons a tank only gets from a gem. They come with a few charges, fire
/// with F or the touch button and are gone once the charges are used up.
enum SpecialWeapon {
  /// Lobs shells over walls and trees onto the spot under the cursor.
  grenades(
    'GRANATWERFER',
    'GRENADE LAUNCHER',
    Color(0xFFEF5350),
    charges: GameConfig.grenadeCharges,
    cooldown: GameConfig.grenadeCooldown,
    radius: GameConfig.grenadeRadius,
    damage: GameConfig.grenadeDamage,
    range: GameConfig.grenadeRange,
    minRange: GameConfig.grenadeMinRange,
    flight: GameConfig.grenadeFlightSeconds,
    arc: 70,
  ),

  /// Launches a kamikaze drone that hunts the nearest enemy on its own.
  drone(
    'DROHNE',
    'DRONE',
    Color(0xFFB388FF),
    charges: GameConfig.droneCharges,
    cooldown: GameConfig.droneCooldown,
    radius: GameConfig.droneRadius,
    damage: GameConfig.droneDamage,
  ),

  /// A light mortar: a long, high arc onto the spot under the cursor. It
  /// hits tanks harder than the grenade launcher.
  mortar(
    'MÖRSER',
    'MORTAR',
    Color(0xFFFF8A65),
    charges: GameConfig.mortarCharges,
    cooldown: GameConfig.mortarCooldown,
    radius: GameConfig.mortarRadius,
    damage: GameConfig.mortarDamage,
    range: GameConfig.mortarRange,
    minRange: GameConfig.mortarMinRange,
    flight: GameConfig.mortarFlightSeconds,
    arc: 150,
  ),

  /// The shell of a mortar emplacement in a defense round. No tank carries
  /// it.
  shell(
    'MÖRSERSTELLUNG',
    'MORTAR EMPLACEMENT',
    Color(0xFFFFAB40),
    charges: 0,
    cooldown: 0,
    radius: GameConfig.shellRadius,
    damage: GameConfig.shellDamage,
    flight: GameConfig.shellFlightSeconds,
    arc: 130,
  );

  const SpecialWeapon(
    this._labelDe,
    this._labelEn,
    this.color, {
    required this.charges,
    required this.cooldown,
    required this.radius,
    required this.damage,
    this.range = 0,
    this.minRange = 0,
    this.flight = 0,
    this.arc = 0,
  });

  final String _labelDe;
  final String _labelEn;
  String get label => tr(_labelDe, _labelEn);
  final Color color;
  final int charges;
  final double cooldown;

  /// Blast radius and the damage right at its centre. At the edge a tank
  /// still takes half of it.
  final double radius;
  final double damage;

  /// For the weapons that lob a shell: how far it flies at most and at
  /// least, how long it is in the air and how high it climbs.
  final double range;
  final double minRange;
  final double flight;
  final double arc;

  bool get lobbed => flight > 0;

  double damageAt(double distance) {
    final share = (distance / radius).clamp(0.0, 1.0);
    return damage * (1 - 0.5 * share);
  }
}
