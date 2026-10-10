import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dart:ui';

import 'package:wargame/src/game/components/power_up.dart';
import 'package:wargame/src/game/components/tank_painter.dart';
import 'package:wargame/src/game/tank_stats.dart';
import 'package:wargame/src/game/defense/defense_map.dart';
import 'package:wargame/src/game/defense/tower.dart';
import 'package:wargame/src/game/inventory.dart';
import 'package:wargame/src/game/round_state.dart';
import 'package:wargame/src/game/special_weapon.dart';
import 'package:wargame/src/game/upgrades.dart';
import 'package:wargame/src/game/game_config.dart';
import 'package:wargame/src/net/payloads/defense_payload.dart';
import 'package:wargame/src/net/payloads/power_up_payload.dart';
import 'package:wargame/src/net/payloads/shoot_payload.dart';
import 'package:wargame/src/net/payloads/soldier_payload.dart';
import 'package:wargame/src/net/payloads/special_payload.dart';

/// Seeds that pick each of the layouts.
Iterable<int> get _layoutSeeds => [
  for (var i = 0; i < DefenseMap.layoutCount; i++) i * 4,
];

void main() {
  group('river and bridges', () {
    test('there are four layouts, each with a river and bridges', () {
      expect(DefenseMap.layoutCount, 4);
      final layouts = {
        for (final seed in _layoutSeeds) DefenseMap.layoutFor(seed),
      };
      expect(layouts, hasLength(4));
      for (final seed in _layoutSeeds) {
        final map = DefenseMap.forSeed(seed);
        expect(map.river.length, greaterThanOrEqualTo(2));
        expect(map.bridges, isNotEmpty);
      }
    });

    test('the road never runs through water, it crosses on bridges', () {
      for (final seed in _layoutSeeds) {
        final map = DefenseMap.forSeed(seed);
        for (var d = 0.0; d < map.roadLength; d += 8) {
          final (point, _) = map.alongRoad(d);
          expect(
            map.inWater(point, margin: GameConfig.tankRadius * 0.6),
            isFalse,
            reason: 'layout ${DefenseMap.layoutFor(seed)} at $point',
          );
        }
      }
    });

    test('the river is water away from the bridges', () {
      for (final seed in _layoutSeeds) {
        final map = DefenseMap.forSeed(seed);
        final dry =
            [
              for (var i = 0; i < map.river.length - 1; i++)
                (map.river[i] + map.river[i + 1]) / 2,
            ].where(
              (p) =>
                  map.bridgeAt(p) == null &&
                  DefenseMap.bounds.contains(p.toOffset()),
            );
        expect(dry.any(map.inWater), isTrue);
      }
    });

    test('players start on dry land and cannot build in the river', () {
      for (final seed in _layoutSeeds) {
        final map = DefenseMap.forSeed(seed);
        for (var i = 0; i < 4; i++) {
          expect(map.inWater(map.spawnFor(i, 4), margin: 20), isFalse);
        }
        final wet = map.river[1];
        if (map.bridgeAt(wet) == null) {
          expect(map.whyNotBuild(wet, const []), isNotNull);
        }
      }
    });

    test('crates of a defense round stay out of the water', () {
      for (final seed in _layoutSeeds) {
        final map = DefenseMap.forSeed(seed);
        final slots = PowerUpSlot.scheduleDefense(seed, map);
        expect(slots, hasLength(GameConfig.defensePowerUpSlots));
        expect(slots.where((s) => map.inWater(s.position)), isEmpty);
      }
    });
  });

  test('later waves bring helicopters, jets and drones', () {
    final first = DefenseMap.planFor(1);
    expect(first.helicopters + first.jets + first.drones, 0);
    expect(first.squads, greaterThan(0));
    final last = DefenseMap.planFor(GameConfig.defenseWaves);
    expect(last.helicopters, greaterThan(0));
    expect(last.jets, greaterThan(0));
    expect(last.drones, greaterThan(0));
    expect(last.total, greaterThan(first.total));
  });

  group('inventory', () {
    test('stacks one kind and keeps the order', () {
      final inventory = Inventory()
        ..add(PowerUpType.ammo)
        ..add(PowerUpType.smoke)
        ..add(PowerUpType.ammo);
      expect(
        [for (final s in inventory.value) s.type],
        [PowerUpType.ammo, PowerUpType.smoke],
      );
      expect(inventory.value.first.count, 2);
      expect(inventory.take(0), PowerUpType.ammo);
      expect(inventory.value.first.count, 1);
      expect(inventory.take(0), PowerUpType.ammo);
      expect(inventory.value.single.type, PowerUpType.smoke);
      expect(inventory.take(5), isNull);
    });

    test('refuses what does not fit', () {
      final inventory = Inventory();
      final kinds = PowerUpType.values.take(GameConfig.inventorySlots);
      for (final kind in kinds) {
        expect(inventory.add(kind), isTrue);
      }
      final other = PowerUpType.values[GameConfig.inventorySlots];
      expect(inventory.canTake(other), isFalse);
      expect(inventory.add(other), isFalse);
      for (var i = 1; i < GameConfig.inventoryStack; i++) {
        expect(inventory.add(kinds.first), isTrue);
      }
      expect(inventory.add(kinds.first), isFalse);
    });
  });

  test('new gems and the mortar', () {
    expect(PowerUpType.mortar.weapon, SpecialWeapon.mortar);
    expect(PowerUpType.infantry.gem, isTrue);
    expect(PowerUpType.paratroopers.gem, isTrue);
    expect(SpecialWeapon.mortar.lobbed, isTrue);
    expect(SpecialWeapon.drone.lobbed, isFalse);
    expect(
      SpecialWeapon.mortar.range,
      greaterThan(SpecialWeapon.grenades.range),
    );
    expect(
      SpecialWeapon.mortar.damage,
      greaterThan(SpecialWeapon.grenades.damage),
    );
  });

  test('gun kinds and their upgrades', () {
    expect(TowerKind.flak.antiAir, isTrue);
    expect(TowerKind.cannon.antiAir, isFalse);
    expect(TowerKind.mortar.minRange, greaterThan(0));
    for (final kind in TowerKind.values.where((k) => k.upgradable)) {
      expect(kind.damageFactor(3), greaterThan(kind.damageFactor(1)));
      expect(kind.rangeAt(3), greaterThan(kind.rangeAt(1)));
      expect(kind.cooldownAt(3), lessThan(kind.cooldownAt(1)));
      expect(kind.upgradeCost(2), greaterThan(kind.upgradeCost(1)));
    }
    expect(UpgradeKind.armor.factorAt(2), lessThan(1));
    expect(UpgradeKind.gun.factorAt(2), greaterThan(1));
    expect(
      UpgradeKind.magazine.costFrom(1),
      greaterThan(UpgradeKind.magazine.costFrom(0)),
    );
  });

  test('squads of a team round take sides, enemies have names', () {
    final teams = RoundState(
      seed: 1,
      startedAt: 2,
      participants: const ['a', 'b'],
      teams: const {'a': 1, 'b': 2},
    );
    expect(teams.teamOf('inf-1'), 1);
    expect(teams.teamOf('inf-2'), 2);
    final defense = RoundState(
      seed: 1,
      startedAt: 2,
      participants: const ['a'],
      botHost: 'a',
      defense: true,
    );
    expect(defense.botName('td-h-2-1'), 'HUBSCHRAUBER');
    expect(defense.botName('td-j-3-4'), 'KAMPFJET');
    expect(defense.botName('td-i-1-0'), 'INFANTERIE');
    expect(defense.botName('td-d-4-9'), 'FEINDDROHNE');
    expect(defense.botName('td-2-1'), 'FEIND');
    expect(defense.teamOf('td-h-2-1'), 2);
  });

  test('the new messages travel over the wire', () {
    final squad = SquadPayload.fromJson(
      const SquadPayload(
        id: 'a',
        owner: 'td-i-1-0',
        squad: 'td-i-1-0',
        x: 1,
        y: 2,
        at: 3,
        rifles: 4,
        rockets: 1,
        road: true,
      ).toJson(),
    );
    expect(
      (squad.owner, squad.count, squad.road, squad.para),
      ('td-i-1-0', 5, true, false),
    );

    final air = AirPayload.fromJson(
      const AirPayload(
        id: 'a',
        unit: 'td-h-1-1',
        kind: 1,
        x: 4,
        y: 5,
        angle: 0.5,
        hp: 0,
        killer: 'b',
      ).toJson(),
    );
    expect((air.unit, air.kind, air.hp, air.killer), ('td-h-1-1', 1, 0.0, 'b'));

    final use = UsePayload.fromJson(
      const UsePayload(id: 'a', item: 'repair').toJson(),
    );
    expect(use.item, 'repair');

    final tower = TowerPayload.fromJson(
      const TowerPayload(
        id: 'a',
        index: 1,
        x: 0,
        y: 0,
        kind: 2,
        level: 3,
      ).toJson(),
    );
    expect((tower.kind, tower.level), (2, 3));
    expect(
      TowerPayload.fromJson({'id': 'a', 'index': 0, 'x': 0, 'y': 0}).level,
      1,
    );

    final shot = ShootPayload.fromJson(
      const ShootPayload(
        id: 'a',
        bulletId: 'a-1',
        x: 0,
        y: 0,
        dx: 1,
        dy: 0,
        soldier: 'a-q0/2',
        damage: 12,
      ).toJson(),
    );
    expect((shot.soldier, shot.damage, shot.air), ('a-q0/2', 12.0, false));

    final grenade = GrenadePayload.fromJson(
      const GrenadePayload(
        id: 'a',
        grenadeId: 'g',
        x: 0,
        y: 0,
        tx: 1,
        ty: 1,
        weapon: 'shell',
        power: 1.7,
        tower: 2,
      ).toJson(),
    );
    expect((grenade.weapon, grenade.power, grenade.tower), ('shell', 1.7, 2));

    final killed = SoldierPayload.fromJson(
      const SoldierPayload(id: 'a', key: 'x/1', raid: true).toJson(),
    );
    expect((killed.key, killed.raid, killed.index), ('x/1', true, -1));

    final smoke = SmokePayload.fromJson(
      const SmokePayload(id: 'a', x: 1, y: 2, fromX: 3, fromY: 4).toJson(),
    );
    expect((smoke.fromX, smoke.fromY), (3.0, 4.0));
  });

  test('a bridge carries what is on its deck only', () {
    final bridge = Bridge(
      centre: Vector2.zero(),
      along: Vector2(1, 0),
      halfLength: 50,
      halfWidth: 20,
    );
    expect(bridge.carries(Vector2(40, 10)), isTrue);
    expect(bridge.carries(Vector2(40, 30)), isFalse);
    expect(bridge.carries(Vector2(60, 0)), isFalse);
  });

  test('two late vehicles join, unlocked by rank', () {
    expect(TankType.values, containsAll([TankType.dachs, TankType.wolf]));
    final free = TankType.values.where((t) => t.level == 1);
    expect(free.length, greaterThanOrEqualTo(3));
    expect(TankType.wolf.level, greaterThan(TankType.dachs.level));
    expect(TankType.dachs.level, greaterThan(1));
    final wolf = TankStats.of(TankType.wolf);
    final keiler = TankStats.of(TankType.keiler);
    expect(wolf.damage, greaterThan(keiler.damage));
    expect(wolf.maxHp, greaterThan(keiler.maxHp));
    expect(TankStats.of(TankType.dachs).ammo, greaterThan(0));
    // Old looks keep their vehicle: the new ones only add styles at the end.
    expect(GameConfig.typeOf(GameConfig.styleOf(4, 2)), TankType.spitzmaus);
    expect(GameConfig.typeOf(GameConfig.styleOf(6, 1)), TankType.wolf);
  });

  test('every vehicle can be drawn, also battered and burning', () {
    for (final type in TankType.values) {
      final recorder = PictureRecorder();
      paintTank(
        Canvas(recorder),
        48,
        type,
        const Color(0xFF6B7F3A),
        turretAngle: 0.4,
        flash: 1,
        wear: 0.9,
        flame: 1.5,
      );
      recorder.endRecording().dispose();
    }
  });
}
