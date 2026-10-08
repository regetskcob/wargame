import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme.dart';
import 'demo_painter.dart';
import 'tutorial_steps.dart';

/// The tutorial: first the controls, one card each, acted out on a small
/// training ground with a thumb on the sticks or with keys and mouse. Then
/// a quick tour through everything the game has, which plays on by itself.
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
    _scene.dispose();
    _auto.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// Starts the scene of the current step over, and the timer of the tour.
  void _enter() {
    _scene
      ..reset()
      ..repeat();
    _auto.reset();
    if (_step.quick && _playing) {
      _auto.forward();
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
    if (_playing && _step.quick) {
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

  @override
  Widget build(BuildContext context) {
    final step = _step;
    return Focus(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: _onKey,
      child: Material(
        color: BwColors.background,
        child: LayoutBuilder(
          builder: (context, _) {
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
          child: RepaintBoundary(
            child: CustomPaint(
              painter: DemoPainter(
                scene: step.scene,
                touch: _touch,
                clock: _scene,
                top: _cardBottom,
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

  Widget _header() {
    return Row(
      children: [
        const Icon(Icons.school, color: BwColors.amber, size: 20),
        const SizedBox(width: 8),
        const Expanded(
          child: Text(
            'EINWEISUNG',
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
              color: BwColors.sand,
            ),
          ),
        ),
        TextButton.icon(
          onPressed: widget.onClose,
          icon: const Icon(Icons.close, size: 18),
          label: const Text('ÜBERSPRINGEN'),
        ),
      ],
    );
  }

  Widget _card(TutorialStep step) {
    final controls = controlSteps(touch: _touch);
    final kicker = _index < controls
        ? 'STEUERUNG ${_touch ? 'TOUCH' : 'TASTATUR & MAUS'} · '
              '${_index + 1}/$controls'
        : step.quick
        ? 'SCHNELLDURCHLAUF · ${_index - controls + 1}/'
              '${_steps.length - controls - 1}'
        : 'ABGESCHLOSSEN';
    // Phones in landscape: title and buttons share a line, so the scene
    // keeps room below the card.
    final compact = MediaQuery.sizeOf(context).height < 500;
    final title = Row(
      children: [
        Icon(step.icon, color: BwColors.amber, size: compact ? 18 : 22),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            step.title,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontSize: compact ? 18 : null,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
              color: BwColors.sand,
            ),
          ),
        ),
      ],
    );
    final buttons = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (step.quick)
          IconButton(
            tooltip: _playing ? 'Anhalten' : 'Weiterlaufen',
            visualDensity: VisualDensity.compact,
            onPressed: _togglePlay,
            icon: Icon(_playing ? Icons.pause : Icons.play_arrow),
          ),
        if (_index > 0)
          TextButton(onPressed: _back, child: const Text('ZURÜCK')),
        const SizedBox(width: 4),
        FilledButton.icon(
          onPressed: _next,
          style: FilledButton.styleFrom(
            padding: EdgeInsets.symmetric(
              horizontal: 16,
              vertical: compact ? 6 : 10,
            ),
          ),
          icon: Icon(_last ? Icons.check : Icons.chevron_right),
          label: Text(_last ? "LOS GEHT'S" : 'WEITER'),
        ),
      ],
    );
    return DecoratedBox(
      key: _cardKey,
      decoration: ShapeDecoration(
        color: BwColors.panel,
        shape: BeveledRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: BwColors.amber, width: 1.5),
        ),
        shadows: const [BoxShadow(color: Color(0x88000000), blurRadius: 16)],
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(14, compact ? 8 : 12, 14, 8),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 200),
          alignment: Alignment.topCenter,
          onEnd: _measureCard,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      kicker,
                      style: const TextStyle(
                        color: BwColors.amber,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                  if (compact) _Dots(count: _steps.length, index: _index),
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
              SizedBox(height: compact ? 2 : 6),
              Text(
                step.text,
                style: TextStyle(
                  color: BwColors.text,
                  fontSize: compact ? 13 : 14,
                  height: 1.35,
                ),
              ),
              SizedBox(height: compact ? 6 : 8),
              if (step.quick)
                AnimatedBuilder(
                  animation: _auto,
                  builder: (context, _) =>
                      LinearProgressIndicator(value: _auto.value, minHeight: 3),
                ),
              if (!compact)
                Row(
                  children: [
                    _Dots(count: _steps.length, index: _index),
                    const Spacer(),
                    buttons,
                  ],
                ),
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
    return Flexible(
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: [
          for (var i = 0; i < count; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: i == index ? 14 : 6,
              height: 6,
              color: i == index
                  ? BwColors.amber
                  : i < index
                  ? BwColors.oliveLight
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
                color: BwColors.text,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
