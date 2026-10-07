import 'package:flutter/material.dart';

import '../game/game_mode.dart';
import '../game/space_game.dart';
import '../game_config.dart';
import '../net/room.dart';
import '../theme.dart';
import 'widgets/mute_button.dart';
import 'widgets/pilot_card.dart';
import 'widgets/room_list.dart';

/// Start page of the host: alone, with others or together against waves.
/// Everything else is set in the waiting room that follows.
class LaunchView extends StatelessWidget {
  const LaunchView({required this.game, super.key});

  final SpaceGame game;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  'PANZERGEFECHT',
                  maxLines: 1,
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
              ),
            ),
            const SizedBox(width: 12),
            _CallSign(game: game),
            const MuteButton(),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Wähle, wie du spielen willst.',
          style: TextStyle(color: BwColors.textDim),
        ),
        const SizedBox(height: 16),
        PilotCard(progress: game.progress),
        const SizedBox(height: 20),
        LayoutBuilder(
          builder: (context, box) {
            // Three cards side by side when there is room, else one per row.
            // All three equally tall, so the row reads calmly.
            if (box.maxWidth >= 640) {
              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final (i, option) in _options.indexed) ...[
                      if (i > 0) const SizedBox(width: 12),
                      Expanded(
                        child: _ModeCard(
                          option: option,
                          stretched: true,
                          onTap: () => game.chooseMode(option.mode),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, option) in _options.indexed) ...[
                  if (i > 0) const SizedBox(height: 12),
                  _ModeCard(
                    option: option,
                    onTap: () => game.chooseMode(option.mode),
                  ),
                ],
              ],
            );
          },
        ),
        if (roomLink(game.net.room).isNotEmpty) ...[
          const SizedBox(height: 28),
          RoomList(game: game),
        ],
      ],
    );
  }
}

typedef _Option = ({
  GameMode mode,
  IconData icon,
  String title,
  String kicker,
  String text,
});

const List<_Option> _options = [
  (
    mode: GameMode.solo,
    icon: Icons.person,
    title: 'EINZELSPIELER',
    kicker: 'ALLEIN GEGEN CPU',
    text:
        'Du gegen ${GameConfig.minBots} bis ${GameConfig.maxBots} '
        'CPU-Panzer auf drei Stufen. Der letzte Panzer im Feld gewinnt.',
  ),
  (
    mode: GameMode.multi,
    icon: Icons.groups,
    title: 'MEHRSPIELER',
    kicker: 'GEFECHT MIT ANDEREN',
    text:
        'Lade per Link oder Code ein, alle gegen alle oder Rot gegen Blau. '
        'CPU-Panzer füllen auf Wunsch auf.',
  ),
  (
    mode: GameMode.defense,
    icon: Icons.shield,
    title: 'VERTEIDIGUNG',
    kicker: 'TOWER DEFENSE',
    text:
        'Haltet gemeinsam den Stützpunkt gegen ${GameConfig.defenseWaves} '
        'Wellen. Abschüsse bringen Mittel für Geschütze.',
  ),
];

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.option,
    required this.onTap,
    this.stretched = false,
  });

  final _Option option;
  final VoidCallback onTap;

  /// Side by side the card is as tall as its neighbours, and WEITER sits at
  /// the bottom.
  final bool stretched;

  @override
  Widget build(BuildContext context) {
    final shape = BeveledRectangleBorder(
      borderRadius: BorderRadius.circular(8),
      side: const BorderSide(color: BwColors.oliveLight, width: 1.5),
    );
    return Material(
      color: const Color(0x44000000),
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        hoverColor: const Color(0x22FFB300),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(option.icon, color: BwColors.amber, size: 36),
              const SizedBox(height: 12),
              // Shrinks on narrow cards instead of breaking the word.
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  option.title,
                  maxLines: 1,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                    color: BwColors.sand,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                option.kicker,
                style: const TextStyle(
                  color: BwColors.amber,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                option.text,
                style: const TextStyle(
                  color: BwColors.text,
                  fontSize: 14,
                  height: 1.35,
                ),
              ),
              if (stretched) const Spacer(),
              const SizedBox(height: 14),
              const Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'WEITER',
                    style: TextStyle(
                      color: BwColors.amber,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                    ),
                  ),
                  Icon(Icons.chevron_right, color: BwColors.amber),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The player's call sign at the top: tap to change it.
class _CallSign extends StatefulWidget {
  const _CallSign({required this.game});

  final SpaceGame game;

  @override
  State<_CallSign> createState() => _CallSignState();
}

class _CallSignState extends State<_CallSign> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  var _editing = false;

  @override
  void initState() {
    super.initState();
    widget.game.pilotVersion.addListener(_refresh);
    _focus.addListener(() {
      if (!_focus.hasFocus && _editing) {
        _save();
      }
    });
  }

  void _refresh() => setState(() {});

  @override
  void dispose() {
    widget.game.pilotVersion.removeListener(_refresh);
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _edit() {
    _controller
      ..text = widget.game.myName
      ..selection = TextSelection(
        baseOffset: 0,
        extentOffset: widget.game.myName.length,
      );
    setState(() => _editing = true);
    _focus.requestFocus();
  }

  void _save() {
    final game = widget.game;
    game.setPilot(name: _controller.text, colorIndex: game.myColorIndex);
    // The waiting room reads the name again from the game.
    game.pilotVersion.value++;
    setState(() => _editing = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_editing) {
      return SizedBox(
        width: 220,
        child: TextField(
          controller: _controller,
          focusNode: _focus,
          maxLength: 16,
          decoration: InputDecoration(
            labelText: 'RUFNAME',
            counterText: '',
            isDense: true,
            suffixIcon: IconButton(
              tooltip: 'Speichern',
              onPressed: _save,
              icon: const Icon(Icons.check, color: BwColors.amber),
            ),
          ),
          onSubmitted: (_) => _save(),
        ),
      );
    }
    return Tooltip(
      message: 'Rufnamen ändern',
      child: InkWell(
        onTap: _edit,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 260),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: ShapeDecoration(
            color: const Color(0x44000000),
            shape: BeveledRectangleBorder(
              borderRadius: BorderRadius.circular(6),
              side: const BorderSide(color: BwColors.oliveLight, width: 1.5),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.badge_outlined, size: 18, color: BwColors.amber),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  widget.game.myName,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.edit, size: 16, color: BwColors.textDim),
            ],
          ),
        ),
      ),
    );
  }
}
