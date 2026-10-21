import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:horizont/horizont.dart';

import '../game/round_stats.dart';
import '../game/game_config.dart';
import '../net/payloads/defense_payload.dart';
import '../game/flag_match.dart';
import '../game/tank_game.dart';
import 'theme.dart';
import 'widgets/fit_or_scroll.dart';
import 'widgets/panel.dart';
import 'widgets/round_rewards.dart';
import '../l10n/l10n.dart';

/// End of round: rays and confetti in the signal yellow for the winner, a
/// critical pulse and a shaking banner for everyone who lost. The panel
/// itself is plain Horizont: the headline in expanded capitals with the
/// sign of the outcome, the numbers as a list, one primary action.
/// Asked for less motion, the backdrop stands still.
class RoundOverOverlay extends StatefulWidget {
  const RoundOverOverlay({required this.game, super.key});

  final TankGame game;

  @override
  State<RoundOverOverlay> createState() => _RoundOverOverlayState();
}

class _RoundOverOverlayState extends State<RoundOverOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    return ValueListenableBuilder<RoundOutcome>(
      valueListenable: game.outcome,
      builder: (context, outcome, _) {
        final won = outcome == RoundOutcome.won;
        final lost = outcome == RoundOutcome.lost;
        final accent = won
            ? GameColors.positive
            : lost
            ? GameColors.critical
            : GameColors.text;
        final title = won
            ? tr('GEWONNEN', 'VICTORY')
            : lost
            ? tr('NIEDERLAGE', 'DEFEAT')
            : tr('GEFECHT BEENDET', 'BATTLE OVER');
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final t = MediaQuery.disableAnimationsOf(context)
                ? 0.0
                : _controller.value;
            return Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(color: GameColors.bg.withValues(alpha: 0.55)),
                if (won) CustomPaint(painter: _VictoryPainter(t)),
                if (lost) CustomPaint(painter: _DefeatPainter(t)),
                // The backdrop covers the whole screen, the panel stays clear
                // of the notch, the Dynamic Island and the home indicator.
                SafeArea(
                  child: LayoutBuilder(
                    builder: (context, box) {
                      final narrow = box.maxWidth < 480;
                      return Center(
                        child: FitOrScroll(
                          padding: EdgeInsets.all(
                            narrow ? HzSpace.s12 : HzSpace.s16,
                          ),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 560),
                            child: _panel(
                              context,
                              t: t,
                              narrow: narrow,
                              won: won,
                              lost: lost,
                              accent: accent,
                              title: title,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// The place of a lost last tank standing round with more than two tanks,
  /// where it says more than the defeat.
  ({int place, int of})? _placeOf(TankGame game, {required bool lost}) {
    final placing = lost ? game.round?.placeOf(game.myId) : null;
    return placing != null && placing.of > 2 ? placing : null;
  }

  Widget _panel(
    BuildContext context, {
    required double t,
    required bool narrow,
    required bool won,
    required bool lost,
    required Color accent,
    required String title,
  }) {
    final game = widget.game;
    // The panel settles in, without the overshoot of a spring.
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: resolveMotion(context, HzMotion.slow),
      curve: HzMotion.standard,
      builder: (context, scale, child) =>
          Transform.scale(scale: 0.9 + 0.1 * scale, child: child),
      child: Panel(
        padding: EdgeInsets.all(narrow ? HzSpace.s16 : HzSpace.s24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Transform.translate(
              offset: lost ? Offset(sin(t * 2 * pi * 40) * 3, 0) : Offset.zero,
              // One line always: a long word shrinks rather
              // than breaking in the middle.
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (won || lost) ...[
                      Icon(
                        won
                            ? HorizontStatus.positive.icon
                            : HorizontStatus.critical.icon,
                        size: HzIconSize.tab,
                        color: accent,
                      ),
                      const SizedBox(width: HzSpace.s12),
                    ],
                    Text(
                      title,
                      maxLines: 1,
                      style: GameType.headline.copyWith(color: accent),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: HzSpace.s8),
            ValueListenableBuilder<String?>(
              valueListenable: game.winnerName,
              builder: (context, winner, _) => Text(
                game.round?.defense ?? false
                    ? _defenseLine(game.defense.value, won)
                    : game.flagMatch != null
                    ? _flagLine(game.flagMatch!, won)
                    : winner == null
                    ? tr(
                        'Unentschieden. Das Sperrgebiet gewinnt.',
                        'Draw. The closed zone wins.',
                      )
                    : won
                    ? (game.round?.teamMode ?? false
                          ? tr(
                              'Euer Team behauptet das Feld!',
                              'Your team holds the field!',
                            )
                          : tr(
                              'Letzter Panzer im Feld. Gut gemacht!',
                              'Last tank in the field. Well done!',
                            ))
                    : tr(
                        '$winner gewinnt das Gefecht.',
                        '$winner wins the battle.',
                      ),
                style: narrow ? GameType.callout : GameType.body,
                textAlign: TextAlign.center,
              ),
            ),
            // A lost round still tells how long the pilot held out: the
            // experience and the rating grow with every tank outlasted.
            if (_placeOf(game, lost: lost) case (:final place, :final of)) ...[
              const SizedBox(height: HzSpace.s8),
              Text(
                tr('PLATZ $place VON $of', 'PLACE $place OF $of'),
                style: GameType.kennung,
              ),
            ],
            if (game.round?.participants.contains(game.myId) ?? false) ...[
              const SizedBox(height: HzSpace.s24),
              _StatsRow(
                stats: game.roundStats,
                respawns:
                    (game.round?.defense ?? false) ||
                    (game.round?.flag ?? false),
              ),
              RoundRewards(progress: game.progress),
            ],
            const SizedBox(height: 24),
            ValueListenableBuilder<bool>(
              valueListenable: game.isHost,
              // One under the other in one width: side by side they broke
              // into rows of their own lengths, three widths on one screen.
              builder: (context, host, _) => LayoutBuilder(
                builder: (context, box) => SizedBox(
                  width: min(box.maxWidth, 320),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: HzSpace.s12,
                    children: [
                      // The one primary action, in the accent; the others
                      // are outlined.
                      FilledButton.icon(
                        onPressed: host ? game.rematch : null,
                        icon: const Icon(HorizontSymbols.replay),
                        label: Text(
                          host
                              ? tr('NEUES SPIEL', 'NEW GAME')
                              : tr('WARTE AUF GASTGEBER', 'WAITING FOR HOST'),
                        ),
                      ),
                      OutlinedButton(
                        onPressed: game.backToLobby,
                        child: _LobbyLabel(
                          lobbyAt: game.lobbyAt.value,
                          withOthers: game.mode.value.withOthers,
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: game.watchReplay,
                        icon: const Icon(HorizontSymbols.movie),
                        label: Text(tr('WIEDERHOLUNG', 'REPLAY')),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The way back to the waiting room, with the seconds left when the end
/// screen goes there by itself, so it never vanishes unannounced.
class _LobbyLabel extends StatefulWidget {
  const _LobbyLabel({required this.lobbyAt, required this.withOthers});

  final int? lobbyAt;

  /// Named as the waiting room calls itself: the camp it once said led to
  /// a screen titled get ready or waiting room.
  final bool withOthers;

  @override
  State<_LobbyLabel> createState() => _LobbyLabelState();
}

class _LobbyLabelState extends State<_LobbyLabel> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.lobbyAt != null) {
      _timer = Timer.periodic(
        const Duration(milliseconds: 250),
        (_) => setState(() {}),
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.withOthers
        ? tr('ZUM WARTERAUM', 'TO THE WAITING ROOM')
        : tr('ZUR BEREITSTELLUNG', 'TO GET READY');
    final at = widget.lobbyAt;
    if (at == null) {
      return Text(label);
    }
    final seconds = ((at - DateTime.now().millisecondsSinceEpoch) / 1000)
        .ceil()
        .clamp(0, 99);
    return Text('$label ($seconds)');
  }
}

class _VictoryPainter extends CustomPainter {
  const _VictoryPainter(this.t);

  final double t;

  static const _confetti = [
    GameColors.accentText,
    GameColors.text,
    GameColors.positive,
    GameColors.accent,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    final reach = size.longestSide;

    // Slowly turning sunburst
    final rays = Paint()..color = GameColors.accent.withValues(alpha: 0.13);
    for (var i = 0; i < 16; i++) {
      final a = t * 2 * pi + i * pi / 8;
      final path = Path()
        ..moveTo(centre.dx, centre.dy)
        ..lineTo(centre.dx + cos(a) * reach, centre.dy + sin(a) * reach)
        ..lineTo(
          centre.dx + cos(a + pi / 16) * reach,
          centre.dy + sin(a + pi / 16) * reach,
        )
        ..close();
      canvas.drawPath(path, rays);
    }

    // Falling confetti
    final random = Random(3);
    for (var i = 0; i < 70; i++) {
      final speed = 0.5 + random.nextDouble();
      final x = random.nextDouble() * size.width;
      final y =
          ((t * 6 * speed + random.nextDouble()) % 1) * (size.height + 40);
      final sway = sin(t * 2 * pi * 6 * speed + i) * 14;
      canvas.save();
      canvas.translate(x + sway, y - 20);
      canvas.rotate(t * 2 * pi * 6 * speed + i);
      canvas.drawRect(
        const Rect.fromLTWH(-4, -2, 8, 4),
        Paint()..color = _confetti[i % _confetti.length],
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_VictoryPainter old) => old.t != t;
}

class _DefeatPainter extends CustomPainter {
  const _DefeatPainter(this.t);

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    // A flat tint rather than a vignette: Horizont draws no gradients.
    final pulse = 0.5 + 0.5 * sin(t * 2 * pi * 6);
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = GameColors.critical.withValues(alpha: 0.1 + 0.1 * pulse),
    );
  }

  @override
  bool shouldRepaint(_DefeatPainter old) => old.t != t;
}

/// The player's own numbers for the round that just ended.
/// How a capture the flag round ended, with the score.
String _flagLine(FlagMatch match, bool won) {
  final score =
      '${GameConfig.teamNames[1]} ${match.score[1]} : '
      '${match.score[2]} ${GameConfig.teamNames[2]}';
  return won
      ? tr('Fahnen erobert! $score', 'Flags captured! $score')
      : tr('Die anderen waren schneller. $score', 'They were faster. $score');
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.stats, this.respawns = false});

  final RoundStats stats;

  /// A defense or flag round brings the tank back, so the time is how long
  /// the round ran, not how long the tank lasted.
  final bool respawns;

  static String _time(double? seconds) {
    final total = (seconds ?? 0).round();
    return '${total ~/ 60}:${(total % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final accuracy = stats.shots == 0
        ? '-'
        : '${(stats.accuracy * 100).round()} %';
    final tiles = [
      (tr('ABSCHÜSSE', 'KILLS'), '${stats.kills}'),
      (tr('SCHADEN', 'DAMAGE'), '${stats.damage.round()}'),
      (tr('TREFFERQUOTE', 'ACCURACY'), accuracy),
      (
        respawns ? tr('DAUER', 'DURATION') : tr('ÜBERLEBT', 'SURVIVED'),
        _time(stats.survived),
      ),
    ];
    // A list with hairlines, the numbers in mono at the end of each row,
    // as wide as the buttons below it.
    const rule = Divider(
      height: HzLine.hairline,
      thickness: HzLine.hairline,
      color: GameColors.line,
    );
    return LayoutBuilder(
      builder: (context, box) => SizedBox(
        width: min(box.maxWidth, 320),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            rule,
            for (final (label, value) in tiles) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: HzSpace.s8),
                child: Row(
                  children: [
                    Expanded(child: Text(label, style: GameType.kennung)),
                    Text(
                      value,
                      style: GameType.data.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              rule,
            ],
          ],
        ),
      ),
    );
  }
}

/// How a defense round ended, with or without an extension.
String _defenseLine(DefensePayload? state, bool won) {
  final wave = state?.wave ?? 0;
  if (!won) {
    return tr(
      'Der Stützpunkt ist in Welle $wave gefallen.',
      'The base fell in wave $wave.',
    );
  }
  if (state == null || !state.extended) {
    return tr(
      'Alle ${GameConfig.defenseWaves} Wellen abgewehrt. Der Stützpunkt steht!',
      'All ${GameConfig.defenseWaves} waves repelled. The base stands!',
    );
  }
  // A wave that is still running when the base falls or the defenders pull
  // out does not count.
  final held = state.nextWaveAt > 0 ? wave : wave - 1;
  return state.hp <= 0
      ? tr(
          '$held Wellen gehalten, in Welle $wave fiel der Stützpunkt. '
              'Gewonnen bleibt gewonnen!',
          '$held waves held, the base fell in wave $wave. '
              'The victory remains!',
        )
      : tr(
          '$held Wellen abgewehrt. Der Stützpunkt steht!',
          '$held waves repelled. The base stands!',
        );
}
