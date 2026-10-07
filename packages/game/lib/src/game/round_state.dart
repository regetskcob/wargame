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

  /// Everybody together against waves of enemies, see [isEnemy].
  final bool defense;

  /// Enemies of a defense round that are already destroyed, so a late state
  /// message does not bring them back.
  final fallen = <String>{};

  /// Enemies of a defense round are called `td-<wave>-<n>` and run by the
  /// [botHost].
  bool isEnemy(String id) => defense && id.startsWith('td-');

  bool isBot(String id) => bots.containsKey(id) || isEnemy(id);

  /// "CPU-3" for the bot called `cpu-3`, "FEIND" for enemies of the defense.
  String botName(String id) =>
      isEnemy(id) ? 'FEIND' : 'CPU-${id.split('-').last}';

  /// Look of an enemy, which follows from its wave and number.
  int enemyStyle(String id) {
    final parts = id.split('-');
    final wave = int.tryParse(parts.length > 1 ? parts[1] : '') ?? 1;
    final n = int.tryParse(parts.last) ?? 0;
    return GameConfig.styleOf(DefenseMap.enemyType(wave, n).index, 1);
  }

  /// In a defense round every player is on team 1 and every enemy on 2.
  int teamOf(String id) {
    if (defense) {
      return participants.contains(id) ? 1 : 2;
    }
    return teams[id] ?? 0;
  }

  /// True when at least two teams were actually formed.
  late final bool teamMode =
      !defense && participants.map(teamOf).toSet().length >= 2;

  int aliveIn(int team) => alive.where((id) => teamOf(id) == team).length;
  String? winnerId;
}
