import 'dart:async';

import 'package:flutter/material.dart';

import '../../db/supabase_schema.g.dart';
import '../../game/components/tank_painter.dart';
import '../../game/space_game.dart';
import '../../theme.dart';
import 'choice_row.dart';

enum _View { total, week, vehicles }

/// Ranking of all pilots by rating, with the totals behind it, the same for
/// the current week, and the player's own numbers per vehicle. The own row
/// is highlighted.
class Leaderboard extends StatefulWidget {
  const Leaderboard({required this.game, this.rows = 10, super.key});

  final SpaceGame game;

  /// How many pilots are listed.
  final int rows;

  @override
  State<Leaderboard> createState() => _LeaderboardState();
}

class _LeaderboardState extends State<Leaderboard> {
  late Future<List<ScoresRow>> _scores;
  Timer? _refresh;
  var _view = _View.total;
  late Future<List<WeeklyScoresRow>> _week;
  late Future<List<TankScoresRow>> _vehicles;

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
    _week = widget.game.scoreService.weeklyScores();
    _vehicles = widget.game.scoreService.myTankScores();
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

  static String _time(int seconds) =>
      '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('BESTENLISTE', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        ChoiceRow<_View>(
          options: const [
            (_View.total, 'GESAMT', null),
            (_View.week, 'DIESE WOCHE', null),
            (_View.vehicles, 'MEINE FAHRZEUGE', null),
          ],
          selected: _view,
          onSelected: (v) => setState(() {
            _view = v ?? _view;
            _reload();
          }),
        ),
        const SizedBox(height: 10),
        switch (_view) {
          _View.total => _total(context),
          _View.week => _weekTable(),
          _View.vehicles => _vehicleTable(),
        },
      ],
    );
  }

  static const _empty = Text(
    'Noch keine Übungen gewertet.',
    style: TextStyle(color: BwColors.textDim),
  );

  Widget _table(List<String> labels, List<TableRow> rows) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 740),
        child: Table(
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          columnWidths: const {
            0: FixedColumnWidth(48),
            1: FlexColumnWidth(2.4),
          },
          children: [_headerOf(labels), ...rows],
        ),
      ),
    );
  }

  TableRow _plainRow(List<String> cells, {bool mine = false, int? rank}) {
    final base = TextStyle(
      fontWeight: mine ? FontWeight.w800 : FontWeight.w500,
      color: mine ? BwColors.amber : BwColors.text,
    );
    final medal = rank != null && rank <= 3 ? _medals[rank - 1] : null;
    return TableRow(
      decoration: BoxDecoration(
        color: mine ? const Color(0x33FFB300) : null,
        border: const Border(bottom: BorderSide(color: Color(0x22FFFFFF))),
      ),
      children: [
        for (var i = 0; i < cells.length; i++)
          _cell(
            cells[i],
            style: i == 0 && medal != null
                ? base.copyWith(color: medal, fontWeight: FontWeight.w900)
                : base,
            align: i == 1 ? TextAlign.left : TextAlign.right,
          ),
      ],
    );
  }

  Widget _weekTable() {
    final me = widget.game.scoreService.myId;
    return FutureBuilder<List<WeeklyScoresRow>>(
      future: _week,
      builder: (context, snapshot) {
        final rows = snapshot.data ?? const <WeeklyScoresRow>[];
        if (rows.isEmpty) {
          return snapshot.connectionState == ConnectionState.done
              ? const Text(
                  'Diese Woche wurde noch nicht geübt.',
                  style: TextStyle(color: BwColors.textDim),
                )
              : const SizedBox(height: 24);
        }
        return _table(
          const [
            'RANG',
            'PILOT',
            'EP',
            'SIEGE',
            'RUNDEN',
            'ABSCHÜSSE',
            '± WERTUNG',
          ],
          [
            for (var i = 0; i < rows.length; i++)
              _plainRow(
                [
                  '${i + 1}',
                  rows[i].name ?? '',
                  '${rows[i].xp ?? 0}',
                  '${rows[i].wins ?? 0}',
                  '${rows[i].rounds ?? 0}',
                  '${rows[i].kills ?? 0}',
                  _signed(rows[i].ratingChange ?? 0),
                ],
                mine: rows[i].id == me,
                rank: i + 1,
              ),
          ],
        );
      },
    );
  }

  static String _signed(int value) => value > 0 ? '+$value' : '$value';

  Widget _vehicleTable() {
    return FutureBuilder<List<TankScoresRow>>(
      future: _vehicles,
      builder: (context, snapshot) {
        final byType = {
          for (final row in snapshot.data ?? const <TankScoresRow>[])
            if (row.tankType != null) row.tankType!: row,
        };
        if (byType.isEmpty) {
          return snapshot.connectionState == ConnectionState.done
              ? _empty
              : const SizedBox(height: 24);
        }
        return _table(
          const [
            '',
            'FAHRZEUG',
            'RUNDEN',
            'SIEGE',
            'ABSCHÜSSE',
            'SCHADEN',
            'TREFFER',
          ],
          [
            for (final type in TankType.values)
              if (byType[type.index] case final row?)
                _plainRow([
                  '',
                  type.label,
                  '${row.rounds ?? 0}',
                  '${row.wins ?? 0}',
                  '${row.kills ?? 0}',
                  '${row.damage ?? 0}',
                  (row.shots ?? 0) == 0
                      ? '-'
                      : '${((row.hits ?? 0) * 100 / row.shots!).round()} %',
                ]),
          ],
        );
      },
    );
  }

  Widget _total(BuildContext context) {
    return FutureBuilder<List<ScoresRow>>(
      future: _scores,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Row(
            children: [
              const Text(
                'Bestenliste gerade nicht erreichbar.',
                style: TextStyle(color: BwColors.textDim),
              ),
              TextButton(
                onPressed: () => setState(_reload),
                child: const Text('NEU LADEN'),
              ),
            ],
          );
        }
        if (snapshot.connectionState != ConnectionState.done) {
          return const Text(
            'Bestenliste wird geladen …',
            style: TextStyle(color: BwColors.textDim),
          );
        }
        final scores = (snapshot.data ?? const <ScoresRow>[]).toList()
          ..sort(_byRank);
        final shown = scores.take(widget.rows).toList();
        final me = widget.game.scoreService.myId;
        if (shown.isEmpty) {
          return _empty;
        }
        return _table(_labels, [
          for (var i = 0; i < shown.length; i++)
            _row(i + 1, shown[i], mine: shown[i].id == me),
        ]);
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

  static const _labels = [
    'RANG',
    'PILOT',
    'WERTUNG',
    'SIEGE',
    'RUNDEN',
    'ABSCHÜSSE',
    'SCHADEN',
    'TREFFER',
    'Ø ÜBERLEBT',
  ];

  TableRow _headerOf(List<String> labels) {
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
        _cell(row.ratedRounds > 0 ? '${row.rating}' : '–', style: base),
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
