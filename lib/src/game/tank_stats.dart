import '../l10n/l10n.dart';
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
    required this.blurbDe,
    required this.blurbEn,
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
  final String blurbDe;
  final String blurbEn;
  String get blurb => tr(blurbDe, blurbEn);

  /// Damage the type can deal per second when every shot lands.
  double get dps => damage * barrels / fireCooldown;

  /// Later vehicles are stronger: every one a higher rank unlocks adds up to
  /// more over its four bars in the lobby (armour, speed, turning,
  /// firepower) than every one before it. The test for it keeps it so.
  static const _byType = {
    TankType.elch: TankStats(
      maxHp: 165,
      speed: 0.95,
      acceleration: 0.9,
      turnRate: 0.92,
      fireCooldown: 0.52,
      ammo: 20,
      damage: 33,
      bulletSpeed: 520,
      barrels: 1,
      sound: 'cannon',
      blurbDe: 'Zäh und hart im Nehmen, langsame schwere Kanone',
      blurbEn: 'Tough and hard to kill, slow heavy cannon',
    ),
    TankType.hermelin: TankStats(
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
      blurbDe: 'Schnellfeuer mit der Maschinenkanone',
      blurbEn: 'Rapid fire with the autocannon',
    ),
    TankType.habicht: TankStats(
      maxHp: 105,
      speed: 1.05,
      acceleration: 1.05,
      turnRate: 1.05,
      fireCooldown: 0.26,
      ammo: 45,
      damage: 9,
      bulletSpeed: 450,
      barrels: 2,
      sound: 'autocannon',
      blurbDe: 'Zwei Rohre gleichzeitig, breite Salven',
      blurbEn: 'Two barrels at once, wide salvos',
    ),
    TankType.otter: TankStats(
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
      blurbDe: 'Schnell und wendig, aber kaum gepanzert',
      blurbEn: 'Fast and nimble, but barely armoured',
    ),
    TankType.spitzmaus: TankStats(
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
      blurbDe: 'Winzig und flink, die Panzerabwehrrakete trifft hart',
      blurbEn: 'Tiny and quick, the anti-tank missile hits hard',
    ),
    TankType.manul: TankStats(
      maxHp: 135,
      speed: 1.15,
      acceleration: 1.15,
      turnRate: 1.15,
      fireCooldown: 0.2,
      ammo: 70,
      damage: 14,
      bulletSpeed: 470,
      barrels: 1,
      sound: 'autocannon',
      blurbDe: 'Manul: 35-mm-Kanone, gut geschützt und flink',
      blurbEn: 'Manul: 35 mm cannon, well protected and quick',
    ),
    TankType.auerochse: TankStats(
      maxHp: 190,
      speed: 1.0,
      acceleration: 0.95,
      turnRate: 0.98,
      fireCooldown: 0.64,
      ammo: 16,
      damage: 50,
      bulletSpeed: 580,
      barrels: 1,
      sound: 'cannon',
      blurbDe: 'Auerochse: 130-mm-Kanone, der schwerste Panzer im Feld',
      blurbEn: 'Auerochse: 130 mm cannon, the heaviest tank in the field',
    ),
    TankType.walross: TankStats(
      maxHp: 185,
      speed: 0.95,
      acceleration: 0.85,
      turnRate: 0.9,
      fireCooldown: 1.05,
      ammo: 12,
      damage: 75,
      bulletSpeed: 700,
      barrels: 1,
      sound: 'cannon',
      blurbDe: 'Walross: 155-mm-Rohr, lädt langsam, trifft verheerend',
      blurbEn: 'Walross: 155 mm gun, reloads slowly, hits devastatingly',
    ),
  };

  static TankStats of(TankType type) => _byType[type]!;
}
