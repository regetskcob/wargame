import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:horizont/horizont.dart';

import '../app/env.dart';
import '../app/routes.dart';
import '../game/game_config.dart';
import '../game/game_phase.dart';
import '../game/special_weapon.dart';
import '../haptics.dart';
import '../net/pad_link.dart';
import '../net/payloads/pad_payload.dart';
import 'theme.dart';
import '../game/inventory.dart';
import 'widgets/health_bar.dart';
import 'widgets/inventory_bar.dart';
import 'widgets/panel.dart';
import 'widgets/tablet_scale.dart';
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

  /// Only the app on a phone becomes a controller. A tablet, or any
  /// browser that opened a pairing link, says so instead and never takes a
  /// seat on the screen.
  final _phone = !kIsWeb && deviceIsPhone;

  @override
  void initState() {
    super.initState();
    if (!_phone) {
      return;
    }
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
    if (_phone) {
      _remote.status.removeListener(_onStatus);
      _remote.screenOnline.removeListener(_onOnline);
      if (widget.remote == null) {
        unawaited(_remote.stop());
      }
    }
    _special.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_phone) {
      return _tabletNotice(context);
    }
    return Scaffold(
      backgroundColor: GameColors.bg,
      body: ValueListenableBuilder<PadStatus?>(
        valueListenable: _remote.status,
        builder: (context, status, _) => LayoutBuilder(
          builder: (context, box) {
            final wide = box.maxWidth > box.maxHeight;
            final playing = status != null && status.phase == GamePhase.playing;
            return Stack(
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
                  minimum: const EdgeInsets.all(HzSpace.s12),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _header(status, wide: wide),
                        if (playing && status.defense) ...[
                          const SizedBox(height: HzSpace.s8),
                          _defense(status, wide: wide),
                        ],
                      ],
                    ),
                  ),
                ),
                if (playing && status.items.isNotEmpty)
                  _inventory(status, wide: wide),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _tabletNotice(BuildContext context) {
    return Scaffold(
      backgroundColor: GameColors.bg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Panel(
              padding: const EdgeInsets.all(HzSpace.s24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    kIsWeb
                        ? tr('NUR IN DER APP', 'IN THE APP ONLY')
                        : tr('NUR AUF DEM HANDY', 'ON PHONES ONLY'),
                    style: GameType.title,
                  ),
                  const SizedBox(height: HzSpace.s12),
                  Text(
                    kIsWeb
                        ? tr(
                            'Als Controller dient die Panzergefecht-App auf '
                                'dem Handy. Öffne dort Konto › Als Controller '
                                'nutzen und scanne den Code.',
                            'The Panzergefecht app on a phone serves as the '
                                'controller. Open Account › Use as controller '
                                'there and scan the code.',
                          )
                        : tr(
                            'Als Controller dient nur ein Handy. Auf einem '
                                'Tablet spielst du selbst und kannst unter '
                                'Konto › Handy koppeln ein Handy als '
                                'Controller dazunehmen.',
                            'Only a phone serves as a controller. On a tablet '
                                'you play yourself and can add a phone as a '
                                'controller under Account › Pair phone.',
                          ),
                    style: GameType.body.copyWith(color: GameColors.textMuted),
                  ),
                  const SizedBox(height: HzSpace.s16),
                  FilledButton(
                    onPressed: _close,
                    child: Text(tr('ZUM SPIEL', 'TO THE GAME')),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The items in the slots the game shows them in: down the left edge when
  /// upright, as on the screen, and between the thumbs when held sideways,
  /// where the top is taken by the status and the shop.
  Widget _inventory(PadStatus status, {required bool wide}) {
    return SafeArea(
      minimum: const EdgeInsets.all(HzSpace.s12),
      child: Align(
        alignment: wide ? Alignment.bottomCenter : const Alignment(-1, 0.15),
        child: Padding(
          padding: EdgeInsets.only(bottom: wide ? HzSpace.s12 : 0),
          child: InventoryStrip(
            slots: [
              for (final (type, count) in status.items)
                InventorySlot(type, count),
            ],
            axis: wide ? Axis.horizontal : Axis.vertical,
            compact: true,
            onUse: (i) {
              Haptics.feel(HapticFeedback.selectionClick);
              _remote.act(PadActionKind.item, i);
            },
          ),
        ),
      ),
    );
  }

  Widget _header(PadStatus? status, {required bool wide}) {
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
          padding: const EdgeInsets.fromLTRB(
            HzSpace.s12,
            HzSpace.s4,
            HzSpace.s4,
            HzSpace.s4,
          ),
          child: Row(
            children: [
              Icon(
                online ? HorizontSymbols.sportsEsports : HorizontSymbols.sync,
                color: online ? GameColors.text : GameColors.textMuted,
              ),
              const SizedBox(width: HzSpace.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            online && status != null && status.name.isNotEmpty
                                ? status.name
                                : tr('CONTROLLER', 'CONTROLLER'),
                            maxLines: 1,
                            overflow: TextOverflow.fade,
                            softWrap: false,
                            style: GameType.label.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        // The funds beside the name: the wide line had the
                        // room, the shop below it did not.
                        if (online &&
                            status != null &&
                            status.defense &&
                            status.phase == GamePhase.playing) ...[
                          const SizedBox(width: HzSpace.s16),
                          _Funds(credits: status.credits),
                        ],
                      ],
                    ),
                    if (hint != null)
                      Text(hint, style: GameType.caption)
                    else if (status != null)
                      _vitals(status, wide: wide),
                  ],
                ),
              ),
              // Upright the word took the width the gauges need.
              if (wide)
                TextButton.icon(
                  onPressed: _close,
                  icon: const Icon(
                    HorizontSymbols.linkOff,
                    size: HzIconSize.row,
                  ),
                  label: Text(tr('TRENNEN', 'UNPAIR')),
                )
              else
                IconButton(
                  tooltip: tr('Trennen', 'Unpair'),
                  onPressed: _close,
                  icon: const Icon(HorizontSymbols.linkOff),
                ),
            ],
          ),
        );
      },
    );
  }

  /// Armour, magazine and, where the level has it, fuel as thin bars, with
  /// the same warnings as the HUD's plate: bar and value turn warning or
  /// critical, and the sign of that state stands in for the icon.
  Widget _vitals(PadStatus status, {required bool wide}) {
    final ammo = status.magazine <= 0
        ? 1.0
        : (status.ammo / status.magazine).clamp(0.0, 1.0);
    Widget bar(
      IconData icon,
      double value,
      HorizontStatus? state,
      String label,
    ) {
      final color = stockColor(state);
      return Row(
        children: [
          Icon(
            state?.icon ?? icon,
            size: HzIconSize.badge,
            color: state == null ? GameColors.textMuted : color,
          ),
          const SizedBox(width: HzSpace.s4),
          Expanded(
            child: GaugeBar(value: value, status: state, height: HzSpace.s4),
          ),
          SizedBox(
            width: 44,
            child: Text(
              label,
              textAlign: TextAlign.right,
              maxLines: 1,
              softWrap: false,
              style: GameType.kennung.copyWith(color: color, letterSpacing: 0),
            ),
          ),
        ],
      );
    }

    final bars = [
      bar(
        HorizontSymbols.healthAndSafety,
        status.hp,
        armourStatus(status.hp),
        '${(status.hp * 100).round()} %',
      ),
      bar(
        // The crate of the HUD's plate, so both read the same.
        HorizontSymbols.inventory2,
        ammo,
        status.magazine > 0 && status.ammo <= 0
            ? HorizontStatus.critical
            : stockStatus(ammo, low: GameConfig.ammoLowShare),
        '${status.ammo}',
      ),
      if (status.fuel case final fuel?)
        bar(
          HorizontSymbols.localGasStation,
          fuel,
          stockStatus(fuel, low: GameConfig.fuelLowShare),
          '${(fuel * 100).round()} %',
        ),
    ];
    // Side by side when held sideways, one under the other upright, where
    // three in a row left no bar to see.
    return Padding(
      padding: const EdgeInsets.only(top: HzSpace.s4, right: HzSpace.s8),
      child: wide
          ? Row(
              children: [
                for (final (i, gauge) in bars.indexed) ...[
                  if (i > 0) const SizedBox(width: HzSpace.s12),
                  Expanded(child: gauge),
                ],
              ],
            )
          : Column(
              children: [
                for (final (i, gauge) in bars.indexed) ...[
                  if (i > 0) const SizedBox(height: HzSpace.s4),
                  gauge,
                ],
              ],
            ),
    );
  }

  /// The defense shop in two groups by purpose: building (guns, the gun
  /// next to the tank, the tank's upgrades) and the round (the host's next
  /// wave, the choice after a stretch, ending it). It all used to wait on
  /// the screen, out of reach of a player with a phone in both hands, and
  /// one long row of chips hid what was what.
  Widget _defense(PadStatus status, {required bool wide}) {
    final build = _buildGroup(status);
    final round = status.callWave || status.canEnd || status.deciding
        ? _roundGroup(status)
        : null;
    if (round == null) {
      return Align(alignment: Alignment.topLeft, child: build);
    }
    return wide
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Building on the left, the round's calls on the right, each
              // over the thumb that reaches it.
              Expanded(
                child: Align(alignment: Alignment.topLeft, child: build),
              ),
              const SizedBox(width: HzSpace.s8),
              round,
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              build,
              const SizedBox(height: HzSpace.s8),
              round,
            ],
          );
  }

  Widget _group(IconData icon, String title, List<Widget> children) {
    return Panel(
      padding: const EdgeInsets.fromLTRB(
        HzSpace.s12,
        HzSpace.s8,
        HzSpace.s12,
        HzSpace.s8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: HzIconSize.badge, color: GameColors.textMuted),
              const SizedBox(width: HzSpace.s4),
              Kennung(title),
            ],
          ),
          const SizedBox(height: HzSpace.s8),
          ...children,
        ],
      ),
    );
  }

  /// Guns and upgrades: two toggles and the gun next to the tank, the open
  /// list right under them.
  Widget _buildGroup(PadStatus status) {
    final near = status.near;
    final open = _shop;
    return _group(HorizontSymbols.construction, tr('AUSBAU', 'BUILD'), [
      Wrap(
        spacing: HzSpace.s8,
        runSpacing: HzSpace.s8,
        children: [
          _Chip(
            icon: HorizontSymbols.fort,
            color: GameColors.textMuted,
            label: tr('GESCHÜTZE', 'GUNS'),
            selected: open == _Shop.towers,
            dot: status.towerReady,
            onTap: () => _toggle(_Shop.towers),
          ),
          _Chip(
            icon: HorizontSymbols.upgrade,
            color: GameColors.textMuted,
            label: tr('AUFRÜSTUNG', 'UPGRADES'),
            selected: open == _Shop.upgrades,
            dot: status.upgradeReady,
            onTap: () => _toggle(_Shop.upgrades),
          ),
          if (near != null && near.$3 > 0)
            _Chip(
              icon: HorizontSymbols.keyboardDoubleArrowUp,
              color: GameColors.text,
              label: '${near.$1.label} ${near.$3}',
              enabled: near.$4,
              onTap: () => _remote.act(PadActionKind.raise),
            ),
        ],
      ),
      if (open != null) ...[
        const SizedBox(height: HzSpace.s8),
        Wrap(
          spacing: HzSpace.s8,
          runSpacing: HzSpace.s8,
          children: open == _Shop.towers
              ? [
                  for (final (kind, cost, ready) in status.shop)
                    _Chip(
                      icon: HorizontSymbols.addLocationAlt,
                      color: GameColors.textMuted,
                      label: '${kind.label} $cost',
                      enabled: ready,
                      onTap: () => _remote.act(PadActionKind.place, kind.index),
                    ),
                ]
              : [
                  for (final (kind, level, limit, cost) in status.upgrades)
                    _Chip(
                      icon: HorizontSymbols.upgrade,
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
    ]);
  }

  void _toggle(_Shop shop) =>
      setState(() => _shop = _shop == shop ? null : shop);

  /// The waves: the host calls the next one, decides after a stretch and
  /// ends a secured round; everybody else learns what is at stake.
  Widget _roundGroup(PadStatus status) {
    final host = status.canExtend || status.canEnd || status.callWave;
    return _group(HorizontSymbols.flag, tr('RUNDE', 'ROUND'), [
      if (status.deciding)
        Padding(
          padding: const EdgeInsets.only(bottom: HzSpace.s8),
          child: HorizontBadge(
            HorizontStatus.positive,
            label: tr('RUNDE GEWONNEN', 'VICTORY SECURED'),
          ),
        ),
      if (host)
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (status.callWave)
              _Chip(
                icon: HorizontSymbols.fastForward,
                color: GameColors.text,
                label: tr('WELLE JETZT', 'WAVE NOW'),
                onTap: () => _remote.act(PadActionKind.wave),
              ),
            if (status.canExtend) ...[
              if (status.callWave) const SizedBox(width: HzSpace.s8),
              _Chip(
                icon: HorizontSymbols.add,
                color: GameColors.text,
                label: tr(
                  '${GameConfig.defenseExtension} WELLEN',
                  '${GameConfig.defenseExtension} WAVES',
                ),
                onTap: () => _remote.act(PadActionKind.extend),
              ),
            ],
            if (status.canEnd) ...[
              if (status.callWave || status.canExtend)
                const SizedBox(width: HzSpace.s8),
              _Chip(
                icon: HorizontSymbols.flag,
                color: GameColors.text,
                label: tr('BEENDEN', 'END'),
                onTap: () => _remote.act(PadActionKind.end),
              ),
            ],
          ],
        )
      else
        Text(
          tr(
            'Der Gastgeber entscheidet, ob es weitergeht.',
            'The host decides whether it goes on.',
          ),
          style: GameType.caption,
        ),
    ]);
  }
}

enum _Shop { towers, upgrades }

/// The funds of a defense round, beside the pilot's name.
class _Funds extends StatelessWidget {
  const _Funds({required this.credits});

  final int credits;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: tr('Münzen $credits', 'Coins $credits'),
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$credits',
              style: GameType.data.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: HzSpace.s4),
            Icon(
              HorizontSymbols.paid,
              size: HzIconSize.inline,
              color: GameColors.textMuted,
            ),
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

  /// The colour of the icon: muted, ink, or the colour a thing has in the
  /// game (an upgrade's).
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
    final sign = enabled ? color : GameColors.textFaint;
    return Semantics(
      button: true,
      enabled: enabled,
      selected: selected,
      label: label,
      value: dot ? tr('Münzen reichen', 'Enough coins') : null,
      child: ExcludeSemantics(
        child: Badge(
          isLabelVisible: dot,
          smallSize: HzSpace.s8,
          backgroundColor: GameColors.accentText,
          offset: const Offset(-2, 2),
          // Folded out is the selection: the accent's line and tint.
          child: Material(
            color: selected ? GameColors.accentTint : GameColors.panel,
            shape: selected
                ? GameShapes.chip(
                    edge: GameColors.accentText,
                    width: HzLine.selection,
                  )
                : GameShapes.chip(
                    edge: enabled ? GameColors.lineStrong : GameColors.line,
                  ),
            child: InkWell(
              onTap: enabled
                  ? () {
                      Haptics.feel(HapticFeedback.selectionClick);
                      onTap();
                    }
                  : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: HzSpace.s12,
                  vertical: HzSpace.s8,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: HzIconSize.row, color: sign),
                    const SizedBox(width: HzSpace.s8),
                    Text(
                      label,
                      style: GameType.label.copyWith(
                        fontWeight: FontWeight.w600,
                        color: enabled ? GameColors.text : GameColors.textMuted,
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
