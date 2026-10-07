import 'package:flutter/material.dart';

import 'tanks/tank_painter.dart';

/// Every tuning constant the exercises refer to. The per vehicle values
/// (health, speed, damage) live in `tanks/tank_stats.dart`.
class GameConfig {
  static const worldRadius = 900.0;

  static const tankMaxSpeed = 240.0;
  static const tankAcceleration = 1000.0;
  static const tankBrake = 2000.0;
  static const tankRollingResistance = 1600.0;
  static const tankReverseSpeed = 110.0;
  static const tankRotationSpeed = 3.0;
  static const tankRadius = 24.0;

  static const bulletTtl = 1.4;
  static const obstacleBumpDamage = 5.0;

  static const stateSyncInterval = 0.05;
  static const keepaliveInterval = 1.0;
  static const remoteLerpFactorPerSecond = 12.0;
  static const remoteTeleportDistance = 200.0;

  static const zoneGraceSeconds = 20.0;
  static const zoneShrinkSeconds = 90.0;
  static const zoneMinRadius = 120.0;
  static const zoneDamagePerSecond = 10.0;

  static const treeCount = 50;
  static const buildingCount = 7;
  static const barrierCount = 14;
  static const spawnRadius = 600.0;

  static const countdownSeconds = 3;
  static const roundOverSeconds = 6;

  /// Four paint schemes: Flecktarn green, Wüstentarn sand, Wintertarn white
  /// and NATO grey.
  static const tankColors = [
    Color(0xFF6B7F3A),
    Color(0xFFC2A878),
    Color(0xFFD8DCD6),
    Color(0xFF8C8C84),
  ];

  static const colorNames = [
    'FLECKTARN',
    'WÜSTENTARN',
    'WINTERTARN',
    'NATO-GRAU',
  ];

  /// A player's look travels as one number, the paint scheme in the low two
  /// bits and the vehicle above it, so the wire format stays a single int.
  static const styleCount = 16;

  static int styleOf(int tankType, int color) => tankType * 4 + color;

  static Color colorOf(int style) => tankColors[style % tankColors.length];

  static TankType typeOf(int style) =>
      TankType.values[(style ~/ tankColors.length) % TankType.values.length];

  /// Team 0 plays alone, 1 is red, 2 is blue.
  static const teamColors = [
    Color(0xFFE6E2D3),
    Color(0xFFE5533D),
    Color(0xFF4A90E2),
  ];
  static const teamNames = ['', 'ROT', 'BLAU'];
}
