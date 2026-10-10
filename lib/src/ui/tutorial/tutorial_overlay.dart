import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../game/special_weapon.dart';
import '../../game/touch_input.dart';
import '../theme.dart';
import '../widgets/touch_controls.dart';
import 'demo_painter.dart';
import 'practice.dart';
import 'tutorial_steps.dart';
import '../../l10n/l10n.dart';
import '../../tv/tv_input.dart';

/// The tutorial: first the controls, one card each, acted out on a small
/// training ground with a thumb on the sticks or with keys and mouse. Then
/// a quick tour through everything the game has. Every card plays on by
/// itself after a while.
///
/// On a controls card the player can take over at any time: a thumb on the
/// sticks, a game key or a click turns the scene into a training ground with
/// their own tank and the game's controls. From then on the card waits for
/// WEITER instead of moving on by itself.
///
/// A button opens it on the welcome page, the start page and in the
/// waiting room, always with the controls of the device it runs on.
class TutorialOverlay extends StatefulWidget {
  const TutorialOverlay({
    required this.touch,
    required this.onClose,
    super.key,
  });

  /// Whether to explain the touch controls instead of keyboard and mouse.
  final bool touch;
  final VoidCallback onClose;

  /// How long one pass of a demo scene takes.
  static const scenePass = Duration(milliseconds: 3600);

  /// How long a card of the quick tour stays.
  static const tourCard = Duration(milliseconds: 5000);

  /// How long a controls card stays when nobody takes over: two passes of
  /// its scene.
  static const controlsCard = Duration(milliseconds: 7200);

  /// Marks the card, for tests.
  static const cardKey = ValueKey('tutorial-card');

  @override
  State<TutorialOverlay> createState() => _TutorialOverlayState();
}

class _TutorialOverlayState extends State<TutorialOverlay>
    with TickerProviderStateMixin {
  bool get _touch => widget.touch;
  var _index = 0;
  var _playing = true;
  final _cardKey = GlobalKey();
  final _focus = FocusNode(debugLabel: 'tutorial');
  double _cardBottom = 200;
  Size _stageSize = Size.zero;

  /// The player's own tank once they took over this card, else null.
  TutorialPractice? _practice;
  var _input = TouchInput();
  final _special = ValueNotifier<(SpecialWeapon, int)?>(null);
  late final _ticker = createTicker(_tick);
  var _lastTick = Duration.zero;

  late final _scene = AnimationController(
    vsync: this,
    duration: TutorialOverlay.scenePass,
  )..repeat();

  late final _auto =
      AnimationController(vsync: this, duration: TutorialOverlay.tourCard)
        ..addStatusListener((status) {
          if (status == AnimationStatus.completed) {
            _next();
          }
        });

  List<TutorialStep> get _steps => tutorialSteps(touch: _touch);
  TutorialStep get _step => _steps[_index];
  bool get _last => _index == _steps.length - 1;

  /// Only the controls cards can be tried out, and not with a remote.
  bool get _canPractice => !onTv && _index < controlSteps(touch: _touch);

  /// How long this card stays by itself, null when it waits for WEITER.
  Duration? get _autoTime => _practice != null || _step.scene == DemoScene.ready
      ? null
      : _step.quick
      ? TutorialOverlay.tourCard
      : TutorialOverlay.controlsCard;

  @override
  void initState() {
    super.initState();
    _enter();
    // The game holds the keyboard, autofocus alone would not take it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focus.requestFocus();
      }
    });
  }

  /// The first touch on a laptop switches to the touch controls. Inside the
  /// controls chapter the tutorial starts over, in the tour it stays on the
  /// same card.
  @override
  void didUpdateWidget(TutorialOverlay old) {
    super.didUpdateWidget(old);
    if (old.touch == widget.touch) {
      return;
    }
    final before = controlSteps(touch: old.touch);
    final after = controlSteps(touch: widget.touch);
    _index = _index < before ? 0 : _index - before + after;
    _enter();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _practice?.dispose();
    _special.dispose();
    _scene.dispose();
    _auto.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// Starts the scene of the current step over, and its timer. A new card
  /// starts as a demonstration again.
  void _enter() {
    _endPractice();
    _scene
      ..reset()
      ..repeat();
    _auto.reset();
    final time = _autoTime;
    if (time != null) {
      _auto.duration = time;
      if (_playing) {
        _auto.forward();
      }
    }
  }

  /// The player takes over: their own tank on the stage, and the card no
  /// longer moves on by itself.
  void _takeOver() {
    if (!_canPractice || _practice != null || _stageSize.isEmpty) {
      return;
    }
    _auto
      ..stop()
      ..reset();
    setState(() {
      _practice = TutorialPractice(
        touch: _touch,
        bounds: _practiceBounds,
        grenades: _step.scene == DemoScene.special,
        input: _input,
      );
    });
    _lastTick = Duration.zero;
    _ticker.start();
  }

  void _endPractice() {
    _ticker.stop();
    _practice?.dispose();
    _practice = null;
    _special.value = null;
    // Fresh sticks for the next card, nothing still held from this one.
    _input = TouchInput();
  }

  Rect get _practiceBounds =>
      Rect.fromLTRB(0, _cardBottom, _stageSize.width, _stageSize.height);

  void _tick(Duration elapsed) {
    final practice = _practice;
    if (practice == null) {
      return;
    }
    final dt = (elapsed - _lastTick).inMicroseconds / 1e6;
    _lastTick = elapsed;
    practice
      ..bounds = _practiceBounds
      ..tick(dt, pressed: HardwareKeyboard.instance.logicalKeysPressed);
    if (practice.grenades) {
      final loadout = (SpecialWeapon.grenades, practice.charges);
      if (_special.value != loadout) {
        _special.value = loadout;
      }
    }
  }

  /// The scene plays below the card, so it needs to know where it ends.
  void _measureCard() {
    final card = _cardKey.currentContext?.findRenderObject() as RenderBox?;
    final stage = context.findRenderObject() as RenderBox?;
    if (!mounted || card == null || stage == null || !card.hasSize) {
      return;
    }
    final bottom =
        stage.globalToLocal(card.localToGlobal(Offset.zero)).dy +
        card.size.height;
    if ((bottom - _cardBottom).abs() > 1) {
      setState(() => _cardBottom = bottom);
    }
  }

  void _go(int index) {
    if (index < 0) {
      return;
    }
    if (index >= _steps.length) {
      widget.onClose();
      return;
    }
    setState(() => _index = index);
    _enter();
  }

  void _next() => _go(_index + 1);
  void _back() => _go(_index - 1);

  void _togglePlay() {
    setState(() => _playing = !_playing);
    if (_playing && _autoTime != null) {
      _auto.forward();
    } else {
      _auto.stop();
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    // The game's keys take over the card. While practising, the arrow keys
    // and space drive and fire as in the game, ENTER moves on.
    if (_canPractice && !_touch && _gameKeys.contains(key)) {
      _takeOver();
      return KeyEventResult.handled;
    }
    if (_practice != null && _practiceKeys.contains(key)) {
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.space) {
      _next();
    } else if (key == LogicalKeyboardKey.arrowLeft) {
      _back();
    } else if (key == LogicalKeyboardKey.escape) {
      widget.onClose();
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  static final _gameKeys = {
    LogicalKeyboardKey.keyW,
    LogicalKeyboardKey.keyA,
    LogicalKeyboardKey.keyS,
    LogicalKeyboardKey.keyD,
    LogicalKeyboardKey.keyQ,
    LogicalKeyboardKey.keyE,
    LogicalKeyboardKey.keyF,
  };

  static final _practiceKeys = {
    LogicalKeyboardKey.arrowUp,
    LogicalKeyboardKey.arrowDown,
    LogicalKeyboardKey.arrowLeft,
    LogicalKeyboardKey.arrowRight,
    LogicalKeyboardKey.space,
  };

  @override
  Widget build(BuildContext context) {
    final step = _step;
    // A scope of its own: a remote walks its buttons and never the page
    // below it.
    return FocusScope(child: _keys(step));
  }

  Widget _keys(TutorialStep step) {
    return Focus(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: _onKey,
      child: Material(
        color: GameColors.background,
        child: LayoutBuilder(
          builder: (context, constraints) {
            _stageSize = constraints.biggest;
            // A new size can move the card's lower edge.
            WidgetsBinding.instance.addPostFrameCallback((_) => _measureCard());
            return _stage(step);
          },
        ),
      ),
    );
  }

  Widget _stage(TutorialStep step) {
    return Stack(
      children: [
        Positioned.fill(
          child: _mouse(
            RepaintBoundary(
              child: CustomPaint(
                painter: DemoPainter(
                  scene: step.scene,
                  touch: _touch,
                  pad: onTv ? tvPadForTutorial : null,
                  clock: _scene,
                  top: _cardBottom,
                  practice: _practice,
                  invite: _canPractice && _practice == null,
                ),
              ),
            ),
          ),
        ),
        // The game's own sticks lie over the stage, unseen until a thumb
        // lands on one: that touch already steers, and the scene turns into
        // the training ground.
        if (_touch && _canPractice)
          Positioned.fill(
            child: Listener(
              onPointerDown: (_) => _takeOver(),
              child: Opacity(
                opacity: _practice == null ? 0 : 1,
                child: TouchControls(
                  key: ValueKey(_index),
                  input: _input,
                  special: _special,
                ),
              ),
            ),
          ),
        SafeArea(
          minimum: const EdgeInsets.all(8),
          child: Column(
            children: [
              _header(),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.sizeOf(context).height < 500 ? 680 : 520,
                ),
                child: _card(step),
              ),
              if (step.chips.isNotEmpty)
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 760),
                      child: SingleChildScrollView(
                        child: _Chips(
                          key: ValueKey(step.title),
                          chips: step.chips,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// The mouse on the stage: a click takes over, then it aims and fires.
  Widget _mouse(Widget child) {
    if (_touch || !_canPractice) {
      return child;
    }
    return MouseRegion(
      onHover: (e) => _practice?.mouse = e.localPosition,
      child: Listener(
        onPointerDown: (e) {
          if (e.kind != PointerDeviceKind.mouse) {
            return;
          }
          _takeOver();
          _practice
            ?..mouse = e.localPosition
            ..mouseDown = true;
        },
        onPointerMove: (e) => _practice?.mouse = e.localPosition,
        onPointerUp: (_) => _practice?.mouseDown = false,
        onPointerCancel: (_) => _practice?.mouseDown = false,
        child: child,
      ),
    );
  }

  /// [child] when [shown], else an empty space of its size.
  /// Hidden it also takes no focus, or a remote would land on nothing.
  static Widget _keep(bool shown, Widget child) => ExcludeFocus(
    excluding: !shown,
    child: Visibility(
      visible: shown,
      maintainSize: true,
      maintainAnimation: true,
      maintainState: true,
      child: child,
    ),
  );

  Widget _header() {
    return Row(
      children: [
        const Icon(Icons.school_outlined, color: GameColors.amber, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            tr('EINWEISUNG', 'BRIEFING'),
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
              color: GameColors.sand,
            ),
          ),
        ),
        TextButton.icon(
          onPressed: widget.onClose,
          icon: const Icon(Icons.close_outlined, size: 18),
          label: Text(tr('ÜBERSPRINGEN', 'SKIP')),
        ),
      ],
    );
  }

  Widget _card(TutorialStep step) {
    final controls = controlSteps(touch: _touch);
    final kicker = _index < controls
        ? '${tr('STEUERUNG', 'CONTROLS')} '
              '${onTv
                  ? (tvPadForTutorial == TvPadKind.gamepad ? 'CONTROLLER' : remoteName.toUpperCase())
                  : _touch
                  ? 'TOUCH'
                  : tr('TASTATUR & MAUS', 'KEYBOARD & MOUSE')} · '
              '${_index + 1}/$controls'
        : step.quick
        ? '${tr('SCHNELLDURCHLAUF', 'QUICK TOUR')} · '
              '${_index - controls + 1}/${_steps.length - controls - 1}'
        : tr('ABGESCHLOSSEN', 'COMPLETE');
    final heading = _practice == null
        ? kicker
        : '$kicker · ${tr('DU STEUERST', 'YOUR TURN')}';
    final auto = _autoTime != null;
    // Phones in landscape: title and buttons share a line, so the scene
    // keeps room below the card.
    final compact = MediaQuery.sizeOf(context).height < 500;
    final title = Row(
      children: [
        Icon(step.icon, color: GameColors.amber, size: compact ? 18 : 22),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            step.title,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontSize: compact ? 18 : null,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
              color: GameColors.sand,
            ),
          ),
        ),
      ],
    );
    final buttons = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Hidden buttons keep their place, so WEITER never moves.
        _keep(
          auto,
          IconButton(
            tooltip: _playing
                ? tr('Anhalten', 'Pause')
                : tr('Weiterlaufen', 'Resume'),
            visualDensity: VisualDensity.compact,
            onPressed: _togglePlay,
            icon: Icon(
              _playing ? Icons.pause_outlined : Icons.play_arrow_outlined,
            ),
          ),
        ),
        _keep(
          _index > 0,
          TextButton(onPressed: _back, child: Text(tr('ZURÜCK', 'BACK'))),
        ),
        const SizedBox(width: 4),
        FilledButton.icon(
          onPressed: _next,
          style: FilledButton.styleFrom(
            padding: EdgeInsets.symmetric(
              horizontal: 16,
              vertical: compact ? 6 : 10,
            ),
          ),
          icon: Icon(
            _last ? Icons.check_outlined : Icons.chevron_right_outlined,
          ),
          // As wide for both labels, so the button stays put on the last card.
          label: Stack(
            alignment: Alignment.center,
            children: [
              _keep(!_last, Text(tr('WEITER', 'NEXT'))),
              _keep(_last, Text(tr("LOS GEHT'S", "LET'S GO"))),
            ],
          ),
        ),
      ],
    );
    return KeyedSubtree(
      key: TutorialOverlay.cardKey,
      child: DecoratedBox(
        key: _cardKey,
        decoration: ShapeDecoration(
          color: GameColors.panel,
          shape: BeveledRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: GameColors.amber, width: 1.5),
          ),
          shadows: const [BoxShadow(color: Color(0x88000000), blurRadius: 16)],
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(14, compact ? 8 : 12, 14, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      heading,
                      style: const TextStyle(
                        color: GameColors.amber,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                  if (compact) ...[
                    const SizedBox(width: 12),
                    _Dots(count: _steps.length, index: _index),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              if (compact)
                Row(
                  children: [
                    Expanded(child: title),
                    buttons,
                  ],
                )
              else
                title,
              // While the player drives, the text folds away and leaves them
              // the stage; they have read it already.
              if (_practice == null) ...[
                SizedBox(height: compact ? 2 : 6),
                // Every text of the tutorial is laid out, only this step's
                // shows: the card is as tall as for the longest text and keeps
                // its height from step to step.
                Stack(
                  children: [
                    for (final (i, other) in _steps.indexed)
                      _keep(
                        i == _index,
                        Text(
                          other.text,
                          style: TextStyle(
                            color: GameColors.text,
                            fontSize: compact ? 13 : 14,
                            height: 1.35,
                          ),
                        ),
                      ),
                  ],
                ),
                SizedBox(height: compact ? 6 : 8),
                _keep(
                  auto,
                  AnimatedBuilder(
                    animation: _auto,
                    builder: (context, _) => LinearProgressIndicator(
                      value: _auto.value,
                      minHeight: 3,
                    ),
                  ),
                ),
              ] else
                SizedBox(height: compact ? 2 : 0),
              if (!compact) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: _Dots(count: _steps.length, index: _index),
                      ),
                    ),
                    const SizedBox(width: 12),
                    buttons,
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Where in the tutorial the player is.
class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    // Always one line: on a narrow card the row shrinks instead of wrapping.
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < count; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: EdgeInsets.only(left: i == 0 ? 0 : 4),
              width: i == index ? 14 : 6,
              height: 6,
              color: i == index
                  ? GameColors.amber
                  : i < index
                  ? GameColors.oliveLight
                  : const Color(0x55BFC6AA),
            ),
        ],
      ),
    );
  }
}

/// The chips of a tour card, popping up one after the other.
class _Chips extends StatefulWidget {
  const _Chips({required this.chips, super.key});

  final List<TutorialChip> chips;

  @override
  State<_Chips> createState() => _ChipsState();
}

class _ChipsState extends State<_Chips> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: 300 + 120 * widget.chips.length),
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.chips.length;
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (i, chip) in widget.chips.indexed)
          ScaleTransition(
            scale: CurvedAnimation(
              parent: _controller,
              curve: Interval(
                i / (n + 1),
                (i + 2) / (n + 1),
                curve: Curves.easeOutBack,
              ),
            ),
            child: _Chip(chip: chip),
          ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.chip});

  final TutorialChip chip;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: const Color(0xCC161C0F),
        shape: BeveledRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: BorderSide(color: chip.color, width: 1.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(chip.icon, size: 18, color: chip.color),
            const SizedBox(width: 8),
            Text(
              chip.label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                color: GameColors.text,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
