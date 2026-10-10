import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

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

/// End of round: gold rays and confetti for the winner, a red pulse and a
/// shaking banner for everyone who lost.
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
            ? GameColors.amber
            : lost
            ? GameColors.danger
            : GameColors.sand;
        final title = won
            ? tr('SIEG', 'VICTORY')
            : lost
            ? tr('NIEDERLAGE', 'DEFEAT')
            : tr('GEFECHT BEENDET', 'BATTLE OVER');
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final t = _controller.value;
            return Stack(
              fit: StackFit.expand,
              children: [
                const ColoredBox(color: Color(0x88000000)),
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
                          padding: EdgeInsets.all(narrow ? 12 : 16),
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
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 700),
      curve: Curves.elasticOut,
      builder: (context, scale, child) =>
          Transform.scale(scale: 0.3 + 0.7 * scale, child: child),
      child: Panel(
        padding: EdgeInsets.all(narrow ? 18 : 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Transform.translate(
              offset: lost ? Offset(sin(t * 2 * pi * 40) * 3, 0) : Offset.zero,
              // One line always: a long word shrinks rather
              // than breaking in the middle.
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  title,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: narrow ? 34 : 44,
                    fontWeight: FontWeight.w900,
                    letterSpacing: narrow ? 3 : 6,
                    color: accent,
                    shadows: [
                      Shadow(
                        blurRadius: won ? 24 : 12,
                        color: accent.withValues(alpha: 0.8),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
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
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontSize: narrow ? 14 : null,
                  letterSpacing: narrow ? 1 : null,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            // A lost round still tells how long the pilot held out: the
            // experience and the rating grow with every tank outlasted.
            if (_placeOf(game, lost: lost) case (:final place, :final of)) ...[
              const SizedBox(height: 6),
              Text(
                tr('PLATZ $place VON $of', 'PLACE $place OF $of'),
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                  color: GameColors.textDim,
                ),
              ),
            ],
            if (game.round?.participants.contains(game.myId) ?? false) ...[
              const SizedBox(height: 20),
              _StatsRow(stats: game.roundStats),
              RoundRewards(progress: game.progress),
            ],
            const SizedBox(height: 24),
            ValueListenableBuilder<bool>(
              valueListenable: game.isHost,
              builder: (context, host, _) => Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilledButton.icon(
                    onPressed: host ? game.rematch : null,
                    icon: const Icon(Icons.replay),
                    label: Text(
                      host
                          ? tr('NEUES SPIEL', 'NEW GAME')
                          : tr('WARTE AUF GASTGEBER', 'WAITING FOR HOST'),
                    ),
                  ),
                  OutlinedButton(
                    onPressed: game.backToLobby,
                    child: _LobbyLabel(lobbyAt: game.lobbyAt.value),
                  ),
                  OutlinedButton.icon(
                    onPressed: game.watchReplay,
                    icon: const Icon(Icons.movie_outlined),
                    label: Text(tr('WIEDERHOLUNG', 'REPLAY')),
                  ),
                ],
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
  const _LobbyLabel({required this.lobbyAt});

  final int? lobbyAt;

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
    final label = tr('ZURÜCK INS LAGER', 'BACK TO CAMP');
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
    Color(0xFFFFD54F),
    Color(0xFFFFFFFF),
    Color(0xFF9CCC65),
    Color(0xFFFFB300),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    final reach = size.longestSide;

    // Slowly turning sunburst
    final rays = Paint()..color = const Color(0x22FFD54F);
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
    final pulse = 0.5 + 0.5 * sin(t * 2 * pi * 6);
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          radius: 0.95,
          colors: [
            const Color(0x00000000),
            Color.fromRGBO(209, 73, 46, 0.25 + 0.2 * pulse),
          ],
          stops: const [0.45, 1],
        ).createShader(rect),
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
  const _StatsRow({required this.stats});

  final RoundStats stats;

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
      (tr('ÜBERLEBT', 'SURVIVED'), _time(stats.survived)),
    ];
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final (label, value) in tiles)
          Container(
            width: 112,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: ShapeDecoration(
              color: const Color(0x66000000),
              shape: GameShapes.chip(),
            ),
            child: Column(
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: GameColors.amber,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    letterSpacing: 1.2,
                    color: GameColors.textDim,
                  ),
                ),
              ],
            ),
          ),
      ],
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
              'Der Sieg bleibt!',
          '$held waves held, the base fell in wave $wave. '
              'The victory remains!',
        )
      : tr(
          '$held Wellen abgewehrt. Der Stützpunkt steht!',
          '$held waves repelled. The base stands!',
        );
}
