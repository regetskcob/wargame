import 'package:flutter/material.dart';

import 'game/components/tank_painter.dart';

class GameConfig {
  static const worldRadius = 900.0;

  static const shipMaxSpeed = 240.0;
  static const shipAcceleration = 1000.0;
  static const shipBrake = 2000.0;
  static const shipRollingResistance = 1600.0;
  static const shipReverseSpeed = 110.0;
  static const shipRotationSpeed = 3.0;
  static const shipMaxHp = 100.0;
  static const shipRadius = 24.0;

  static const fireCooldown = 0.25;
  static const bulletSpeed = 420.0;
  static const bulletTtl = 1.4;
  static const bulletDamage = 15.0;
  static const asteroidBumpDamage = 5.0;

  static const stateSyncInterval = 0.05;
  static const keepaliveInterval = 1.0;
  static const remoteLerpFactorPerSecond = 12.0;
  static const remoteTeleportDistance = 200.0;

  static const zoneGraceSeconds = 20.0;
  static const zoneShrinkSeconds = 90.0;
  static const zoneMinRadius = 120.0;
  static const zoneDamagePerSecond = 10.0;

  static const asteroidCount = 50;
  static const soldierSquads = 6;
  static const soldiersPerSquad = 4;
  static const buildingCount = 7;
  static const barrierCount = 14;
  static const spawnRadius = 600.0;

  static const powerUpSlots = 14;
  static const powerUpFirstAt = 5.0;
  static const powerUpEvery = 7.0;
  static const repairAmount = 40.0;
  static const rapidFireSeconds = 8.0;
  static const rapidFireFactor = 0.45;
  static const smokeRadius = 130.0;
  static const smokeSeconds = 10.0;

  static const countdownSeconds = 3;
  static const roundOverSeconds = 6;

  /// Four paint schemes: Flecktarn green, Wüstentarn sand, Wintertarn white
  /// and NATO grey.
  static const shipColors = [
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

  /// Team 0 plays alone, 1 is red, 2 is blue.
  static const teamColors = [
    Color(0xFFE6E2D3),
    Color(0xFFE5533D),
    Color(0xFF4A90E2),
  ];
  static const teamNames = ['', 'ROT', 'BLAU'];

  static int styleOf(int tankType, int color) => tankType * 4 + color;

  static Color colorOf(int style) => shipColors[style % shipColors.length];

  static TankType typeOf(int style) =>
      TankType.values[(style ~/ shipColors.length) % TankType.values.length];
}
