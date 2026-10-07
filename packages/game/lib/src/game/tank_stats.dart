import 'components/tank_painter.dart';

/// What sets the vehicles apart on the field. The factors scale the
/// shared base values in `GameConfig`, damage and fire rate are absolute.
class TankStats {
  const TankStats({
    required this.maxHp,
    required this.speed,
    required this.acceleration,
    required this.turnRate,
    required this.fireCooldown,
    required this.damage,
    required this.bulletSpeed,
    required this.barrels,
    required this.ammo,
    required this.sound,
    required this.blurb,
  });

  final double maxHp;

  /// Factors on top speed, acceleration and turning rate.
  final double speed;
  final double acceleration;
  final double turnRate;

  final double fireCooldown;
  final double damage;
  final double bulletSpeed;

  /// Bullets per shot, fired side by side.
  final int barrels;

  /// Shots in a full magazine. A shot of the twin gun counts once.
  final int ammo;
  final String sound;
  final String blurb;

  /// Damage the type can deal per second when every shot lands.
  double get dps => damage * barrels / fireCooldown;

  static const _byType = {
    TankType.leopard: TankStats(
      maxHp: 140,
      speed: 0.85,
      acceleration: 0.8,
      turnRate: 0.85,
      fireCooldown: 0.6,
      ammo: 20,
      damage: 30,
      bulletSpeed: 520,
      barrels: 1,
      sound: 'cannon',
      blurb: 'Zäh und hart im Nehmen, langsame schwere Kanone',
    ),
    TankType.puma: TankStats(
      maxHp: 100,
      speed: 1.05,
      acceleration: 1.1,
      turnRate: 1.0,
      fireCooldown: 0.17,
      ammo: 90,
      damage: 8,
      bulletSpeed: 430,
      barrels: 1,
      sound: 'autocannon',
      blurb: 'Schnellfeuer mit der Maschinenkanone',
    ),
    TankType.gepard: TankStats(
      maxHp: 85,
      speed: 0.9,
      acceleration: 0.9,
      turnRate: 0.9,
      fireCooldown: 0.3,
      ammo: 45,
      damage: 9,
      bulletSpeed: 450,
      barrels: 2,
      sound: 'autocannon',
      blurb: 'Zwei Rohre gleichzeitig, breite Salven',
    ),
    TankType.boxer: TankStats(
      maxHp: 70,
      speed: 1.35,
      acceleration: 1.35,
      turnRate: 1.25,
      fireCooldown: 0.26,
      ammo: 55,
      damage: 11,
      bulletSpeed: 400,
      barrels: 1,
      sound: 'autocannon',
      blurb: 'Schnell und wendig, aber kaum gepanzert',
    ),
    TankType.wiesel: TankStats(
      maxHp: 60,
      speed: 1.5,
      acceleration: 1.5,
      turnRate: 1.35,
      fireCooldown: 1.2,
      damage: 38,
      ammo: 14,
      bulletSpeed: 640,
      barrels: 1,
      sound: 'cannon',
      blurb: 'Winzig und flink, die Panzerabwehrrakete trifft hart',
    ),
    TankType.lynx: TankStats(
      maxHp: 115,
      speed: 1.05,
      acceleration: 1.05,
      turnRate: 1.05,
      fireCooldown: 0.22,
      ammo: 70,
      damage: 12,
      bulletSpeed: 470,
      barrels: 1,
      sound: 'autocannon',
      blurb: 'Rheinmetall Lynx: 35-mm-Kanone, gut geschützt und flink',
    ),
    TankType.panther: TankStats(
      maxHp: 165,
      speed: 0.82,
      acceleration: 0.78,
      turnRate: 0.82,
      fireCooldown: 0.8,
      ammo: 16,
      damage: 42,
      bulletSpeed: 580,
      barrels: 1,
      sound: 'cannon',
      blurb: 'Rheinmetall Panther: 130-mm-Kanone, der schwerste Panzer im Feld',
    ),
  };

  static TankStats of(TankType type) => _byType[type]!;
}
