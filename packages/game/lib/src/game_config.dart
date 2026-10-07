import 'dart:math';

import 'package:flutter/material.dart';

import 'game/components/tank_painter.dart';

class GameConfig {
  static const worldRadius = 900.0;

  /// World units that fit along the shorter side of the window.
  static const viewShortSide = 720.0;

  /// How far the ground and the danger zone are drawn from the middle, far
  /// enough that a wide window never shows the void.
  static const groundReach = worldRadius * 2.8;

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
  static const silentTankTimeout = Duration(seconds: 8);
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

  static const powerUpSlots = 18;
  static const powerUpFirstAt = 5.0;
  static const powerUpEvery = 6.0;
  static const repairAmount = 40.0;
  static const rapidFireSeconds = 8.0;
  static const rapidFireFactor = 0.45;

  /// Paratroopers drop in waves and walk like the other infantry once down.
  static const paraFirstWave = 18.0;
  static const paraWaveEvery = 22.0;
  static const paraWaves = 5;
  static const paraPerWave = 4;
  static const paraFallSeconds = 4.0;

  static const smokeRadius = 130.0;
  static const smokeSeconds = 10.0;

  /// A shield lets only part of the damage through for a few seconds.
  static const shieldSeconds = 8.0;
  static const shieldFactor = 0.4;

  static const minesPerCrate = 3;
  static const mineRadius = 12.0;
  static const mineArmSeconds = 1.0;
  static const mineDamage = 35.0;

  /// Seconds between calling in a barrage and the shells landing.
  static const artilleryDelay = 2.5;
  static const artilleryRadius = 110.0;
  static const artilleryDamage = 45.0;
  static const artilleryRange = 360.0;

  /// Defense: the base, the waves and the guns the players put down.
  static const defenseWaves = 8;
  static const baseHp = 1500.0;
  static const raidDamage = 120.0;
  static const firstWaveSeconds = 8;
  static const waveBreakSeconds = 12;
  static const enemySpawnEvery = 1.6;
  static const maxEnemiesAlive = 6;
  static const enemySpeed = 0.6;
  static const enemyFireFactor = 3.0;
  static const enemySyncInterval = 0.1;
  static const respawnSeconds = 6.0;

  /// How close to the base a tank refills, and how long a full magazine
  /// takes there.
  static const resupplyReach = 130.0;
  static const resupplySeconds = 4.0;
  static const startCredits = 150;
  static const creditsPerKill = 20;
  static const waveBonus = 50;
  static const towerCost = 100;
  static const maxTowers = 6;
  static const towerSpacing = 60.0;
  static const towerRange = 420.0;
  static const towerCooldown = 0.45;
  static const towerDamage = 18.0;
  static const towerBulletSpeed = 560.0;

  /// Share of the full magazine an ammo gem puts back.
  static const ammoRefillShare = 0.6;

  /// At or below this share of the magazine the HUD warns.
  static const ammoLowShare = 0.2;

  static const grenadeCharges = 3;
  static const grenadeCooldown = 1.1;
  static const grenadeRange = 380.0;
  static const grenadeMinRange = 90.0;
  static const grenadeFlightSeconds = 0.9;
  static const grenadeRadius = 85.0;
  static const grenadeDamage = 45.0;

  static const droneCharges = 1;
  static const droneCooldown = 1.5;
  static const droneSpeed = 230.0;
  static const droneTurnRate = 3.2;
  static const droneSeconds = 10.0;
  static const droneTrigger = 34.0;
  static const droneRadius = 75.0;
  static const droneDamage = 60.0;
  static const droneSyncInterval = 0.08;

  static const countdownSeconds = 3;

  /// How many CPU tanks a single player round rolls, both ends included.
  static const minBots = 1;
  static const maxBots = 4;

  /// With other people, CPU tanks fill the field up to this many tanks.
  static const fillTo = 4;
  static const roundOverSeconds = 10;

  /// Paint schemes: Flecktarn green, Wüstentarn sand, Wintertarn white and
  /// NATO grey for everybody, then four that come with higher ranks.
  static const shipColors = [
    Color(0xFF6B7F3A),
    Color(0xFFC2A878),
    Color(0xFFD8DCD6),
    Color(0xFF8C8C84),
    Color(0xFF3E5C7A),
    Color(0xFF2C2C2A),
    Color(0xFF8B3E2B),
    Color(0xFFC9A227),
  ];

  static const colorNames = [
    'FLECKTARN',
    'WÜSTENTARN',
    'WINTERTARN',
    'NATO-GRAU',
    'MARINEBLAU',
    'NACHTSCHWARZ',
    'ROSTROT',
    'EHRENGOLD',
  ];

  /// Rank a paint scheme needs.
  static const colorLevels = [1, 1, 1, 1, 3, 5, 7, 10];

  /// A player's look travels as one number, the vehicle times the number of
  /// paint schemes plus the scheme, so the wire format stays a single int.
  static final styleCount = TankType.values.length * shipColors.length;

  /// Multiplayer rounds paint every tank in its own loud colour instead of
  /// camouflage, so players tell each other apart at a glance. Red and blue
  /// are left out, they belong to the teams.
  static const playerColors = [
    Color(0xFFF2C230),
    Color(0xFF2EC4B6),
    Color(0xFFD94BC0),
    Color(0xFFF08A24),
    Color(0xFF9BD93B),
    Color(0xFF8E6CEF),
    Color(0xFFF2F2F2),
    Color(0xFFFF8FA3),
  ];

  /// Colour of the player at [index] in a multiplayer round.
  static Color playerColor(int index) =>
      playerColors[index % playerColors.length];

  static const lobbyIdleTimeout = Duration(minutes: 10);

  /// How long the room may be without a host, or with two, before it settles
  /// the question itself.
  static const hostSettleSeconds = 3.0;

  /// Team 0 plays alone, 1 is red, 2 is blue.
  static const teamColors = [
    Color(0xFFE6E2D3),
    Color(0xFFE5533D),
    Color(0xFF4A90E2),
  ];
  static const teamNames = ['', 'ROT', 'BLAU'];

  static int styleOf(int tankType, int color) =>
      tankType * shipColors.length + color;

  /// Paint schemes everybody has from the start.
  static const freeColors = 4;

  /// A vehicle and one of the free paint schemes, for a fresh player or a
  /// CPU tank.
  static int randomStyle(Random random) => styleOf(
    random.nextInt(TankType.values.length),
    random.nextInt(freeColors),
  );

  static Color colorOf(int style) => shipColors[style % shipColors.length];

  static TankType typeOf(int style) =>
      TankType.values[(style ~/ shipColors.length) % TankType.values.length];
}
