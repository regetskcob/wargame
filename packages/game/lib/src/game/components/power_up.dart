import 'dart:math';
import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';

import 'package:flutter/material.dart' show IconData, Icons, TextPainter;
import 'package:flutter/painting.dart' show TextSpan, TextStyle;

import '../../game_config.dart';
import '../bot_level.dart';
import '../defense/defense_map.dart';
import '../special_weapon.dart';
import 'storm_zone.dart';

enum PowerUpType {
  repair('REPARATUR', Color(0xFF66BB6A)),
  smoke('NEBELWERFER', Color(0xFFB0BEC5)),
  rapidFire('SCHNELLFEUER', Color(0xFFFFB300)),
  shield('SCHILD', Color(0xFF80DEEA)),
  mines('MINEN', Color(0xFFE57373)),
  artillery('ARTILLERIE', Color(0xFFFF7043)),

  /// Gems: refill the magazine or hand out a special weapon.
  ammo('MUNITION', Color(0xFF4FC3F7), gem: true),
  grenades('GRANATWERFER', Color(0xFFEF5350), gem: true),
  drone('DROHNE', Color(0xFFB388FF), gem: true),
  mortar('MÖRSER', Color(0xFFFF8A65), gem: true),

  /// A squad on foot that fights next to the tank.
  infantry('INFANTERIE', Color(0xFF9CCC65), gem: true),

  /// A drop of paratroopers with rocket launchers onto the cursor.
  paratroopers('FALLSCHIRMJÄGER', Color(0xFFFFD54F), gem: true),

  /// A jerrycan that fills the tank up again, from the middle level on.
  fuel('KANISTER', Color(0xFFFF9100), gem: true),

  /// A drone that takes off from the inventory and hunts an enemy picked at
  /// random.
  hunterDrone('JAGDDROHNE', Color(0xFF26C6DA), gem: true),

  /// A bomber that crosses the field and bombs an enemy, on the hard level.
  airstrike('LUFTSCHLAG', Color(0xFF90CAF9), gem: true);

  const PowerUpType(this.label, this.color, {this.gem = false});

  final String label;
  final Color color;

  /// Drawn as a gem instead of a crate.
  final bool gem;

  /// The special weapon this gem hands out, if any.
  SpecialWeapon? get weapon => switch (this) {
    PowerUpType.grenades => SpecialWeapon.grenades,
    PowerUpType.drone => SpecialWeapon.drone,
    PowerUpType.mortar => SpecialWeapon.mortar,
    _ => null,
  };

  /// Short name for the inventory slot.
  String get short => switch (this) {
    PowerUpType.repair => 'REPARATUR',
    PowerUpType.smoke => 'NEBEL',
    PowerUpType.rapidFire => 'SCHNELLF.',
    PowerUpType.shield => 'SCHILD',
    PowerUpType.mines => 'MINEN',
    PowerUpType.artillery => 'ARTILLERIE',
    PowerUpType.ammo => 'MUNITION',
    PowerUpType.grenades => 'GRANATEN',
    PowerUpType.drone => 'DROHNE',
    PowerUpType.mortar => 'MÖRSER',
    PowerUpType.infantry => 'TRUPP',
    PowerUpType.paratroopers => 'FALLSCH.',
    PowerUpType.fuel => 'KANISTER',
    PowerUpType.hunterDrone => 'JAGDDR.',
    PowerUpType.airstrike => 'LUFTSCHL.',
  };

  /// The symbol on the gem, in the inventory and on the crate list.
  IconData get icon => switch (this) {
    PowerUpType.repair => Icons.build,
    PowerUpType.smoke => Icons.cloud,
    PowerUpType.rapidFire => Icons.fast_forward,
    PowerUpType.shield => Icons.shield,
    PowerUpType.mines => Icons.brightness_7,
    PowerUpType.artillery => Icons.gps_fixed,
    PowerUpType.ammo => Icons.inventory_2,
    PowerUpType.grenades => Icons.sports_baseball,
    PowerUpType.drone => Icons.toys,
    PowerUpType.mortar => Icons.vertical_align_top,
    PowerUpType.infantry => Icons.groups,
    PowerUpType.paratroopers => Icons.paragliding,
    PowerUpType.fuel => Icons.local_gas_station,
    PowerUpType.hunterDrone => Icons.track_changes,
    PowerUpType.airstrike => Icons.flight,
  };

  /// Whether this turns up at all on [level]: on the easy level the tank
  /// never runs dry of shells or fuel, the bomber is for the hard level.
  bool comesOn(BotLevel level) => switch (this) {
    PowerUpType.ammo || PowerUpType.fuel => level != BotLevel.easy,
    PowerUpType.airstrike => level == BotLevel.hard,
    _ => true,
  };

  /// Picks a type from a roll between 0 and 1, among those that come on
  /// [level]. Ammo gems are the most common drop, since every shot costs a
  /// round.
  static PowerUpType fromRoll(double roll, [BotLevel level = BotLevel.hard]) {
    final odds = [
      for (final entry in _odds)
        if (entry.$1.comesOn(level)) entry,
    ];
    final total = odds.fold(0.0, (sum, entry) => sum + entry.$2);
    var sum = 0.0;
    for (final (type, share) in odds) {
      sum += share / total;
      if (roll < sum) {
        return type;
      }
    }
    return odds.last.$1;
  }
}

/// One planned crate: when it appears, where and what it holds. Derived from
/// the round seed alone, so every client sees the same crates without any
/// network traffic.
class PowerUpSlot {
  const PowerUpSlot({
    required this.id,
    required this.appearsAt,
    required this.position,
    required this.type,
  });

  final int id;
  final double appearsAt;
  final Vector2 position;
  final PowerUpType type;

  /// Crates of a defense round: one every few seconds for as long as a
  /// round can last, scattered over the field away from the road, the river
  /// and the base.
  static List<PowerUpSlot> scheduleDefense(
    int seed,
    DefenseMap map, [
    BotLevel level = BotLevel.hard,
  ]) {
    final random = Random(seed ^ 0x2d1fe5);
    final slots = <PowerUpSlot>[];
    for (var i = 0; i < GameConfig.defensePowerUpSlots; i++) {
      var position = Vector2.zero();
      for (var attempt = 0; attempt < 30; attempt++) {
        position = Vector2(
          (random.nextDouble() * 2 - 1) * (DefenseMap.halfWidth - 80),
          (random.nextDouble() * 2 - 1) * (DefenseMap.halfHeight - 80),
        );
        if (map.distanceToRoad(position) > DefenseMap.roadHalfWidth + 40 &&
            !map.inWater(position, margin: 30) &&
            position.distanceTo(map.base) > DefenseMap.baseRadius + 60) {
          break;
        }
      }
      slots.add(
        PowerUpSlot(
          id: i,
          appearsAt:
              GameConfig.defensePowerUpFirstAt +
              i * GameConfig.defensePowerUpEvery,
          position: position,
          type: PowerUpType.fromRoll(random.nextDouble(), level),
        ),
      );
    }
    return slots;
  }

  static List<PowerUpSlot> schedule(
    int seed, [
    BotLevel level = BotLevel.hard,
  ]) {
    final random = Random(seed ^ 0x5bd1e995);
    return [
      for (var i = 0; i < GameConfig.powerUpSlots; i++)
        () {
          final appearsAt =
              GameConfig.powerUpFirstAt + i * GameConfig.powerUpEvery;
          final startedAt = 0;
          final safe = StormZone.radiusAt(
            startedAt,
            startedAt + (appearsAt * 1000).round(),
          );
          final distance =
              sqrt(random.nextDouble()) * (safe - 60).clamp(80, 800);
          final direction = random.nextDouble() * 2 * pi;
          final roll = random.nextDouble();
          return PowerUpSlot(
            id: i,
            appearsAt: appearsAt,
            position: Vector2(cos(direction), sin(direction))..scale(distance),
            type: PowerUpType.fromRoll(roll, level),
          );
        }(),
    ];
  }
}

/// How often each crate and gem turns up, the shares add up to 1.
const _odds = [
  (PowerUpType.repair, 0.14),
  (PowerUpType.rapidFire, 0.08),
  (PowerUpType.smoke, 0.08),
  (PowerUpType.shield, 0.08),
  (PowerUpType.mines, 0.07),
  (PowerUpType.artillery, 0.07),
  (PowerUpType.ammo, 0.2),
  (PowerUpType.fuel, 0.12),
  (PowerUpType.hunterDrone, 0.05),
  (PowerUpType.airstrike, 0.04),
  (PowerUpType.grenades, 0.06),
  (PowerUpType.drone, 0.05),
  (PowerUpType.mortar, 0.05),
  (PowerUpType.infantry, 0.05),
  (PowerUpType.paratroopers, 0.05),
];

/// A crate lying on the field, picked up by driving over it.
class PowerUp extends PositionComponent {
  PowerUp({required this.slot})
    : super(
        position: slot.position.clone(),
        size: Vector2.all(36),
        anchor: Anchor.center,
        priority: 4,
      );

  final PowerUpSlot slot;
  PowerUpType get type => slot.type;
  double _time = 0;

  @override
  void onLoad() {
    add(CircleHitbox());
  }

  @override
  void update(double dt) {
    _time += dt;
  }

  @override
  void render(Canvas canvas) {
    if (type.gem) {
      _renderGem(canvas);
      return;
    }
    final center = (size / 2).toOffset();
    final pulse = 1 + 0.08 * sin(_time * 4);
    final color = type.color;
    canvas.drawCircle(
      center,
      20 * pulse,
      Paint()..color = color.withValues(alpha: 0.25),
    );
    canvas.drawRect(
      Rect.fromCenter(center: center, width: 26, height: 26),
      Paint()..color = const Color(0xFF1E2614),
    );
    canvas.drawRect(
      Rect.fromCenter(center: center, width: 26, height: 26),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = color,
    );
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    switch (type) {
      case PowerUpType.repair:
        canvas.drawLine(center.translate(-7, 0), center.translate(7, 0), paint);
        canvas.drawLine(center.translate(0, -7), center.translate(0, 7), paint);
      case PowerUpType.rapidFire:
        for (final dy in [-5.0, 3.0]) {
          canvas.drawPath(
            Path()
              ..moveTo(center.dx - 6, center.dy + dy + 4)
              ..lineTo(center.dx, center.dy + dy - 2)
              ..lineTo(center.dx + 6, center.dy + dy + 4),
            paint,
          );
        }
      case PowerUpType.smoke:
        final fill = Paint()..color = color;
        canvas.drawCircle(center.translate(-4, 2), 4.5, fill);
        canvas.drawCircle(center.translate(4, 2), 4.5, fill);
        canvas.drawCircle(center.translate(0, -3), 5, fill);
      case PowerUpType.shield:
        canvas.drawPath(
          Path()
            ..moveTo(center.dx, center.dy - 8)
            ..lineTo(center.dx + 7, center.dy - 5)
            ..lineTo(center.dx + 6, center.dy + 3)
            ..lineTo(center.dx, center.dy + 8)
            ..lineTo(center.dx - 6, center.dy + 3)
            ..lineTo(center.dx - 7, center.dy - 5)
            ..close(),
          paint..strokeWidth = 2.5,
        );
      case PowerUpType.mines:
        final fill = Paint()..color = color;
        canvas.drawCircle(center, 6, fill);
        for (var i = 0; i < 4; i++) {
          final a = i * pi / 2;
          canvas.drawLine(
            center + Offset(cos(a), sin(a)) * 6,
            center + Offset(cos(a), sin(a)) * 9,
            paint..strokeWidth = 2,
          );
        }
      case PowerUpType.artillery:
        canvas.drawCircle(center, 7, paint..strokeWidth = 2);
        canvas.drawLine(
          center.translate(-10, 0),
          center.translate(10, 0),
          paint,
        );
        canvas.drawLine(
          center.translate(0, -10),
          center.translate(0, 10),
          paint,
        );
      case PowerUpType.ammo ||
          PowerUpType.grenades ||
          PowerUpType.drone ||
          PowerUpType.mortar ||
          PowerUpType.infantry ||
          PowerUpType.paratroopers ||
          PowerUpType.fuel ||
          PowerUpType.hunterDrone ||
          PowerUpType.airstrike:
        break;
    }
  }

  static final _glyphs = <PowerUpType, TextPainter>{};

  /// A round plate above the gem with the symbol of what it holds.
  void _badge(Canvas canvas, Offset at, Color color) {
    canvas.drawCircle(at, 9.5, Paint()..color = const Color(0xDD1E2614));
    canvas.drawCircle(
      at,
      9.5,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = color,
    );
    final glyph = _glyphs.putIfAbsent(type, () {
      final icon = type.icon;
      return TextPainter(
        text: TextSpan(
          text: String.fromCharCode(icon.codePoint),
          style: TextStyle(
            fontSize: 13,
            fontFamily: icon.fontFamily,
            package: icon.fontPackage,
            color: const Color(0xFFF2EEE2),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
    });
    glyph.paint(canvas, at - Offset(glyph.width / 2, glyph.height / 2));
  }

  /// A cut stone floating above its shadow, with a glow and a glint running
  /// over the facets.
  void _renderGem(Canvas canvas) {
    final center = (size / 2).toOffset();
    final color = type.color;
    final bob = sin(_time * 3) * 2.5;
    final pulse = 1 + 0.1 * sin(_time * 4);
    canvas.drawOval(
      Rect.fromCenter(center: center.translate(0, 12), width: 20, height: 7),
      Paint()..color = const Color(0x55000000),
    );
    canvas.drawCircle(
      center.translate(0, bob),
      21 * pulse,
      Paint()..color = color.withValues(alpha: 0.22),
    );
    final c = center.translate(0, bob - 2);
    const w = 11.0;
    const top = 6.0;
    const bottom = 12.0;
    final crown = Path()
      ..moveTo(c.dx - w, c.dy)
      ..lineTo(c.dx - w * 0.5, c.dy - top)
      ..lineTo(c.dx + w * 0.5, c.dy - top)
      ..lineTo(c.dx + w, c.dy)
      ..close();
    final pavilion = Path()
      ..moveTo(c.dx - w, c.dy)
      ..lineTo(c.dx + w, c.dy)
      ..lineTo(c.dx, c.dy + bottom)
      ..close();
    canvas.drawPath(
      pavilion,
      Paint()..color = Color.lerp(color, const Color(0xFF000000), 0.35)!,
    );
    canvas.drawPath(
      crown,
      Paint()..color = Color.lerp(color, const Color(0xFFFFFFFF), 0.25)!,
    );
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = const Color(0xCCFFFFFF);
    canvas.drawPath(crown, edge);
    canvas.drawPath(pavilion, edge);
    canvas.drawLine(c.translate(-w * 0.5, -top), c.translate(0, bottom), edge);
    canvas.drawLine(c.translate(w * 0.5, -top), c.translate(0, bottom), edge);
    _badge(canvas, center.translate(0, bob - 22), color);
    // A glint that sweeps across every two seconds.
    final glint = (_time % 2) / 2;
    if (glint < 0.35) {
      final x = c.dx - w + 2 * w * (glint / 0.35);
      canvas.drawCircle(
        Offset(x, c.dy - top * 0.5),
        2.2,
        Paint()..color = const Color(0xEEFFFFFF),
      );
    }
  }
}
