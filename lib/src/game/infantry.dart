import 'package:flame/components.dart';

import 'components/tank_base.dart';
import 'components/soldier.dart';
import 'components/squad_route.dart';
import 'game_config.dart';
import 'game_phase.dart';
import 'tank_game.dart';

/// Aims and fires the guns of the soldiers this client commands: those of
/// the local player and its CPU tanks, the enemies of a defense round on the
/// client that runs them, and the sides of a team round on one chosen
/// client. Riflemen go for soldiers first, rocket launchers for tanks.
///
/// It also leads their squads off the road: they patrol on their own, and
/// once an enemy comes within sight they stalk it to within reach of their
/// guns. Only these orders travel, see [SquadRoute].
class InfantryCommand extends Component with HasGameRef<TankGame> {
  /// Seconds until each squad looks around again, by its key.
  final _think = <String, double>{};

  /// Round clock second each squad last saw an enemy.
  final _seen = <String, double>{};

  @override
  void update(double dt) {
    final phase = gameRef.phase.value;
    final field = gameRef.soldierField;
    if (field == null ||
        (phase != GamePhase.playing && phase != GamePhase.spectating)) {
      return;
    }
    if (!gameRef.replaying.value) {
      _lead(field, dt);
    }
    final soldiers = field.children.whereType<Soldier>().toList();
    for (final soldier in soldiers) {
      final owner = soldier.ownerId;
      if (owner == null || soldier.dead || soldier.airborne) {
        continue;
      }
      soldier.cooldown -= dt;
      if (soldier.cooldown > 0 || !gameRef.runsShooter(owner)) {
        continue;
      }
      final target = _pick(soldier, soldiers);
      if (target == null) {
        // Look again in a moment.
        soldier.cooldown = 0.3;
        continue;
      }
      gameRef.fireSoldier(soldier, target);
    }
  }

  void _lead(SoldierField field, double dt) {
    final now = field.clock;
    for (final route in field.routes.values) {
      final owner = route.ownerId;
      if (owner == null ||
          now < route.startAt ||
          !route.alive ||
          !gameRef.runsShooter(owner)) {
        continue;
      }
      final wait = (_think[route.key] ?? 0) - dt;
      if (wait > 0) {
        _think[route.key] = wait;
        continue;
      }
      _think[route.key] = GameConfig.squadThink;
      final here = route.at(now);
      final prey = _prey(owner, here);
      final last = route.orderedAt;
      final calm = last == null || now - last >= GameConfig.squadOrderGap;
      if (prey == null) {
        // Lost it: after a while back to walking a round where they are.
        if (route.stalking &&
            calm &&
            now - (_seen[route.key] ?? 0) > GameConfig.stalkGiveUp) {
          gameRef.orderSquad(route, null);
        }
        continue;
      }
      _seen[route.key] = now;
      // Up to where their guns reach, rocket launchers further out.
      final rockets = route.members.every((s) => s.dead || s.rocket);
      final reach =
          (rockets ? GameConfig.rocketRange : GameConfig.rifleRange) *
          GameConfig.stalkStandoff;
      final away = here - prey.position;
      final goal = away.length <= reach
          ? here
          : prey.position + away.normalized() * reach;
      final current = route.goal;
      if (calm &&
          route.walkable(goal) &&
          (current == null || current.distanceTo(goal) > 60)) {
        gameRef.orderSquad(route, goal);
      }
    }
  }

  /// The nearest enemy within sight of a squad of [owner] at [here]: a tank
  /// out of the smoke or an armed soldier of the other side.
  PositionComponent? _prey(String owner, Vector2 here) {
    PositionComponent? best;
    var bestDistance = GameConfig.squadSight;
    for (final tank in gameRef.enemiesOf(owner)) {
      final distance = tank.position.distanceTo(here);
      if (distance < bestDistance && !gameRef.inSmoke(tank.position)) {
        bestDistance = distance;
        best = tank;
      }
    }
    for (final other in gameRef.soldierField?.all ?? const <Soldier>[]) {
      if (!other.armed ||
          other.dead ||
          !other.isMounted ||
          other.airborne ||
          gameRef.allied(other.ownerId, owner)) {
        continue;
      }
      final distance = other.position.distanceTo(here);
      if (distance < bestDistance) {
        bestDistance = distance;
        best = other;
      }
    }
    return best;
  }

  PositionComponent? _pick(Soldier soldier, List<Soldier> soldiers) {
    final owner = soldier.ownerId!;
    final range = soldier.range;
    TankBase? nearest;
    var nearestDistance = range;
    for (final tank in gameRef.enemiesOf(owner)) {
      final distance = tank.position.distanceTo(soldier.position);
      if (distance < nearestDistance && !gameRef.inSmoke(tank.position)) {
        nearestDistance = distance;
        nearest = tank;
      }
    }
    if (soldier.rocket && nearest != null) {
      return nearest;
    }
    Soldier? foe;
    var foeDistance = range;
    for (final other in soldiers) {
      if (!other.armed ||
          other.dead ||
          other.airborne ||
          gameRef.allied(other.ownerId, owner)) {
        continue;
      }
      final distance = other.position.distanceTo(soldier.position);
      if (distance < foeDistance) {
        foeDistance = distance;
        foe = other;
      }
    }
    return foe ?? nearest;
  }
}
