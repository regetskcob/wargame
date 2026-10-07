import 'package:flame/components.dart';

import 'components/ship_base.dart';
import 'components/soldier.dart';
import 'game_phase.dart';
import 'space_game.dart';

/// Aims and fires the guns of the soldiers this client commands: those of
/// the local player and its CPU tanks, the enemies of a defense round on the
/// client that runs them, and the sides of a team round on one chosen
/// client. Riflemen go for soldiers first, rocket launchers for tanks.
class InfantryCommand extends Component with HasGameRef<SpaceGame> {
  @override
  void update(double dt) {
    final phase = gameRef.phase.value;
    final field = gameRef.soldierField;
    if (field == null ||
        (phase != GamePhase.playing && phase != GamePhase.spectating)) {
      return;
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

  PositionComponent? _pick(Soldier soldier, List<Soldier> soldiers) {
    final owner = soldier.ownerId!;
    final range = soldier.range;
    ShipBase? tank;
    var tankDistance = range;
    for (final ship in gameRef.enemiesOf(owner)) {
      final distance = ship.position.distanceTo(soldier.position);
      if (distance < tankDistance && !gameRef.inSmoke(ship.position)) {
        tankDistance = distance;
        tank = ship;
      }
    }
    if (soldier.rocket && tank != null) {
      return tank;
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
    return foe ?? tank;
  }
}
