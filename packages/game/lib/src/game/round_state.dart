import 'bot_level.dart';

class RoundState {
  RoundState({
    required this.seed,
    required this.startedAt,
    required this.participants,
    this.teams = const {},
    this.bots = const {},
    this.botHost,
    this.botLevel = BotLevel.normal,
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

  bool isBot(String id) => bots.containsKey(id);

  /// "CPU-3" for the bot called `cpu-3`.
  String botName(String id) => 'CPU-${id.split('-').last}';
  int teamOf(String id) => teams[id] ?? 0;

  /// True when at least two teams were actually formed.
  late final bool teamMode = participants.map(teamOf).toSet().length >= 2;

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
