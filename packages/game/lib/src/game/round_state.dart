import 'bot_level.dart';
import '../game_config.dart';
import 'defense/defense_map.dart';

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
  }) : alive = participants.toSet();

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

  bool isBot(String id) => bots.containsKey(id) || isEnemy(id) || isAlly(id);

  /// "CPU-3" for the bot called `cpu-3` and "KAMERAD 2" for the comrade in
  /// slot 1. Enemies of the defense are named after what they are:
  /// `td-h-…` a helicopter, `td-j-…` a jet, `td-d-…` a drone, `td-i-…` a
  /// squad on foot and every other one a tank.
  String botName(String id) {
    final parts = id.split('-');
    if (isAlly(id)) {
      return 'KAMERAD ${(int.tryParse(parts[1]) ?? 0) + 1}';
    }
    if (!isEnemy(id)) {
      return 'CPU-${parts.last}';
    }
    return switch (parts[1]) {
      'h' => 'HUBSCHRAUBER',
      'j' => 'KAMPFJET',
      'd' => 'FEINDDROHNE',
      'i' => 'INFANTERIE',
      _ => 'FEIND',
    };
  }

  /// Look of an enemy, which follows from its wave and number.
  int enemyStyle(String id) {
    final parts = id.split('-');
    final wave = int.tryParse(parts.length > 1 ? parts[1] : '') ?? 1;
    final n = int.tryParse(parts.last) ?? 0;
    return GameConfig.styleOf(DefenseMap.enemyType(wave, n).index, 1);
  }

  /// Look of a comrade, which follows from its slot: in camouflage, so it
  /// stands apart from the loud colours of the players and from the enemy.
  int allyStyle(String id) {
    final slot = int.tryParse(id.split('-')[1]) ?? 0;
    return GameConfig.styleOf(DefenseMap.allyType(slot).index, 0);
  }

  /// In a defense round every player is on team 1 and every enemy on 2.
  int teamOf(String id) {
    // The red and blue squads of a team round, `inf-1` and `inf-2`.
    if (!defense && id.startsWith('inf-')) {
      return int.tryParse(id.substring(4)) ?? 0;
    }
    if (defense) {
      return participants.contains(id) || isAlly(id) ? 1 : 2;
    }
    return teams[id] ?? 0;
  }

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
    fallen.add(id);
    return true;
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
