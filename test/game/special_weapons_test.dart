import 'package:flutter_test/flutter_test.dart';
import 'package:wargame/src/game/components/power_up.dart';
import 'package:wargame/src/game/components/tank_painter.dart';
import 'package:wargame/src/game/special_weapon.dart';
import 'package:wargame/src/game/tank_stats.dart';
import 'package:wargame/src/net/payloads/special_payload.dart';

void main() {
  test('every tank starts with a magazine', () {
    for (final type in TankType.values) {
      expect(TankStats.of(type).ammo, greaterThan(0));
    }
  });

  test('the crate schedule hands out gems and stays the same per seed', () {
    final a = PowerUpSlot.schedule(42);
    final b = PowerUpSlot.schedule(42);
    expect([for (final s in a) s.type], [for (final s in b) s.type]);

    final types = {
      for (var seed = 0; seed < 50; seed++)
        for (final slot in PowerUpSlot.schedule(seed)) slot.type,
    };
    expect(types, containsAll(PowerUpType.values));
  });

  test('gems name their weapons, crates have none', () {
    expect(PowerUpType.grenades.weapon, SpecialWeapon.grenades);
    expect(PowerUpType.drone.weapon, SpecialWeapon.drone);
    expect(PowerUpType.ammo.weapon, isNull);
    expect(PowerUpType.ammo.gem, isTrue);
    expect(PowerUpType.repair.gem, isFalse);
  });

  test('blast damage halves towards the edge', () {
    const weapon = SpecialWeapon.grenades;
    expect(weapon.damageAt(0), weapon.damage);
    expect(weapon.damageAt(weapon.radius), weapon.damage / 2);
    expect(weapon.damageAt(weapon.radius * 3), weapon.damage / 2);
  });

  test('special weapon payloads survive the round trip', () {
    final grenade = GrenadePayload.fromJson(
      const GrenadePayload(
        id: 'a',
        grenadeId: 'a-g1',
        x: 1,
        y: 2,
        tx: 3,
        ty: 4,
      ).toJson(),
    );
    expect((grenade.grenadeId, grenade.tx, grenade.ty), ('a-g1', 3.0, 4.0));

    final drone = DronePayload.fromJson(
      const DronePayload(
        id: 'a',
        droneId: 'a-d2',
        x: 5,
        y: 6,
        angle: 1.5,
      ).toJson(),
    );
    expect((drone.droneId, drone.x, drone.angle), ('a-d2', 5.0, 1.5));

    final blast = BlastPayload.fromJson(
      BlastPayload(
        id: 'a',
        blastId: 'a-d2',
        weapon: SpecialWeapon.drone.name,
        x: 7,
        y: 8,
      ).toJson(),
    );
    expect(SpecialWeapon.values.byName(blast.weapon), SpecialWeapon.drone);
    expect((blast.x, blast.y), (7.0, 8.0));
  });
}
