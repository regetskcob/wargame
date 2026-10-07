import 'dart:math';

import 'package:flutter/material.dart';

import 'game/components/tank_painter.dart';

class GameConfig {
  static const worldRadius = 900.0;

  /// World units that fit along the shorter side of the window.
  static const viewShortSide = 720.0;

  /// The same for a defense round, wide enough to see most of the field:
  /// the road, the guns and where the next wave comes from.
  static const defenseViewShortSide = 1150.0;

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
  static const defensePowerUpSlots = 80;
  static const defensePowerUpFirstAt = 10.0;
  static const defensePowerUpEvery = 9.0;
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

  /// The base grows from a watchtower to barracks to a fortress after waves
  /// beaten off while losing at most [hqCleanLoss] of its hit points. Each
  /// step adds hit points, a comrade, room for two more guns and a gun on
  /// the base itself.
  static const hqNames = ['WACHTURM', 'KASERNE', 'FESTUNG'];
  static const hqCleanWaves = [0, 2, 4];
  static const hqCleanLoss = 0.15;
  static const hqHpStep = 500.0;
  static const hqTowerStep = 2;

  static int hqLevelFor(int cleanWaves) {
    var level = 1;
    for (var i = 1; i < hqCleanWaves.length; i++) {
      if (cleanWaves >= hqCleanWaves[i]) {
        level = i + 1;
      }
    }
    return level;
  }

  static double baseMaxHp(int hq) => baseHp + hqHpStep * (hq - 1);
  static String hqName(int hq) => hqNames[(hq - 1).clamp(0, 2)];
  static const raidDamage = 120.0;
  static const firstWaveSeconds = 8;
  static const waveBreakSeconds = 12;
  static const enemySpawnEvery = 1.6;
  static const maxEnemiesAlive = 6;
  static const enemySpeed = 0.6;
  static const enemyFireFactor = 3.0;
  static const enemySyncInterval = 0.1;
  static const respawnSeconds = 6.0;

  /// Nobody holds the base alone: CPU comrades fill the squad up to this
  /// size, at least one of them even with a full room. They come back from
  /// the base a while after they were destroyed.
  static const defenseSquad = 4;
  static const allyRespawnSeconds = 10.0;
  static const allyRange = 440.0;

  /// How far the touch aim assist looks for a target.
  static const assistRange = 420.0;

  /// The base's own aircraft: a helicopter every wave from [supportFromWave]
  /// on, a bombing jet as well from [supportJetFromWave], some seconds into
  /// the wave so the enemy is on the road.
  static const supportFromWave = 3;
  static const supportJetFromWave = 5;
  static const supportJetDelay = 14.0;
  static const supportHelicopterSeconds = 40.0;
  static const supportHelicopterReach = 520.0;

  /// How close to the base a tank refills, and how long a full magazine
  /// takes there.
  static const resupplyReach = 130.0;
  static const resupplySeconds = 4.0;
  static const startCredits = 150;
  static const creditsPerKill = 20;
  static const waveBonus = 50;
  static const towerCost = 100;
  static const maxTowers = 6;

  /// Trenches: how many a player may dig, how close a tank has to be to
  /// sit in one and what share of a hit still gets through.
  static const maxTrenches = 4;
  static const trenchReach = 34.0;
  static const trenchCover = 0.5;
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

  /// A portable mortar from a gem: further and harder than the grenade
  /// launcher, but slow to land.
  static const mortarCharges = 4;
  static const mortarCooldown = 1.8;
  static const mortarRange = 560.0;
  static const mortarMinRange = 140.0;
  static const mortarFlightSeconds = 1.6;
  static const mortarRadius = 95.0;
  static const mortarDamage = 55.0;

  /// Shells of a mortar emplacement in a defense round.
  static const shellRadius = 75.0;
  static const shellDamage = 50.0;
  static const shellFlightSeconds = 1.3;

  /// Inventory at the side of the screen: how many kinds it holds and how
  /// many of one kind stack in a slot.
  static const inventorySlots = 6;
  static const inventoryStack = 5;

  /// Smoke grenades from the inventory are thrown this far at most.
  static const smokeThrowRange = 300.0;
  static const smokeFlightSeconds = 0.8;

  /// Soldiers on foot. Riflemen are quick to fire and deadly to soldiers,
  /// the rocket launchers of paratroopers hurt tanks.
  static const rifleRange = 220.0;
  static const rifleCooldown = 1.3;
  static const rifleDamage = 1.0;
  static const rifleSpeed = 480.0;
  static const rocketRange = 300.0;
  static const rocketCooldown = 4.0;
  static const rocketDamage = 18.0;
  static const rocketSpeed = 300.0;

  /// A squad from a gem, deployed next to the tank: riflemen and one rocket.
  static const squadRifles = 4;
  static const squadRockets = 1;

  /// A drop of paratroopers from a gem, all with rocket launchers.
  static const paraDropRockets = 4;
  static const paraDropRange = 420.0;

  /// Enemy soldiers march down the road of a defense round at this pace and
  /// hurt the base when they reach it.
  static const marchSpeed = 70.0;
  static const soldierRaidDamage = 25.0;
  static const creditsPerSoldier = 5;

  /// Enemy aircraft of a defense round.
  static const helicopterHp = 120.0;
  static const helicopterSpeed = 110.0;
  static const helicopterHover = 260.0;
  static const helicopterCooldown = 1.8;
  static const helicopterDamage = 10.0;
  static const helicopterRange = 420.0;
  static const helicopterShotSpeed = 380.0;
  static const jetHp = 80.0;
  static const jetSpeed = 420.0;
  static const jetBombs = 3;
  static const airSyncInterval = 0.1;
  static const creditsPerAircraft = 40;

  /// Shells that are not built to hit aircraft only scratch a helicopter
  /// and never touch a jet. Flak and the Gepard hit them hard.
  static const groundGunVsHelicopter = 0.25;
  static const antiAirFactor = 2.0;

  /// Enemy kamikaze drones fly longer than the ones from gems, the road is
  /// long.
  static const enemyDroneSeconds = 18.0;

  /// Upgrades of the tank in a defense round.
  static const upgradeBaseCost = 80;
  static const upgradeMaxLevel = 3;

  /// Fuel, from the middle difficulty on. A full tank lasts about this many
  /// seconds at full throttle, standing still burns a little. Empty, the
  /// engine only crawls.
  static const fuelSeconds = 95.0;
  static const fuelIdleShare = 0.15;
  static const fuelLowShare = 0.25;
  static const emptyTankSpeed = 0.3;

  /// Share of the tank a canister puts back.
  static const canisterShare = 0.65;

  /// The bomber from a gem on the hard level.
  static const airstrikeBombs = 4;
  static const airstrikeReach = 700.0;

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

  /// Multiplayer rounds paint every tank in its own colour instead of the
  /// camouflage, so players tell each other apart at a glance. The colours
  /// come from the Bundeswehr's paints, the most different ones first. Red
  /// and blue are left out, they belong to the teams.
  static const playerColors = [
    Color(0xFFCDB57E), // Sandgelb
    Color(0xFFA9603A), // Lederbraun
    Color(0xFFE4DECB), // Wintertarn
    Color(0xFF8E9DA6), // Feldgrau
    Color(0xFF8E9B4E), // Gelboliv
    Color(0xFF8A6B4A), // Erdbraun
    Color(0xFF55703C), // Bronzegrün
    Color(0xFF5D6A70), // Basaltgrau
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

  /// Any vehicle and one of the free paint schemes, for a CPU tank.
  static int randomStyle(Random random) => styleOf(
    random.nextInt(TankType.values.length),
    random.nextInt(freeColors),
  );

  /// A vehicle everybody has from the start and a free paint scheme, for a
  /// fresh player: nobody begins in a vehicle their rank does not allow.
  static int randomStarterStyle(Random random) {
    final free = [
      for (final type in TankType.values)
        if (type.level <= 1) type,
    ];
    return styleOf(
      free[random.nextInt(free.length)].index,
      random.nextInt(freeColors),
    );
  }

  static Color colorOf(int style) => shipColors[style % shipColors.length];

  static TankType typeOf(int style) =>
      TankType.values[(style ~/ shipColors.length) % TankType.values.length];
}
