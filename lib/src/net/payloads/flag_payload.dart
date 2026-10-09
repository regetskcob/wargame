/// Where a flag of a capture the flag round is.
enum FlagSpot { home, carried, dropped }

/// What just happened to a flag. [sync] only repeats the state.
enum FlagAction { sync, take, drop, back, capture }

/// One flag as the authority sees it.
class FlagSnapshot {
  const FlagSnapshot({
    required this.spot,
    this.carrier,
    required this.x,
    required this.y,
    this.lying = 0,
  });

  final FlagSpot spot;

  /// Who has it while it is [FlagSpot.carried].
  final String? carrier;

  /// Where it stands or lies; for a carried flag where it was last seen.
  final double x;
  final double y;

  /// Seconds a dropped flag has been lying in the field.
  final double lying;

  Map<String, dynamic> toJson() => {
    's': spot.index,
    if (carrier != null) 'c': carrier,
    'x': x.roundToDouble(),
    'y': y.roundToDouble(),
    if (lying > 0) 'l': (lying * 10).round() / 10,
  };

  static FlagSnapshot? tryParse(Object? raw) {
    if (raw is! Map) {
      return null;
    }
    final spot = raw['s'];
    final x = raw['x'];
    final y = raw['y'];
    final carrier = raw['c'];
    final lying = raw['l'];
    if (spot is! int ||
        spot < 0 ||
        spot >= FlagSpot.values.length ||
        x is! num ||
        y is! num ||
        !x.isFinite ||
        !y.isFinite ||
        (carrier != null && carrier is! String) ||
        (lying != null && (lying is! num || !lying.isFinite))) {
      return null;
    }
    final kind = FlagSpot.values[spot];
    if (kind == FlagSpot.carried && carrier == null) {
      return null;
    }
    return FlagSnapshot(
      spot: kind,
      carrier: kind == FlagSpot.carried ? carrier as String : null,
      x: x.toDouble(),
      y: y.toDouble(),
      lying: (lying as num? ?? 0).toDouble().clamp(0, 600),
    );
  }
}

/// The whole state of both flags and the score, sent by the authority of a
/// capture the flag round whenever a flag changes hands, and now and then
/// to repeat it. Every message carries everything, so a lost one does no
/// harm.
class FlagPayload {
  const FlagPayload({
    required this.id,
    required this.action,
    required this.team,
    this.by,
    required this.red,
    required this.blue,
    required this.flags,
  });

  /// The sender, the authority of the round.
  final String id;
  final FlagAction action;

  /// Whose flag the [action] is about, 1 red or 2 blue.
  final int team;

  /// The tank that took, returned or brought home the flag.
  final String? by;
  final int red;
  final int blue;

  /// The red flag first, then the blue one.
  final List<FlagSnapshot> flags;

  Map<String, dynamic> toJson() => {
    'id': id,
    'a': action.name,
    't': team,
    if (by != null) 'by': by,
    'sc': [red, blue],
    'f': [for (final flag in flags) flag.toJson()],
  };

  /// Null for anything that is not a well formed flag message.
  static FlagPayload? tryParse(Map<String, dynamic> json) {
    final id = json['id'];
    final action = FlagAction.values.asNameMap()[json['a']];
    final team = json['t'];
    final by = json['by'];
    final score = json['sc'];
    final flags = json['f'];
    if (id is! String ||
        action == null ||
        (team != 1 && team != 2) ||
        (by != null && by is! String) ||
        score is! List ||
        score.length != 2 ||
        flags is! List ||
        flags.length != 2) {
      return null;
    }
    final red = score[0];
    final blue = score[1];
    if (red is! int || blue is! int || red < 0 || blue < 0) {
      return null;
    }
    final parsed = [for (final raw in flags) FlagSnapshot.tryParse(raw)];
    if (parsed.contains(null)) {
      return null;
    }
    return FlagPayload(
      id: id,
      action: action,
      team: team as int,
      by: by as String?,
      red: red,
      blue: blue,
      flags: parsed.cast<FlagSnapshot>(),
    );
  }
}
