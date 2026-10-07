import 'dart:math';
import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/extensions.dart';

import '../../game_config.dart';
import '../../net/net_events.dart';
import '../../net/payloads/special_payload.dart';
import '../components/bullet.dart';
import '../game_phase.dart';
import '../space_game.dart';
import 'defense_map.dart';

enum AirKind {
  /// Flies in, hovers at a distance and fires rockets at tanks and the base.
  helicopter('HUBSCHRAUBER', GameConfig.helicopterHp),

  /// Races across the field once and drops a string of bombs on its target.
  jet('KAMPFJET', GameConfig.jetHp);

  const AirKind(this.label, this.maxHp);

  final String label;
  final double maxHp;
}

/// An enemy aircraft of a defense round. It flies over the river, the trees
/// and the houses. Shells meant for the ground barely touch it, flak and the
/// twin guns of the Gepard bring it down.
///
/// Only the player who runs the enemies flies it and tells the others where
/// it is. On every other client the same component follows those messages.
class Aircraft extends PositionComponent with HasGameRef<SpaceGame> {
  Aircraft({
    required this.unitId,
    required this.kind,
    required Vector2 position,
    required double angle,
    this.remote = false,
    Vector2? goal,
  }) : _target = position.clone(),
       _targetAngle = angle,
       goal = goal ?? Vector2.zero(),
       super(
         position: position,
         angle: angle,
         size: Vector2.all(kind == AirKind.jet ? 44 : 40),
         anchor: Anchor.center,
         priority: 26,
       );

  final String unitId;
  final AirKind kind;
  final bool remote;

  /// Where a jet drops its bombs.
  final Vector2 goal;

  late double hp = kind.maxHp;
  final velocity = Vector2.zero();

  final Vector2 _target;
  double _targetAngle;
  double _age = 0;
  double _sinceSync = 0;
  double _sinceSeen = 0;
  double _cooldown = 1.5;
  double _think = 0;
  double _strafe = 1;
  double _flash = 0;
  bool _bombed = false;
  bool _gone = false;
  PositionComponent? _prey;

  Vector2 get heading => Vector2(sin(angle), -cos(angle));

  @override
  void onLoad() {
    add(
      CircleHitbox(
        radius: kind == AirKind.jet ? 16 : 18,
        position: size / 2,
        anchor: Anchor.center,
        collisionType: CollisionType.passive,
      ),
    );
  }

  void applyState(AirPayload state) {
    _sinceSeen = 0;
    final from = _target.clone();
    _target.setValues(state.x, state.y);
    _targetAngle = state.angle;
    velocity.setFrom((_target - from) / GameConfig.airSyncInterval);
    if (state.hp < hp) {
      _flash = 0.12;
    }
    hp = state.hp;
  }

  /// How hard [bullet] hits, 0 when it flies right past.
  double damageFrom(Bullet bullet) {
    if (bullet.antiAir) {
      return bullet.damage * GameConfig.antiAirFactor;
    }
    return kind == AirKind.helicopter
        ? bullet.damage * GameConfig.groundGunVsHelicopter
        : 0;
  }

  /// The client that flies it took a hit. Returns whether the shell struck.
  bool takeHit(Bullet bullet) {
    if (remote || hp <= 0) {
      return false;
    }
    final damage = damageFrom(bullet);
    if (damage <= 0) {
      return false;
    }
    hp -= damage;
    _flash = 0.12;
    gameRef.aircraftHit(this, bullet, damage);
    return true;
  }

  @override
  void update(double dt) {
    _age += dt;
    _flash = max(0, _flash - dt);
    if (remote) {
      _follow(dt);
      return;
    }
    final phase = gameRef.phase.value;
    if (phase != GamePhase.playing && phase != GamePhase.spectating) {
      return;
    }
    if (kind == AirKind.helicopter) {
      _hover(dt);
    } else {
      _dive(dt);
    }
    if (_gone) {
      return;
    }
    _sinceSync += dt;
    if (_sinceSync >= GameConfig.airSyncInterval) {
      _sinceSync = 0;
      gameRef.net.send(NetEvent.air, state().toJson());
    }
  }

  AirPayload state({double? hp, String? killer}) => AirPayload(
    id: gameRef.myId,
    unit: unitId,
    kind: kind.index,
    x: position.x,
    y: position.y,
    angle: angle,
    hp: hp ?? this.hp,
    killer: killer,
  );

  void _follow(double dt) {
    _sinceSeen += dt;
    // The host left or the message that it went down got lost.
    if (_sinceSeen > 2) {
      removeFromParent();
      return;
    }
    position.add(velocity * dt);
    _target.add(velocity * dt);
    final factor = min(1.0, dt * GameConfig.remoteLerpFactorPerSecond);
    position.add((_target - position) * factor);
    angle += (_targetAngle - angle).toNormalizedAngle() * factor;
  }

  double _headingTo(Vector2 point) =>
      atan2(point.x - position.x, -(point.y - position.y));

  /// Closes in on whatever it attacks, then hangs back at a distance and
  /// slides from side to side while it fires.
  void _hover(double dt) {
    final map = gameRef.defenseMap;
    if (map == null) {
      return;
    }
    _think -= dt;
    if (_think <= 0) {
      _think = 0.4;
      _prey = gameRef.nearestDefender(position, 480);
      if (gameRef.random.nextDouble() < 0.1) {
        _strafe = -_strafe;
      }
    }
    final prey = _prey;
    final aimAt = prey != null && prey.isMounted ? prey.position : map.base;
    final wanted = _headingTo(aimAt);
    final diff = (wanted - angle).toNormalizedAngle();
    angle += diff.clamp(-2.2 * dt, 2.2 * dt);
    final distance = position.distanceTo(aimAt);
    final toward = (aimAt - position).normalized();
    final side = Vector2(-toward.y, toward.x) * _strafe;
    final move = distance > GameConfig.helicopterHover
        ? toward
        : distance < GameConfig.helicopterHover - 60
        ? -toward * 0.5 + side * 0.6
        : side * 0.6;
    velocity.setFrom(move * GameConfig.helicopterSpeed);
    position.add(velocity * dt);
    _keepInside();
    _cooldown -= dt;
    if (_cooldown <= 0 &&
        diff.abs() < 0.2 &&
        distance < GameConfig.helicopterRange) {
      _cooldown = GameConfig.helicopterCooldown;
      gameRef.fireAircraft(this, (aimAt - position).normalized());
    }
  }

  /// Straight in over [goal], the bombs go as it passes, then out the other
  /// side of the field.
  void _dive(double dt) {
    velocity.setFrom(heading * GameConfig.jetSpeed);
    position.add(velocity * dt);
    if (!_bombed && (goal - position).dot(heading) < 40) {
      _bombed = true;
      gameRef.dropBombs(this);
    }
    final outside = !DefenseMap.bounds
        .inflate(220)
        .contains(position.toOffset());
    if (_bombed && outside) {
      _gone = true;
      gameRef.aircraftLeft(this);
    }
  }

  void _keepInside() {
    final bounds = DefenseMap.bounds.deflate(20);
    position.setValues(
      position.x.clamp(bounds.left, bounds.right),
      position.y.clamp(bounds.top, bounds.bottom),
    );
  }

  @override
  void onRemove() {
    if (gameRef.aircraft[unitId] == this) {
      gameRef.aircraft.remove(unitId);
    }
    super.onRemove();
  }

  @override
  void render(Canvas canvas) {
    final c = Offset(size.x / 2, size.y / 2);
    canvas.save();
    canvas.translate(c.dx, c.dy);
    // The shadow falls far behind and below, it flies high.
    final shadow = kind == AirKind.jet
        ? const Offset(34, 46)
        : const Offset(16, 24);
    canvas.save();
    canvas.translate(shadow.dx, shadow.dy);
    canvas.rotate(angle);
    canvas.scale(kind == AirKind.helicopter ? 1.05 : 0.8);
    _shape(canvas, Paint()..color = const Color(0x3A000000), shadow: true);
    canvas.restore();
    canvas.rotate(angle);
    if (kind == AirKind.helicopter) {
      canvas.scale(1.3);
    }
    final body = Paint()
      ..color = Color.lerp(
        const Color(0xFF7D8A6A),
        const Color(0xFFFFFFFF),
        _flash > 0 ? 0.6 : 0,
      )!;
    _shape(canvas, body, shadow: false);
    canvas.restore();
    final ratio = (hp / kind.maxHp).clamp(0.0, 1.0);
    if (ratio < 1) {
      final bar = Rect.fromLTWH(c.dx - 18, size.y + 4, 36, 4);
      canvas.drawRect(bar, Paint()..color = const Color(0x88000000));
      canvas.drawRect(
        Rect.fromLTWH(bar.left, bar.top, bar.width * ratio, bar.height),
        Paint()..color = GameConfig.teamColors[2],
      );
    }
  }

  void _shape(Canvas canvas, Paint body, {required bool shadow}) {
    final mark = Paint()..color = GameConfig.teamColors[2];
    if (kind == AirKind.jet) {
      final wing = Path()
        ..moveTo(0, -24)
        ..lineTo(6, -6)
        ..lineTo(22, 10)
        ..lineTo(22, 14)
        ..lineTo(5, 10)
        ..lineTo(4, 18)
        ..lineTo(10, 22)
        ..lineTo(-10, 22)
        ..lineTo(-4, 18)
        ..lineTo(-5, 10)
        ..lineTo(-22, 14)
        ..lineTo(-22, 10)
        ..lineTo(-6, -6)
        ..close();
      canvas.drawPath(wing, body);
      if (shadow) {
        return;
      }
      canvas.drawCircle(
        const Offset(0, -10),
        2.6,
        Paint()..color = const Color(0xFF9FD3F0),
      );
      canvas.drawCircle(const Offset(15, 11), 2.2, mark);
      canvas.drawCircle(const Offset(-15, 11), 2.2, mark);
      // Afterburner.
      if ((_age * 20).floor().isEven) {
        canvas.drawCircle(
          const Offset(0, 25),
          3,
          Paint()..color = const Color(0xFFFFB74D),
        );
      }
      return;
    }
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(0, -2), width: 14, height: 26),
      body,
    );
    canvas.drawLine(
      const Offset(0, 8),
      const Offset(0, 26),
      Paint()
        ..strokeWidth = 4
        ..color = body.color,
    );
    canvas.drawLine(
      const Offset(-5, 25),
      const Offset(5, 25),
      Paint()
        ..strokeWidth = 2.5
        ..color = body.color,
    );
    if (shadow) {
      canvas.drawCircle(Offset.zero, 20, body);
      return;
    }
    // Stub wings with rocket pods.
    canvas.drawLine(
      const Offset(-12, 0),
      const Offset(12, 0),
      Paint()
        ..strokeWidth = 3
        ..color = const Color(0xFF3A4236),
    );
    canvas.drawCircle(const Offset(-12, 0), 2.4, mark);
    canvas.drawCircle(const Offset(12, 0), 2.4, mark);
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(0, -9), width: 8, height: 8),
      Paint()..color = const Color(0xFF9FD3F0),
    );
    // Rotor: a faint disc and two blades turning fast.
    canvas.drawCircle(
      Offset.zero,
      20,
      Paint()..color = const Color(0x22E6E2D3),
    );
    final spin = _age * 30;
    final blade = Paint()
      ..strokeWidth = 2
      ..color = const Color(0xCC1A1A1A);
    for (final a in [spin, spin + pi / 2]) {
      canvas.drawLine(
        Offset(cos(a), sin(a)) * 20,
        Offset(cos(a), sin(a)) * -20,
        blade,
      );
    }
  }
}
