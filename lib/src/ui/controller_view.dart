import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../app/routes.dart';
import '../game/game_phase.dart';
import '../game/special_weapon.dart';
import '../haptics.dart';
import '../net/pad_link.dart';
import '../net/payloads/pad_payload.dart';
import 'theme.dart';
import 'widgets/panel.dart';
import 'widgets/touch_controls.dart';
import '../l10n/l10n.dart';

/// The phone as the gamepad of the game on a computer or tablet: the twin
/// sticks of the touch controls over the whole screen, and along the top
/// how the tank is doing, its items and, in a defense round, the guns.
class ControllerView extends StatefulWidget {
  const ControllerView({
    required this.code,
    required this.name,
    this.onClose,
    super.key,
  });

  /// Pairing code of the screen.
  final String code;

  /// How the phone shows up on the screen.
  final String name;

  /// Where TRENNEN leads. Without it the view closes its route.
  final VoidCallback? onClose;

  /// Opens the controller over the game for the screen of [code].
  static Future<void> open(BuildContext context, String code, String name) =>
      context.push<void>(Routes.pad(code, name: name));

  @override
  State<ControllerView> createState() => _ControllerViewState();
}

class _ControllerViewState extends State<ControllerView> {
  late final _remote = PadRemote(widget.code);
  final _special = ValueNotifier<(SpecialWeapon, int)?>(null);
  var _everOnline = false;
  var _lastHp = 1.0;

  @override
  void initState() {
    super.initState();
    _remote.status.addListener(_onStatus);
    _remote.screenOnline.addListener(_onOnline);
    unawaited(_remote.start(widget.name));
  }

  void _onOnline() {
    if (_remote.screenOnline.value && !_everOnline) {
      setState(() => _everOnline = true);
      Haptics.feel(HapticFeedback.mediumImpact);
    }
  }

  void _onStatus() {
    final status = _remote.status.value;
    if (status == null) {
      return;
    }
    final weapon = status.special;
    final loadout = weapon == null ? null : (weapon, status.charges);
    if (_special.value != loadout) {
      _special.value = loadout;
    }
    // A hit on the screen is felt in the hands.
    if (status.phase == GamePhase.playing && status.hp < _lastHp - 0.01) {
      Haptics.feel(HapticFeedback.heavyImpact);
    }
    _lastHp = status.hp;
  }

  void _close() {
    final onClose = widget.onClose;
    if (onClose != null) {
      onClose();
    } else {
      Navigator.of(context).maybePop();
    }
  }

  @override
  void dispose() {
    _remote.status.removeListener(_onStatus);
    _remote.screenOnline.removeListener(_onOnline);
    unawaited(_remote.stop());
    _special.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GameColors.background,
      body: ValueListenableBuilder<PadStatus?>(
        valueListenable: _remote.status,
        builder: (context, status, _) => Stack(
          children: [
            // Built anew when the round allows the aim assist or not, so
            // its button comes and goes.
            TouchControls(
              key: ValueKey(status?.assist ?? true),
              input: _remote.input,
              special: _special,
              assist: status?.assist ?? true,
            ),
            SafeArea(
              minimum: const EdgeInsets.all(10),
              child: Align(
                alignment: Alignment.topCenter,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _header(status),
                    if (status != null && status.phase == GamePhase.playing)
                      _gear(status),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(PadStatus? status) {
    return ValueListenableBuilder<bool>(
      valueListenable: _remote.screenOnline,
      builder: (context, online, _) {
        final hint = !online
            ? _everOnline
                  ? tr(
                      'Der Bildschirm ist weg. Sobald er wieder da ist, '
                          'geht es weiter.',
                      'The screen is gone. It carries on as soon as it is '
                          'back.',
                    )
                  : tr(
                      'Verbinde mit ${spacedPadCode(widget.code)} …',
                      'Connecting to ${spacedPadCode(widget.code)} …',
                    )
            : switch (status?.phase) {
                null || GamePhase.lobby => tr(
                  'Gekoppelt. Starte die Runde am Bildschirm.',
                  'Paired. Start the round on the screen.',
                ),
                GamePhase.countdown => tr('Gleich geht es los.', 'Get ready.'),
                GamePhase.playing => null,
                GamePhase.spectating => tr(
                  'Du schaust zu, bis die Runde vorbei ist.',
                  'You are watching until the round is over.',
                ),
                GamePhase.roundOver => tr(
                  'Runde vorbei. Weiter geht es am Bildschirm.',
                  'Round over. Carry on at the screen.',
                ),
                GamePhase.closed => tr(
                  'Der Raum ist geschlossen.',
                  'The room is closed.',
                ),
              };
        return Panel(
          padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
          child: Row(
            children: [
              Icon(
                online ? Icons.sports_esports : Icons.sync,
                color: online ? GameColors.amber : GameColors.textDim,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      online && status != null && status.name.isNotEmpty
                          ? status.name
                          : tr('CONTROLLER', 'CONTROLLER'),
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                        color: GameColors.sand,
                      ),
                    ),
                    if (hint != null)
                      Text(
                        hint,
                        style: const TextStyle(
                          color: GameColors.textDim,
                          fontSize: 12,
                        ),
                      )
                    else if (status != null)
                      _vitals(status),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: _close,
                icon: const Icon(Icons.link_off, size: 18),
                label: Text(tr('TRENNEN', 'UNPAIR')),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Armour and magazine as two thin bars.
  Widget _vitals(PadStatus status) {
    final hpColor = status.hp > 0.3
        ? const Color(0xFF9CCC65)
        : GameColors.danger;
    final ammo = status.magazine <= 0
        ? 1.0
        : (status.ammo / status.magazine).clamp(0.0, 1.0);
    Widget bar(IconData icon, double value, Color color, String label) => Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Expanded(
          child: LinearProgressIndicator(
            value: value,
            minHeight: 6,
            backgroundColor: Colors.black38,
            color: color,
          ),
        ),
        SizedBox(
          width: 44,
          child: Text(
            label,
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
    return Padding(
      padding: const EdgeInsets.only(top: 4, right: 8),
      child: Row(
        children: [
          Expanded(
            child: bar(
              Icons.health_and_safety,
              status.hp,
              hpColor,
              '${(status.hp * 100).round()} %',
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: bar(
              Icons.circle,
              ammo,
              ammo <= 0 ? GameColors.danger : const Color(0xFF4FC3F7),
              '${status.ammo}',
            ),
          ),
        ],
      ),
    );
  }

  /// Items to set off and, in a defense round, the guns to build.
  Widget _gear(PadStatus status) {
    if (status.items.isEmpty && !status.defense) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final (i, (type, count)) in status.items.indexed)
            _Chip(
              icon: type.icon,
              color: type.color,
              label: count > 1 ? '${type.short} ×$count' : type.short,
              onTap: () => _remote.act(PadActionKind.item, i),
            ),
          if (status.defense) ...[
            _Chip(
              icon: Icons.add_location_alt,
              color: GameColors.amber,
              label:
                  '${tr('BAUEN', 'BUILD')} ${status.tower?.label ?? ''}'
                  ' · ${status.credits}',
              onTap: () => _remote.act(PadActionKind.build),
            ),
            _Chip(
              icon: Icons.swap_horiz,
              color: GameColors.sand,
              label: tr('GESCHÜTZ', 'TURRET'),
              onTap: () => _remote.act(PadActionKind.cycle),
            ),
          ],
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: GameColors.panel,
      shape: GameShapes.chip(edge: color, width: 1.8),
      child: InkWell(
        onTap: () {
          Haptics.feel(HapticFeedback.selectionClick);
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
