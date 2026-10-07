import 'package:flutter/material.dart';

import '../../db/supabase_schema.g.dart';
import '../../game/space_game.dart';
import '../../theme.dart';

/// Ranking of all pilots by wins, with the totals behind it. The own row is
/// highlighted.
class Leaderboard extends StatefulWidget {
  const Leaderboard({required this.game, this.rows = 10, super.key});

  final SpaceGame game;

  /// How many pilots are listed.
  final int rows;

  @override
  State<Leaderboard> createState() => _LeaderboardState();
}

class _LeaderboardState extends State<Leaderboard> {
  late final Stream<List<ScoresRow>> _scores;

  @override
  void initState() {
    super.initState();
    _scores = widget.game.scoreService.topScores();
  }

  /// Wins first, kills and damage break ties.
  static int _byRank(ScoresRow a, ScoresRow b) {
    final byWins = b.wins.compareTo(a.wins);
    if (byWins != 0) {
      return byWins;
    }
    final byKills = b.kills.compareTo(a.kills);
    return byKills != 0 ? byKills : b.damage.compareTo(a.damage);
  }

  static String _time(int seconds) =>
      '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ScoresRow>>(
      stream: _scores,
      builder: (context, snapshot) {
        final scores = (snapshot.data ?? const <ScoresRow>[]).toList()
          ..sort(_byRank);
        final shown = scores.take(widget.rows).toList();
        final me = widget.game.scoreService.myId;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('BESTENLISTE', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (shown.isEmpty)
              const Text(
                'Noch keine Übungen gewertet.',
                style: TextStyle(color: BwColors.textDim),
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 640),
                  child: Table(
                    defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                    columnWidths: const {
                      0: FixedColumnWidth(48),
                      1: FlexColumnWidth(2.4),
                    },
                    children: [
                      _header(),
                      for (var i = 0; i < shown.length; i++)
                        _row(i + 1, shown[i], mine: shown[i].id == me),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  static const _head = TextStyle(
    fontSize: 10,
    letterSpacing: 1.4,
    color: BwColors.textDim,
    fontWeight: FontWeight.w800,
  );

  Widget _cell(
    String text, {
    TextStyle style = const TextStyle(),
    TextAlign align = TextAlign.right,
  }) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
    child: Text(
      text,
      style: style,
      textAlign: align,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    ),
  );

  TableRow _header() {
    const labels = [
      'RANG',
      'PILOT',
      'SIEGE',
      'RUNDEN',
      'ABSCHÜSSE',
      'SCHADEN',
      'TREFFER',
      'Ø ÜBERLEBT',
    ];
    return TableRow(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: BwColors.oliveLight)),
      ),
      children: [
        for (var i = 0; i < labels.length; i++)
          _cell(
            labels[i],
            style: _head,
            align: i == 1 ? TextAlign.left : TextAlign.right,
          ),
      ],
    );
  }

  static const _medals = [
    Color(0xFFFFC107),
    Color(0xFFCFD8DC),
    Color(0xFFCD7F32),
  ];

  TableRow _row(int rank, ScoresRow row, {required bool mine}) {
    final medal = rank <= 3 ? _medals[rank - 1] : null;
    final base = TextStyle(
      fontWeight: mine ? FontWeight.w800 : FontWeight.w500,
      color: mine ? BwColors.amber : BwColors.text,
    );
    final accuracy = row.shots == 0
        ? '-'
        : '${(row.hits * 100 / row.shots).round()} %';
    final survived = row.rounds == 0
        ? '-'
        : _time((row.survivalSeconds / row.rounds).round());
    return TableRow(
      decoration: BoxDecoration(
        color: mine ? const Color(0x33FFB300) : null,
        border: const Border(bottom: BorderSide(color: Color(0x22FFFFFF))),
      ),
      children: [
        _cell(
          '$rank',
          style: base.copyWith(
            color: medal ?? base.color,
            fontWeight: FontWeight.w900,
          ),
        ),
        _cell(row.name, style: base, align: TextAlign.left),
        _cell('${row.wins}', style: base),
        _cell('${row.rounds}', style: base),
        _cell('${row.kills}', style: base),
        _cell('${row.damage}', style: base),
        _cell(accuracy, style: base),
        _cell(survived, style: base),
      ],
    );
  }
}
