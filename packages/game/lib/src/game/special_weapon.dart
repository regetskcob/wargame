import 'dart:ui';

import '../game_config.dart';

/// Weapons a tank only gets from a gem. They come with a few charges, fire
/// with F or the touch button and are gone once the charges are used up.
enum SpecialWeapon {
  /// Lobs shells over walls and trees onto the spot under the cursor.
  grenades(
    'GRANATWERFER',
    Color(0xFFEF5350),
    charges: GameConfig.grenadeCharges,
    cooldown: GameConfig.grenadeCooldown,
    radius: GameConfig.grenadeRadius,
    damage: GameConfig.grenadeDamage,
  ),

  /// Launches a kamikaze drone that hunts the nearest enemy on its own.
  drone(
    'DROHNE',
    Color(0xFFB388FF),
    charges: GameConfig.droneCharges,
    cooldown: GameConfig.droneCooldown,
    radius: GameConfig.droneRadius,
    damage: GameConfig.droneDamage,
  );

  const SpecialWeapon(
    this.label,
    this.color, {
    required this.charges,
    required this.cooldown,
    required this.radius,
    required this.damage,
  });

  final String label;
  final Color color;
  final int charges;
  final double cooldown;

  /// Blast radius and the damage right at its centre. At the edge a tank
  /// still takes half of it.
  final double radius;
  final double damage;

  double damageAt(double distance) {
    final share = (distance / radius).clamp(0.0, 1.0);
    return damage * (1 - 0.5 * share);
  }
}
