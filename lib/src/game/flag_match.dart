import 'package:flame/components.dart';

import '../net/payloads/flag_payload.dart';
import 'game_config.dart';

/// One of the two flags of a capture the flag round.
class Flag {
  Flag(this.team) : position = FlagMatch.baseOf(team);

  /// The side it belongs to, 1 red or 2 blue.
  final int team;
  FlagSpot spot = FlagSpot.home;
  String? carrier;

  /// Where it stands or lies, and where its carrier was last seen.
  Vector2 position;

  /// Seconds it has been lying in the field.
  double lying = 0;

  bool get home => spot == FlagSpot.home;

  void _goHome() {
    spot = FlagSpot.home;
    carrier = null;
    lying = 0;
    position = FlagMatch.baseOf(team);
  }
}

/// What a tank on the field looks like to the rules: its side and where it
/// is.
typedef FlagTank = ({int team, Vector2 position});

/// The rules of capture the flag, without anything of Flame: who may pick up
/// which flag, when it goes home and when a side scores. Only the authority
/// of the round runs [step]; everybody else takes over its state with
/// [apply].
class FlagMatch {
  final flags = {1: Flag(1), 2: Flag(2)};
  final score = {1: 0, 2: 0};

  /// The base of [team]: red on the left, blue on the right.
  static Vector2 baseOf(int team) =>
      Vector2(team == 1 ? -GameConfig.flagBaseX : GameConfig.flagBaseX, 0);

  static int otherTeam(int team) => team == 1 ? 2 : 1;

  /// The team whose flag [id] carries, null if none.
  int? carriedBy(String id) {
    for (final flag in flags.values) {
      if (flag.spot == FlagSpot.carried && flag.carrier == id) {
        return flag.team;
      }
    }
    return null;
  }

  /// Moves the flags on by [dt] seconds with the tanks on the field. Returns
  /// what happened, in a fixed order, so the authority can announce it.
  List<FlagPayload> step(
    double dt,
    Map<String, FlagTank> tanks, {
    required String authority,
  }) {
    final events = <FlagPayload>[];
    void report(FlagAction action, Flag flag, String? by) =>
        events.add(snapshot(authority, action, flag.team, by: by));
    // Look at the tanks in the same order on every device.
    final ids = tanks.keys.toList()..sort();
    for (final flag in flags.values) {
      switch (flag.spot) {
        case FlagSpot.carried:
          final tank = tanks[flag.carrier];
          if (tank == null) {
            // The carrier was destroyed or is gone: the flag stays where
            // it was last seen.
            final by = flag.carrier;
            flag
              ..spot = FlagSpot.dropped
              ..carrier = null
              ..lying = 0;
            report(FlagAction.drop, flag, by);
            continue;
          }
          flag.position = tank.position.clone();
          final own = flags[tank.team]!;
          final atHome =
              tank.position.distanceTo(baseOf(tank.team)) <
              GameConfig.flagBaseRadius;
          // A side scores only while its own flag stands at home.
          if (atHome && own.home) {
            final by = flag.carrier;
            score[tank.team] = score[tank.team]! + 1;
            flag._goHome();
            report(FlagAction.capture, flag, by);
          }
        case FlagSpot.dropped:
          flag.lying += dt;
          if (flag.lying >= GameConfig.flagReturnSeconds) {
            flag._goHome();
            report(FlagAction.back, flag, null);
            continue;
          }
          for (final id in ids) {
            final tank = tanks[id]!;
            if (!_touches(tank, flag) || tank.team == 0) {
              continue;
            }
            if (tank.team == flag.team) {
              // A comrade brings it home at once, a carrier as well.
              flag._goHome();
              report(FlagAction.back, flag, id);
            } else if (carriedBy(id) == null) {
              flag
                ..spot = FlagSpot.carried
                ..carrier = id
                ..lying = 0;
              report(FlagAction.take, flag, id);
            }
            break;
          }
        case FlagSpot.home:
          for (final id in ids) {
            final tank = tanks[id]!;
            if (tank.team == flag.team ||
                tank.team == 0 ||
                !_touches(tank, flag) ||
                carriedBy(id) != null) {
              continue;
            }
            flag
              ..spot = FlagSpot.carried
              ..carrier = id;
            report(FlagAction.take, flag, id);
            break;
          }
      }
    }
    return events;
  }

  bool _touches(FlagTank tank, Flag flag) =>
      tank.position.distanceTo(flag.position) < GameConfig.flagReach;

  /// The side that won after [elapsed] seconds of the round, null while it
  /// goes on. After the regular time the side ahead wins; with a draw the
  /// next capture decides.
  int? winner(double elapsed) {
    for (final team in const [1, 2]) {
      if (score[team]! >= GameConfig.flagCaptures) {
        return team;
      }
    }
    if (elapsed < GameConfig.flagRoundSeconds || score[1] == score[2]) {
      return null;
    }
    return score[1]! > score[2]! ? 1 : 2;
  }

  /// The regular time is over with a draw: the next capture wins.
  bool overtime(double elapsed) =>
      elapsed >= GameConfig.flagRoundSeconds && score[1] == score[2];

  FlagPayload snapshot(
    String authority,
    FlagAction action,
    int team, {
    String? by,
  }) {
    FlagSnapshot of(Flag flag) => FlagSnapshot(
      spot: flag.spot,
      carrier: flag.carrier,
      x: flag.position.x,
      y: flag.position.y,
      lying: flag.lying,
    );
    return FlagPayload(
      id: authority,
      action: action,
      team: team,
      by: by,
      red: score[1]!,
      blue: score[2]!,
      flags: [of(flags[1]!), of(flags[2]!)],
    );
  }

  /// Takes over the state the authority sent. A flag at home stands at its
  /// base, wherever the message says.
  void apply(FlagPayload payload) {
    score[1] = payload.red;
    score[2] = payload.blue;
    for (final (i, state) in payload.flags.indexed) {
      final flag = flags[i + 1]!;
      flag
        ..spot = state.spot
        ..carrier = state.carrier
        ..lying = state.lying
        ..position = state.spot == FlagSpot.home
            ? baseOf(flag.team)
            : Vector2(state.x, state.y);
    }
  }

  /// Between two messages a flag in the field keeps counting towards going
  /// home, so its ring shrinks smoothly on every screen.
  void tick(double dt) {
    for (final flag in flags.values) {
      if (flag.spot == FlagSpot.dropped) {
        flag.lying += dt;
      }
    }
  }
}
