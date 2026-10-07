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
}
