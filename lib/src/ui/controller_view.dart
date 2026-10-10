import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../app/env.dart';
import '../app/routes.dart';
import '../game/game_config.dart';
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
    this.remote,
    super.key,
  });

  /// Pairing code of the screen.
  final String code;

  /// How the phone shows up on the screen.
  final String name;

  /// Where TRENNEN leads. Without it the view closes its route.
  final VoidCallback? onClose;

  /// Stands in for the link to the screen in a test, which starts and stops
  /// it itself.
  @visibleForTesting
  final PadRemote? remote;

  /// Opens the controller over the game for the screen of [code].
  static Future<void> open(BuildContext context, String code, String name) =>
      context.push<void>(Routes.pad(code, name: name));

  @override
  State<ControllerView> createState() => _ControllerViewState();
}

class _ControllerViewState extends State<ControllerView> {
  late final _remote = widget.remote ?? PadRemote(widget.code);
  final _special = ValueNotifier<(SpecialWeapon, int)?>(null);
  var _everOnline = false;
  var _lastHp = 1.0;

  /// The list of the defense shop that is folded out, null for none.
  _Shop? _shop;

  @override
  void initState() {
    super.initState();
    _remote.status.addListener(_onStatus);
    _remote.screenOnline.addListener(_onOnline);
    if (widget.remote == null) {
      unawaited(_remote.start(widget.name));
    }
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
    if (widget.remote == null) {
      unawaited(_remote.stop());
    }
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
      builder: (context, paired, _) {
        // The store picture shows the controller as if paired.
        final online = paired || Env.shotScene == 'pad';
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
                online ? Icons.sports_esports_outlined : Icons.sync_outlined,
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
                icon: const Icon(Icons.link_off_outlined, size: 18),
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
              Icons.health_and_safety_outlined,
              status.hp,
              hpColor,
              '${(status.hp * 100).round()} %',
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: bar(
              Icons.circle_outlined,
              ammo,
              ammo <= 0 ? GameColors.danger : const Color(0xFF4FC3F7),
              '${status.ammo}',
            ),
          ),
        ],
      ),
    );
  }

  /// Items to set off and, in a defense round, the shop: the guns to build
  /// where the tank stands, the upgrades for it, and the host's calls. All of
  /// it used to wait on the screen, out of reach of a player with a phone in
  /// both hands.
  Widget _gear(PadStatus status) {
    if (status.items.isEmpty && !status.defense) {
      return const SizedBox.shrink();
    }
    final near = status.near;
    final open = _shop;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (status.deciding) ...[
            _decision(status),
            const SizedBox(height: 6),
          ],
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final (i, (type, count)) in status.items.indexed)
                _Chip(
                  icon: type.icon,
                  color: type.color,
                  label: count > 1 ? '${type.short} ×$count' : type.short,
                  onTap: () => _remote.act(PadActionKind.item, i),
                ),
              if (status.defense) ...[
                _Funds(credits: status.credits),
                _Chip(
                  icon: Icons.construction_outlined,
                  color: GameColors.oliveLight,
                  label: tr('TÜRME', 'TOWERS'),
                  selected: open == _Shop.towers,
                  dot: status.towerReady,
                  onTap: () => _toggle(_Shop.towers),
                ),
                _Chip(
                  icon: Icons.upgrade_outlined,
                  color: GameColors.oliveLight,
                  label: 'UPGRADES',
                  selected: open == _Shop.upgrades,
                  dot: status.upgradeReady,
                  onTap: () => _toggle(_Shop.upgrades),
                ),
                if (near != null && near.$3 > 0)
                  _Chip(
                    icon: Icons.keyboard_double_arrow_up_outlined,
                    color: GameColors.amber,
                    label: '${near.$1.label} ${near.$3}',
                    enabled: near.$4,
                    onTap: () => _remote.act(PadActionKind.raise),
                  ),
                if (status.callWave)
                  _Chip(
                    icon: Icons.fast_forward_outlined,
                    color: GameColors.amber,
                    label: tr('WELLE JETZT', 'WAVE NOW'),
                    onTap: () => _remote.act(PadActionKind.wave),
                  ),
                if (status.canEnd && !status.deciding)
                  _Chip(
                    icon: Icons.flag_outlined,
                    color: GameColors.sand,
                    label: tr('BEENDEN', 'END'),
                    onTap: () => _remote.act(PadActionKind.end),
                  ),
              ],
            ],
          ),
          if (status.defense && open != null) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: open == _Shop.towers
                  ? [
                      for (final (kind, cost, ready) in status.shop)
                        _Chip(
                          icon: Icons.add_location_alt_outlined,
                          color: GameColors.oliveLight,
                          label: '${kind.label} $cost',
                          enabled: ready,
                          onTap: () =>
                              _remote.act(PadActionKind.place, kind.index),
                        ),
                    ]
                  : [
                      for (final (kind, level, limit, cost) in status.upgrades)
                        _Chip(
                          icon: Icons.upgrade_outlined,
                          color: kind.color,
                          label:
                              '${kind.label} '
                              '${'●' * level}${'○' * max(0, limit - level)}'
                              '${level < limit ? ' $cost' : ''}',
                          enabled: level < limit && status.credits >= cost,
                          onTap: () =>
                              _remote.act(PadActionKind.upgrade, kind.index),
                        ),
                    ],
            ),
          ],
        ],
      ),
    );
  }

  void _toggle(_Shop shop) =>
      setState(() => _shop = _shop == shop ? null : shop);

  /// After the last wave of a stretch: the host extends or ends, everybody
  /// else waits for the host.
  Widget _decision(PadStatus status) {
    final host = status.canExtend || status.canEnd;
    return Panel(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            tr('SIEG GESICHERT', 'VICTORY SECURED'),
            style: const TextStyle(
              color: GameColors.amber,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
          if (status.canExtend)
            _Chip(
              icon: Icons.add_outlined,
              color: GameColors.amber,
              label: tr(
                '${GameConfig.defenseExtension} WELLEN',
                '${GameConfig.defenseExtension} WAVES',
              ),
              onTap: () => _remote.act(PadActionKind.extend),
            ),
          if (status.canEnd)
            _Chip(
              icon: Icons.flag_outlined,
              color: GameColors.sand,
              label: tr('BEENDEN', 'END'),
              onTap: () => _remote.act(PadActionKind.end),
            ),
          if (!host)
            Text(
              tr(
                'Der Host entscheidet, ob es weitergeht.',
                'The host decides whether it goes on.',
              ),
              style: const TextStyle(color: GameColors.textDim, fontSize: 12),
            ),
        ],
      ),
    );
  }
}

enum _Shop { towers, upgrades }

/// The funds of a defense round, beside the shop's buttons.
class _Funds extends StatelessWidget {
  const _Funds({required this.credits});

  final int credits;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: tr('Mittel $credits', 'Funds $credits'),
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$credits',
              style: const TextStyle(
                color: GameColors.amber,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(width: 3),
            const Icon(Icons.paid_outlined, size: 16, color: GameColors.amber),
          ],
        ),
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
    this.enabled = true,
    this.selected = false,
    this.dot = false,
  });

  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  /// Faint and without effect when the funds or the rules say no.
  final bool enabled;

  /// The list behind it is folded out.
  final bool selected;

  /// The funds reach for something behind it.
  final bool dot;

  @override
  Widget build(BuildContext context) {
    final edge = enabled ? color : color.withValues(alpha: 0.3);
    return Semantics(
      button: true,
      enabled: enabled,
      selected: selected,
      label: label,
      value: dot ? tr('Mittel reichen', 'Funds suffice') : null,
      child: ExcludeSemantics(
        child: Badge(
          isLabelVisible: dot,
          smallSize: 10,
          backgroundColor: GameColors.amber,
          offset: const Offset(-2, 2),
          child: Material(
            color: selected ? color.withValues(alpha: 0.28) : GameColors.panel,
            shape: GameShapes.chip(edge: edge, width: 1.8),
            child: InkWell(
              onTap: enabled
                  ? () {
                      Haptics.feel(HapticFeedback.selectionClick);
                      onTap();
                    }
                  : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 18, color: edge),
                    const SizedBox(width: 6),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: enabled
                            ? GameColors.text
                            : GameColors.textDim.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
