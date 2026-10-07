import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../audio_service.dart';
import '../env.dart';
import '../game_config.dart';
import '../tanks/tank_painter.dart';
import '../tanks/tank_stats.dart';
import '../theme.dart';

User? _signedInUser() {
  try {
    return Supabase.instance.client.auth.currentUser;
  } catch (_) {
    return null;
  }
}

/// Shows that the plumbing works: a Supabase session, the four vehicles that
/// are already drawn for you and a button to hear the sounds.
class StatusScreen extends StatefulWidget {
  const StatusScreen({super.key});

  @override
  State<StatusScreen> createState() => _StatusScreenState();
}

class _StatusScreenState extends State<StatusScreen> {
  int _color = 0;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SKELETON',
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 8),
              const Text(
                'Fill in lib/src/env.dart to connect, then build the game.',
                style: TextStyle(color: BwColors.textDim, fontSize: 16),
              ),
              const SizedBox(height: 24),
              const AuthStatus(),
              const SizedBox(height: 16),
              const EnvRow(label: 'SUPABASE_URL', value: Env.supabaseUrl),
              const EnvRow(label: 'ROOM', value: Env.room),
              const SizedBox(height: 24),
              Text('FAHRZEUGE', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final type in TankType.values)
                    _TankCard(type: type, color: GameConfig.tankColors[_color]),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  for (var i = 0; i < GameConfig.tankColors.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: InkWell(
                        onTap: () => setState(() => _color = i),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: ShapeDecoration(
                            color: GameConfig.tankColors[i],
                            shape: BeveledRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                              side: BorderSide(
                                color: i == _color
                                    ? BwColors.amber
                                    : Colors.black45,
                                width: 2.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final sound in const [
                    'cannon',
                    'autocannon',
                    'hit',
                    'explosion',
                  ])
                    OutlinedButton(
                      onPressed: () => AudioService.play(sound),
                      child: Text(sound.toUpperCase()),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TankCard extends StatelessWidget {
  const _TankCard({required this.type, required this.color});

  final TankType type;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final stats = TankStats.of(type);
    return Container(
      width: 164,
      padding: const EdgeInsets.all(10),
      decoration: ShapeDecoration(
        color: BwColors.panel,
        shape: BeveledRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: BwColors.oliveLight, width: 1.5),
        ),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 92,
            child: CustomPaint(
              size: const Size(96, 92),
              painter: _TankPainter(type, color),
            ),
          ),
          Text(
            type.label,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
          ),
          Text(
            '${stats.maxHp.round()} HP · ${stats.barrels}x ${stats.damage.round()}',
            style: const TextStyle(color: BwColors.textDim, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _TankPainter extends CustomPainter {
  const _TankPainter(this.type, this.color);

  final TankType type;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const tank = 62.0;
    canvas.translate((size.width - tank) / 2, size.height - tank - 4);
    paintTank(canvas, tank, type, color);
  }

  @override
  bool shouldRepaint(_TankPainter old) =>
      old.type != type || old.color != color;
}

class AuthStatus extends StatelessWidget {
  const AuthStatus({super.key});

  @override
  Widget build(BuildContext context) {
    final user = _signedInUser();
    final connected = user != null;
    const green = Color(0xFF9CCC65);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: ShapeDecoration(
        color: connected ? green.withValues(alpha: 0.08) : Colors.transparent,
        shape: BeveledRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: connected ? green : BwColors.oliveLight,
            width: 2,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            connected ? Icons.check_circle : Icons.link_off,
            color: connected ? green : BwColors.textDim,
            size: 32,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              connected
                  ? 'Signed in anonymously as ${user.id}'
                  : 'No Supabase session yet. Check lib/src/env.dart and that '
                        'anonymous sign-ins are enabled, then hot restart.',
              style: TextStyle(
                color: connected ? green : BwColors.text,
                fontSize: 16,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class EnvRow extends StatelessWidget {
  const EnvRow({required this.label, required this.value, super.key});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 160,
            child: Text(
              label,
              style: const TextStyle(color: BwColors.textDim, fontSize: 14),
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }
}
