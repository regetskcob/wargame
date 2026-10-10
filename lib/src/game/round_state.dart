import 'dart:math';

import 'bot_level.dart';
import 'components/storm_zone.dart';
import 'game_config.dart';
import 'defense/defense_map.dart';
import '../l10n/l10n.dart';

class RoundState {
  RoundState({
    required this.seed,
    required this.startedAt,
    required this.participants,
    this.teams = const {},
    this.bots = const {},
    this.botHost,
    this.botLevel = BotLevel.normal,
    this.defense = false,
    this.lanes = const [],
    this.flag = false,
  }) : alive = participants.toSet(),
       flagHost = botHost;

  final int seed;
  final int startedAt;
  final List<String> participants;
  final Set<String> alive;

  /// Team per player, empty for a free for all.
  final Map<String, int> teams;

  /// Computer controlled tanks (id to look) and who runs them.
  final Map<String, int> bots;
  final String? botHost;
  final BotLevel botLevel;

  /// Everybody together against waves of enemies, see [isEnemy].
  final bool defense;

  /// A defense duel: who defends the base of each side. Empty otherwise.
  final List<String> lanes;

  bool get duel => lanes.length > 1;

  /// Capture the flag: red against blue, see [FlagMatch].
  final bool flag;

  /// Who runs the flags of a capture the flag round: the [botHost] at the
  /// start, the next player in line when they leave.
  String? flagHost;

  /// Players and CPU tanks that left a capture the flag round for good, so
  /// a side without anybody left loses.
  final left = <String>{};

  /// When a tank last went down, in milliseconds since the epoch. A state
  /// message still on its way must not bring it back before it respawns.
  final downAt = <String, int>{};

  /// Tanks come back after they were destroyed instead of being out.
  bool get respawns => defense || flag;

  /// Nobody of [team] is left in the round.
  bool teamGone(int team) =>
      participants.where((id) => teamOf(id) == team).every(left.contains);

  /// Radius of the field that is still safe: the closing zone of a battle,
  /// the whole field when capturing the flag.
  double safeRadiusAt(int nowMs) =>
      flag ? GameConfig.worldRadius : StormZone.radiusAt(startedAt, nowMs);

  /// The side [id] defends in a duel, the left one for anybody else.
  int laneOf(String id) => max(0, lanes.indexOf(id));

  /// Real people play against each other, so every tank gets its own colour.
  bool get distinctColors => bots.isEmpty;

  /// Enemies and comrades of a defense round that are already destroyed, so
  /// a late state message does not bring them back.
  final destroyedEnemies = <String>{};

  /// Enemies of a defense round are called `td-<wave>-<n>` and run by the
  /// [botHost].
  bool isEnemy(String id) => defense && id.startsWith('td-');

  /// CPU comrades of a defense round are called `ally-<slot>-<life>`, a new
  /// life after every respawn, and run by the [botHost] as well.
  bool isAlly(String id) => defense && id.startsWith('ally-');

  /// Aircraft the base sends to help the defenders are called `air-h-…`
  /// for a helicopter and `air-j-…` for a jet, flown by the [botHost].
  bool isFriendlyAir(String id) => defense && id.startsWith('air-');

  bool isBot(String id) =>
      bots.containsKey(id) || isEnemy(id) || isAlly(id) || isFriendlyAir(id);

  /// "CPU-3" for the bot called `cpu-3` and "KAMERAD 2" for the comrade in
  /// slot 1. Enemies of the defense are named after what they are:
  /// `td-h-…` a helicopter, `td-j-…` a jet, `td-d-…` a drone, `td-i-…` a
  /// squad on foot and every other one a tank.
  String botName(String id) {
    final parts = id.split('-');
    if (isFriendlyAir(id)) {
      return parts[1] == 'j'
          ? tr('EIGENER JET', 'OWN JET')
          : tr('EIGENER HUBSCHRAUBER', 'OWN HELICOPTER');
    }
    if (isAlly(id) && parts[1].startsWith('q')) {
      return tr('EIGENE INFANTERIE', 'OWN INFANTRY');
    }
    if (isAlly(id)) {
      return '${tr('KAMERAD', 'COMRADE')} ${(int.tryParse(parts[1]) ?? 0) + 1}';
    }
    if (!isEnemy(id)) {
      return 'CPU-${parts.last}';
    }
    return switch (parts[1]) {
      'h' => tr('HUBSCHRAUBER', 'HELICOPTER'),
      'j' => tr('KAMPFJET', 'FIGHTER JET'),
      'd' => tr('FEINDDROHNE', 'ENEMY DRONE'),
      'i' => tr('INFANTERIE', 'INFANTRY'),
      _ => tr('FEIND', 'ENEMY'),
    };
  }

  /// Look of an enemy, which follows from its wave and number.
  int enemyStyle(String id) {
    final parts = id.split('-');
    // A troop sent in a duel, `td-s<lane>-<wave>-<n>`, is a tank of the wave
    // it was sent in.
    final at = laneOfUnit(id) != null ? 2 : 1;
    final wave = int.tryParse(parts.length > at ? parts[at] : '') ?? 1;
    // The right road's units of a duel end in `b`: the same tank as the
    // left one's.
    final n = int.tryParse(parts.last.replaceAll('b', '')) ?? 0;
    return GameConfig.styleOf(DefenseMap.enemyType(wave, n).index, 1);
  }

  /// Vehicle of a comrade, which follows from its slot. The colour is the
  /// defenders' red like that of every tank on their side.
  int allyStyle(String id) {
    final slot = int.tryParse(id.split('-')[1]) ?? 0;
    return GameConfig.styleOf(DefenseMap.allyType(slot).index, 0);
  }

  /// In a defense round every player is on team 1 and every enemy on 2.
  int teamOf(String id) {
    if (duel) {
      return _duelTeamOf(id);
    }
    // The red and blue squads of a team round, `inf-1` and `inf-2`.
    if (!defense && id.startsWith('inf-')) {
      return int.tryParse(id.substring(4)) ?? 0;
    }
    if (defense) {
      return participants.contains(id) || isAlly(id) || isFriendlyAir(id)
          ? 1
          : 2;
    }
    return teams[id] ?? 0;
  }

  /// The two sides of a defense duel: the player of the left base with
  /// everything that is theirs is red (1), the other blue (2). Troops a
  /// player sends are `td-s<lane>-…`, the infantry of a base `ally-L<lane>-…`.
  /// The waves belong to the side they attack the other one for: those on
  /// the way to the right base end in `b` and are red.
  int _duelTeamOf(String id) {
    final lane = lanes.indexOf(id);
    if (lane >= 0) {
      return lane + 1;
    }
    final sent = laneOfUnit(id);
    if (sent != null) {
      return sent + 1;
    }
    if (isEnemy(id)) {
      return id.endsWith('b') ? 1 : 2;
    }
    return 0;
  }

  /// The side a sent troop or a base's infantry of a duel belongs to, null
  /// for everything else.
  int? laneOfUnit(String id) {
    final match = _unit.firstMatch(id);
    return match == null ? null : int.parse(match.group(1)!);
  }

  static final _unit = RegExp(r'^(?:td-s|ally-L)([01])-');

  /// True when at least two teams were actually formed.
  late final bool teamMode =
      !defense && participants.map(teamOf).toSet().length >= 2;

  int aliveIn(int team) => alive.where((id) => teamOf(id) == team).length;
  String? winnerId;

  /// Team that won a team round, null for a draw or a free for all.
  int? winnerTeam;

  /// Tanks in the order they went down.
  final fallen = <String>[];

  /// Takes [id] out of the round. Returns false if it was already out.
  bool markDead(String id) {
    if (!alive.remove(id)) {
      return false;
    }
    downAt[id] = DateTime.now().millisecondsSinceEpoch;
    fallen.add(id);
    return true;
  }

  /// CPU tanks [me] outlasted and those that outlasted [me], counted the
  /// same way as [placementsOf] counts people. They move the rating with a
  /// fixed rating for their level.
  ({int beaten, int beatenBy}) cpuPlacementsOf(String me) {
    var beaten = 0;
    var beatenBy = 0;
    final cpus = participants.where((id) => id != me && bots.containsKey(id));
    if (teamMode) {
      final mine = teamOf(me);
      final team = winnerTeam;
      if (team == null) {
        return (beaten: 0, beatenBy: 0);
      }
      for (final id in cpus) {
        if (teamOf(id) == mine) {
          continue;
        }
        team == mine ? beaten++ : beatenBy++;
      }
      return (beaten: beaten, beatenBy: beatenBy);
    }
    final myFall = fallen.indexOf(me);
    for (final id in cpus) {
      final theirFall = fallen.indexOf(id);
      final outlasted = myFall < 0 || (theirFall >= 0 && theirFall < myFall);
      outlasted ? beaten++ : beatenBy++;
    }
    return (beaten: beaten, beatenBy: beatenBy);
  }

  /// Human opponents [me] outlasted and those who outlasted [me], for the
  /// rating. In a team round the whole other team counts, won or lost
  /// together, and teammates do not count. CPU tanks never count.
  ({List<String> beaten, List<String> beatenBy}) placementsOf(String me) {
    final beaten = <String>[];
    final beatenBy = <String>[];
    final others = participants.where((id) => id != me && !isBot(id));
    if (teamMode) {
      final mine = teamOf(me);
      final team = winnerTeam;
      if (team == null) {
        return (beaten: beaten, beatenBy: beatenBy);
      }
      for (final id in others) {
        if (teamOf(id) == mine) {
          continue;
        }
        (team == mine ? beaten : beatenBy).add(id);
      }
      return (beaten: beaten, beatenBy: beatenBy);
    }
    final myFall = fallen.indexOf(me);
    for (final id in others) {
      final theirFall = fallen.indexOf(id);
      final outlasted = myFall < 0
          ? true
          : theirFall >= 0 && theirFall < myFall;
      (outlasted ? beaten : beatenBy).add(id);
    }
    return (beaten: beaten, beatenBy: beatenBy);
  }
}
