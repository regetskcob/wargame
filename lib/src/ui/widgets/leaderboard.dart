import 'dart:async';

import 'package:flutter/material.dart';

import '../../db/supabase_schema.g.dart';
import '../../game/tank_game.dart';
import '../theme.dart';
import '../../l10n/l10n.dart';
import '../../tv/tv_input.dart';

/// Ranking of all pilots by rating, with the totals behind it. The own row
/// is highlighted, and added below the list when it is further down.
class Leaderboard extends StatefulWidget {
  const Leaderboard({required this.game, this.rows = 5, super.key});

  final TankGame game;

  /// How many pilots are listed.
  final int rows;

  @override
  State<Leaderboard> createState() => _LeaderboardState();
}

class _LeaderboardState extends State<Leaderboard> {
  late Future<List<ScoresRow>> _scores;
  Timer? _refresh;

  @override
  void initState() {
    super.initState();
    _reload();
    _refresh = Timer.periodic(
      const Duration(seconds: 30),
      (_) => setState(_reload),
    );
  }

  @override
  void dispose() {
    _refresh?.cancel();
    super.dispose();
  }

  void _reload() {
    _scores = widget.game.scoreService.topScores(limit: 50);
  }

  /// Pilots with a rated round first, then rating, then wins, kills and
  /// damage break ties.
  static int _byRank(ScoresRow a, ScoresRow b) {
    final byRated = _rated(b).compareTo(_rated(a));
    if (byRated != 0) {
      return byRated;
    }
    final byRating = b.rating.compareTo(a.rating);
    if (byRating != 0) {
      return byRating;
    }
    final byWins = b.wins.compareTo(a.wins);
    if (byWins != 0) {
      return byWins;
    }
    final byKills = b.kills.compareTo(a.kills);
    return byKills != 0 ? byKills : b.damage.compareTo(a.damage);
  }

  /// Without a rated opponent yet the rating is only the starting value.
  static int _rated(ScoresRow row) => row.ratedRounds > 0 ? 1 : 0;

  /// The first [widget.rows] places, and the own place below them when it
  /// is further down.
  List<(int, T)> _shown<T>(List<T> rows, bool Function(T) mine) {
    final shown = [
      for (var i = 0; i < rows.length && i < widget.rows; i++) (i + 1, rows[i]),
    ];
    final own = rows.indexWhere(mine);
    if (own >= widget.rows) {
      shown.add((own + 1, rows[own]));
    }
    return shown;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          tr('BESTENLISTE', 'LEADERBOARD'),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 10),
        _total(context),
      ],
    );
  }

  static Widget get _empty => Text(
    tr('Noch keine Gefechte gewertet.', 'No battles ranked yet.'),
    style: const TextStyle(color: GameColors.textDim),
  );

  Widget _table(List<String> labels, List<TableRow> rows) {
    final table = Table(
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      columnWidths: const {0: FixedColumnWidth(48), 1: FlexColumnWidth(2.4)},
      children: [_headerOf(labels), ...rows],
    );
    // The Apple TV shows it in a column beside the menu and has no way to
    // scroll sideways: there the table shrinks to the column instead.
    if (onTv) {
      return LayoutBuilder(
        builder: (context, box) => box.maxWidth >= _tvTableWidth
            ? table
            : FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.topLeft,
                child: SizedBox(width: _tvTableWidth, child: table),
              ),
      );
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: _tableWidth),
        child: table,
      ),
    );
  }

  /// Below this width the columns get too tight to read.
  static const _tableWidth = 740.0;

  /// The television draws larger, its columns stay readable a bit tighter.
  static const _tvTableWidth = 520.0;

  Widget _total(BuildContext context) {
    return FutureBuilder<List<ScoresRow>>(
      future: _scores,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Row(
            children: [
              Text(
                tr(
                  'Bestenliste gerade nicht erreichbar.',
                  'Leaderboard currently unavailable.',
                ),
                style: const TextStyle(color: GameColors.textDim),
              ),
              TextButton(
                onPressed: () => setState(_reload),
                child: Text(tr('NEU LADEN', 'RELOAD')),
              ),
            ],
          );
        }
        if (snapshot.connectionState != ConnectionState.done) {
          return Text(
            tr('Bestenliste wird geladen …', 'Loading leaderboard …'),
            style: const TextStyle(color: GameColors.textDim),
          );
        }
        final scores = (snapshot.data ?? const <ScoresRow>[]).toList()
          ..sort(_byRank);
        final me = widget.game.scoreService.myId;
        if (scores.isEmpty) {
          return _empty;
        }
        return _table(_labels, [
          for (final (rank, row) in _shown(scores, (r) => r.id == me))
            _row(rank, row, mine: row.id == me),
        ]);
      },
    );
  }

  static const _head = TextStyle(
    fontSize: 11,
    letterSpacing: 1.4,
    color: GameColors.textDim,
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

  static List<String> get _labels => [
    tr('RANG', 'RANK'),
    'PILOT',
    tr('WERTUNG', 'RATING'),
    tr('SIEGE', 'WINS'),
    tr('ABSCHÜSSE', 'KILLS'),
  ];

  TableRow _headerOf(List<String> labels) {
    return TableRow(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: GameColors.oliveLight)),
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
      color: mine ? GameColors.amber : GameColors.text,
    );
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
        _cell(row.ratedRounds > 0 ? '${row.rating}' : '–', style: base),
        _cell('${row.wins}', style: base),
        _cell('${row.kills}', style: base),
      ],
    );
  }
}
