import 'dart:math';

import '../game_config.dart';
import 'tank_stats.dart';

/// Checks what other players broadcast against what their tank can actually
/// do. The netcode trusts every peer with its own tank, so a modified client
/// could shoot faster, drive faster or heal itself. This guard sits on the
/// receiving side and throws out or clamps the grossest of these before they
/// reach the game. It is no anti-cheat, only a plausibility check: every limit
/// leaves room for lag and jitter, so honest players never trip it.
class PlausibilityGuard {
  PlausibilityGuard({required this.statsOf, DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  /// Stats of the tank a player drives, looked up by player id.
  final TankStats Function(String id) statsOf;
  final DateTime Function() _clock;

  final _tanks = <String, _Track>{};

  /// How often each player broke a rule this round.
  final strikes = <String, int>{};

  /// How far a shell may start from where its tank was last seen, to cover
  /// the barrel length and a few packets of lag.
  static const shotReach = 160.0;

  /// A tank that drove this much faster than its top speed is lying.
  static const speedSlack = 1.6;

  /// Distance any tank may jump on top of its speed, for packet jitter.
  static const jumpSlack = 60.0;

  /// A tank whose last known health was above this cannot have died.
  static const deathCeiling = 75.0;

  /// How far from the middle a tank may be: the round open field, or the
  /// corner of the larger defense map.
  double worldReach = GameConfig.worldRadius;

  void reset() {
    _tanks.clear();
    strikes.clear();
  }

  void forget(String id) => _tanks.remove(id);

  void _strike(String id) => strikes[id] = (strikes[id] ?? 0) + 1;

  _Track _track(String id) => _tanks.putIfAbsent(id, _Track.new);

  /// Last health the guard accepted for [id], null before the first state.
  double? hpOf(String id) => _tanks[id]?.hp;

  /// The player picked up a repair crate: their health may rise once.
  void allowRepair(String id) {
    _track(id).healBudget += GameConfig.repairAmount;
  }

  /// The player picked up mines or a barrage and may use it once.
  /// With [consume] the use is checked and spent instead.
  bool allowSpecial(String id, {bool consume = false}) {
    final track = _track(id);
    if (!consume) {
      track.specials++;
      return true;
    }
    if (track.specials <= 0) {
      _strike(id);
      return false;
    }
    track.specials--;
    return true;
  }

  /// The player picked up rapid fire and may shoot faster for a while.
  void allowRapidFire(String id) {
    _track(id).rapidUntil = _clock().add(
      Duration(milliseconds: (GameConfig.rapidFireSeconds * 1000).round()),
    );
  }

  /// Returns where the tank may plausibly be, [x], [y] if they are fine, or a
  /// point on the way there if the tank moved too far for its speed. Health
  /// is clamped to what the tank can have.
  ({double x, double y, double hp}) checkState(
    String id, {
    required double x,
    required double y,
    required double hp,
  }) {
    final stats = statsOf(id);
    final track = _track(id);
    final now = _clock();
    var acceptedX = x;
    var acceptedY = y;
    var acceptedHp = hp.clamp(0.0, stats.maxHp);
    final last = track.at;
    if (last != null) {
      final seconds = now.difference(last).inMicroseconds / 1e6;
      final reach =
          GameConfig.shipMaxSpeed * stats.speed * speedSlack * seconds +
          jumpSlack;
      final dx = x - track.x;
      final dy = y - track.y;
      final distance = sqrt(dx * dx + dy * dy);
      if (distance > reach) {
        _strike(id);
        acceptedX = track.x + dx / distance * reach;
        acceptedY = track.y + dy / distance * reach;
      }
      final previous = track.hp;
      if (previous != null && acceptedHp > previous) {
        final gain = acceptedHp - previous;
        if (gain > track.healBudget) {
          _strike(id);
          acceptedHp = previous + track.healBudget;
          track.healBudget = 0;
        } else {
          track.healBudget -= gain;
        }
      }
    }
    if (acceptedX * acceptedX + acceptedY * acceptedY >
        pow(worldReach + jumpSlack, 2)) {
      _strike(id);
      final length = sqrt(acceptedX * acceptedX + acceptedY * acceptedY);
      acceptedX = acceptedX / length * worldReach;
      acceptedY = acceptedY / length * worldReach;
    }
    track
      ..x = acceptedX
      ..y = acceptedY
      ..hp = acceptedHp
      ..at = now;
    return (x: acceptedX, y: acceptedY, hp: acceptedHp);
  }

  /// Whether a shell from [id] starting at [x], [y] is believable: not too
  /// soon after the last ones and not far from the tank.
  bool allowShot(String id, {required double x, required double y}) {
    final stats = statsOf(id);
    final track = _track(id);
    final now = _clock();
    final rapid = track.rapidUntil?.isAfter(now) ?? false;
    final cooldown =
        stats.fireCooldown * (rapid ? GameConfig.rapidFireFactor : 1);
    // A bucket of shells that refills at the gun's rate, with a little extra
    // for packets that arrive in bunches.
    final capacity = stats.barrels * 3.0;
    final last = track.shotAt;
    if (last == null) {
      track.shells = capacity;
    } else {
      final seconds = now.difference(last).inMicroseconds / 1e6;
      track.shells = min(
        capacity,
        track.shells + seconds / cooldown * stats.barrels * 1.25,
      );
    }
    track.shotAt = now;
    if (track.shells < 1) {
      _strike(id);
      return false;
    }
    track.shells -= 1;
    if (track.at != null) {
      final dx = x - track.x;
      final dy = y - track.y;
      if (dx * dx + dy * dy > shotReach * shotReach) {
        _strike(id);
        return false;
      }
    }
    return true;
  }

  /// Whether [shooterId] can have taken the victim from its last known health
  /// down to [hp] in one hit. Returns the health to show.
  double checkHit(String victimId, String shooterId, {required double hp}) {
    final victim = statsOf(victimId);
    final track = _track(victimId);
    final shooter = statsOf(shooterId);
    final previous = track.hp ?? victim.maxHp;
    final maxDrop = shooter.damage * shooter.barrels + jumpSlack;
    var accepted = hp.clamp(0.0, victim.maxHp);
    if (accepted > previous) {
      // A hit never heals, the next state will tell the truth.
      accepted = previous;
    } else if (previous - accepted > maxDrop) {
      _strike(victimId);
      accepted = max(0, previous - maxDrop);
    }
    track.hp = accepted;
    return accepted;
  }

  /// Whether a death message for [id] is believable, given the health the
  /// tank last reported.
  bool allowDeath(String id) {
    final hp = _tanks[id]?.hp;
    if (hp == null || hp <= deathCeiling) {
      return true;
    }
    _strike(id);
    return false;
  }
}

class _Track {
  double x = 0;
  double y = 0;
  double? hp;
  DateTime? at;
  double healBudget = 0;
  DateTime? rapidUntil;
  DateTime? shotAt;
  double shells = 0;
  int specials = 0;
}
