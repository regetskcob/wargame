import 'dart:async';

import 'package:flutter/material.dart';
import 'package:horizont/horizont.dart';

import '../../app/env.dart';
import '../../db/score_points.dart';
import '../../db/supabase_schema.g.dart';
import '../../game/tank_game.dart';
import '../theme.dart';
import '../../l10n/l10n.dart';
import '../../tv/tv_input.dart';

/// Ranking of all pilots by points over all their totals, with the totals
/// behind it. The own row
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

  /// The last list that arrived, shown while the next one loads: the line
  /// "loading" in its place shrank the table every 30 seconds and the
  /// start page jumped.
  List<ScoresRow>? _last;

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

  /// Made-up pilots for the store pictures, which would otherwise show
  /// whatever call signs real players chose that day.
  static const _shotRows = [
    ScoresRow({
      'id': 's1',
      'name': 'Nordwind',
      'wins': 41,
      'kills': 352,
      'rounds': 180,
      'updated_at': '2026-10-01T00:00:00Z',
    }),
    ScoresRow({
      'id': 's2',
      'name': 'Feldlerche',
      'wins': 33,
      'kills': 297,
      'rounds': 166,
      'updated_at': '2026-10-01T00:00:00Z',
    }),
    ScoresRow({
      'id': 's3',
      'name': 'Kiesel',
      'wins': 25,
      'kills': 210,
      'rounds': 131,
      'updated_at': '2026-10-01T00:00:00Z',
    }),
    ScoresRow({
      'id': 's4',
      'name': 'Graupel',
      'wins': 12,
      'kills': 96,
      'rounds': 74,
      'updated_at': '2026-10-01T00:00:00Z',
    }),
    ScoresRow({
      'id': 's5',
      'name': 'Moosbeere',
      'wins': 6,
      'kills': 41,
      'rounds': 38,
      'updated_at': '2026-10-01T00:00:00Z',
    }),
  ];

  void _reload() {
    if (Env.shots) {
      _scores = Future.value(_last = _shotRows);
      return;
    }
    _scores = widget.game.scoreService.topScores(limit: 100).then((rows) {
      _last = rows;
      return rows;
    });
  }

  /// Pilots with something to show: a row of three zeros is a round left
  /// early, not a place on the board.
  static bool _scored(ScoresRow row) =>
      row.points > 0 || row.wins > 0 || row.kills > 0;

  /// Points first, then rating, wins and kills break ties.
  static int _byRank(ScoresRow a, ScoresRow b) {
    for (final (x, y) in [
      (a.points, b.points),
      (a.rating, b.rating),
      (a.wins, b.wins),
      (a.kills, b.kills),
    ]) {
      if (x != y) {
        return y.compareTo(x);
      }
    }
    return 0;
  }

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
        Kennung(tr('Bestenliste', 'Leaderboard')),
        const SizedBox(height: HzSpace.s8),
        _total(context),
      ],
    );
  }

  static Widget get _empty => Text(
    tr('Noch keine Gefechte gewertet.', 'No battles ranked yet.'),
    style: GameType.callout.copyWith(color: GameColors.textMuted),
  );

  Widget _table(List<String> labels, List<TableRow> rows) {
    final table = Table(
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      // Rank and numbers take what they need and the name gets the rest, so
      // the whole table fits on a phone without scrolling sideways.
      columnWidths: const {1: FlexColumnWidth()},
      defaultColumnWidth: const IntrinsicColumnWidth(),
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
    return LayoutBuilder(
      builder: (context, box) => box.maxWidth >= _tableWidth
          ? table
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(width: _tableWidth, child: table),
            ),
    );
  }

  /// Below this width the names get too tight to read; only then the table
  /// scrolls sideways.
  static const _tableWidth = 320.0;

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
                style: GameType.callout.copyWith(color: GameColors.textMuted),
              ),
              TextButton(
                onPressed: () => setState(_reload),
                child: Text(tr('NEU LADEN', 'RELOAD')),
              ),
            ],
          );
        }
        final rows = snapshot.connectionState == ConnectionState.done
            ? snapshot.data
            : _last;
        if (rows == null) {
          // The table's rows, empty, while the first list loads: the one
          // line "loading" grew into the table and the start page, which
          // sits in the middle of a tablet, jumped under the finger.
          return Semantics(
            label: tr('Bestenliste wird geladen …', 'Loading leaderboard …'),
            child: ExcludeSemantics(
              child: _table(_labels, [
                for (var i = 0; i < widget.rows; i++) _placeholderRow(i + 1),
              ]),
            ),
          );
        }
        final scores = rows.where(_scored).toList()..sort(_byRank);
        // A guest plays unranked: a row under the guest's id is a leftover
        // of an earlier name and never the guest's own place.
        final service = widget.game.scoreService;
        final me = service.isGuest ? null : service.myId;
        if (scores.isEmpty) {
          return _empty;
        }
        final shown = [
          for (final (rank, row) in _shown(scores, (r) => r.id == me))
            _row(rank, row, mine: row.id == me),
        ];
        // Fewer pilots than places: empty rows keep the table as tall as
        // its placeholders were, or the start page, centred in the browser,
        // moves under the pointer the moment the list arrives.
        return _table(_labels, [
          ...shown,
          for (var i = shown.length; i < widget.rows; i++) _blankRow(),
        ]);
      },
    );
  }

  /// Column heads are Kennungen, the numbers below them mono.
  static final _head = GameType.kennung;

  Widget _cell(
    String text, {
    TextStyle? style,
    TextAlign align = TextAlign.right,
    int lines = 1,
  }) => Padding(
    padding: const EdgeInsets.symmetric(
      horizontal: HzSpace.s4,
      vertical: HzSpace.s4,
    ),
    child: Text(
      text,
      style: style ?? GameType.data,
      textAlign: align,
      maxLines: lines,
      overflow: TextOverflow.ellipsis,
    ),
  );

  // The rank column has no heading, its numbers speak for themselves.
  static List<String> get _labels => [
    '',
    'PILOT',
    tr('PUNKTE', 'POINTS'),
    tr('GEWONNEN', 'WINS'),
    tr('ABSCHÜSSE', 'KILLS'),
  ];

  TableRow _headerOf(List<String> labels) {
    return TableRow(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: GameColors.lineStrong)),
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

  TableRow _placeholderRow(int rank) {
    final dim = GameType.data.copyWith(color: GameColors.textMuted);
    return TableRow(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: GameColors.line)),
      ),
      children: [
        _cell('$rank', style: dim),
        _cell('…', style: dim, align: TextAlign.left),
        for (var i = 0; i < 3; i++) _cell('–', style: dim),
      ],
    );
  }

  TableRow _blankRow() =>
      TableRow(children: [for (var i = 0; i < 5; i++) _cell(' ')]);

  TableRow _row(int rank, ScoresRow row, {required bool mine}) {
    // The player's own row is the selection: accent tint, its rank in the
    // accent. The first three stand out by weight, not by medal colours.
    final base = GameType.data.copyWith(
      fontWeight: mine ? FontWeight.w600 : FontWeight.w400,
    );
    return TableRow(
      decoration: BoxDecoration(
        color: mine ? GameColors.accentTint : null,
        border: Border(bottom: BorderSide(color: GameColors.line)),
      ),
      children: [
        _cell(
          '$rank',
          style: base.copyWith(
            color: mine ? GameColors.accentText : null,
            fontWeight: rank <= 3 || mine ? FontWeight.w600 : null,
          ),
        ),
        // A long name breaks onto a second line on a phone instead of
        // losing its end. Names are words, in Sans.
        _cell(
          row.name,
          style: GameType.callout.copyWith(
            fontWeight: mine ? FontWeight.w600 : FontWeight.w400,
          ),
          align: TextAlign.left,
          lines: 2,
        ),
        _cell(
          '${row.points}',
          style: base.copyWith(fontWeight: FontWeight.w600),
        ),
        _cell('${row.wins}', style: base),
        _cell('${row.kills}', style: base),
      ],
    );
  }
}
