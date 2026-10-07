import 'dart:math';

import 'package:flutter/material.dart';

import '../game/round_stats.dart';
import '../game/space_game.dart';
import '../theme.dart';
import 'widgets/panel.dart';
import 'widgets/round_rewards.dart';

/// End of round: gold rays and confetti for the winner, a red pulse and a
/// shaking banner for everyone who lost.
class RoundOverOverlay extends StatefulWidget {
  const RoundOverOverlay({required this.game, super.key});

  final SpaceGame game;

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
            ? BwColors.amber
            : lost
            ? BwColors.danger
            : BwColors.sand;
        final title = won
            ? 'SIEG'
            : lost
            ? 'NIEDERLAGE'
            : 'ÜBUNG BEENDET';
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
                Center(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 700),
                    curve: Curves.elasticOut,
                    builder: (context, scale, child) =>
                        Transform.scale(scale: 0.3 + 0.7 * scale, child: child),
                    child: Panel(
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Transform.translate(
                            offset: lost
                                ? Offset(sin(t * 2 * pi * 40) * 3, 0)
                                : Offset.zero,
                            child: Text(
                              title,
                              style: TextStyle(
                                fontSize: 44,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 6,
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
                          const SizedBox(height: 8),
                          ValueListenableBuilder<String?>(
                            valueListenable: game.winnerName,
                            builder: (context, winner, _) => Text(
                              winner == null
                                  ? 'Unentschieden. Das Sperrgebiet gewinnt.'
                                  : won
                                  ? (game.round?.teamMode ?? false
                                        ? 'Euer Team behauptet das Feld!'
                                        : 'Letzter Panzer im Feld. Gut gemacht!')
                                  : '$winner gewinnt die Übung.',
                              style: Theme.of(context).textTheme.titleMedium,
                              textAlign: TextAlign.center,
                            ),
                          ),
                          if (game.round?.participants.contains(game.myId) ??
                              false) ...[
                            const SizedBox(height: 20),
                            _StatsRow(stats: game.roundStats),
                            RoundRewards(progress: game.progress),
                          ],
                          const SizedBox(height: 24),
                          _Actions(game: game),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

/// Straight into the next round, or back to the waiting room. Only the
/// player who may start rounds gets the rematch button, everybody else is
/// pulled along when it is pressed.
class _Actions extends StatelessWidget {
  const _Actions({required this.game});

  final SpaceGame game;

  @override
  Widget build(BuildContext context) {
    final rematch = game.canStart;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 12,
          runSpacing: 12,
          children: [
            if (rematch)
              FilledButton.icon(
                onPressed: game.rematch,
                icon: const Icon(Icons.replay),
                label: const Text('NOCHMAL'),
              ),
            if (rematch)
              OutlinedButton(
                onPressed: game.backToLobby,
                child: const Text('ZURÜCK INS LAGER'),
              )
            else
              FilledButton(
                onPressed: game.backToLobby,
                child: const Text('ZURÜCK INS LAGER'),
              ),
            OutlinedButton.icon(
              onPressed: game.watchReplay,
              icon: const Icon(Icons.movie_outlined),
              label: const Text('WIEDERHOLUNG'),
            ),
          ],
        ),
        if (!rematch) ...[
          const SizedBox(height: 10),
          const Text(
            'Startet der Gastgeber eine neue Runde, bist du automatisch dabei.',
            style: TextStyle(color: BwColors.textDim, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
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
      ('ABSCHÜSSE', '${stats.kills}'),
      ('SCHADEN', '${stats.damage.round()}'),
      ('TREFFERQUOTE', accuracy),
      ('ÜBERLEBT', _time(stats.survived)),
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
            decoration: BoxDecoration(
              color: const Color(0x66000000),
              border: Border.all(color: BwColors.oliveLight),
            ),
            child: Column(
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: BwColors.amber,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10,
                    letterSpacing: 1.5,
                    color: BwColors.textDim,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
