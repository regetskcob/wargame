import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../ui/theme.dart';

/// Draws an amber frame around whatever has the focus, so the menus can be
/// followed from the sofa while the remote or a controller moves through
/// them. The buttons' own focus shades are too faint for that, and cards
/// and list tiles have none at all.
///
/// Sits above everything, outside any scaling, and follows the focused
/// widget every frame, also while a list scrolls or a sheet slides in.
///
/// When the focus sits on nothing that can be pressed, as on the game
/// itself or after the focused button went away with its page, it moves on
/// to the first thing that can, unless [holdFocus] says the game keeps it.
class TvFocusFrame extends StatefulWidget {
  const TvFocusFrame({required this.child, required this.holdFocus, super.key});

  final Widget child;

  /// True while the game needs the focus for itself, as during a round.
  final bool Function() holdFocus;

  @override
  State<TvFocusFrame> createState() => _TvFocusFrameState();
}

class _TvFocusFrameState extends State<TvFocusFrame>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Rect? _rect;
  FocusNode? _stuck;
  Duration _stuckSince = Duration.zero;

  @override
  void initState() {
    super.initState();
    // There is no pointer on the Apple TV: focus always shows.
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
    // Measured once the frame is laid out, the focused box may be new.
    _ticker = createTicker(
      (elapsed) => SchedulerBinding.instance.addPostFrameCallback(
        (_) => _follow(elapsed),
      ),
    )..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _follow(Duration elapsed) {
    if (!mounted) {
      return;
    }
    final node = FocusManager.instance.primaryFocus;
    final screen = MediaQuery.sizeOf(context);
    Rect? rect;
    final box = node?.context?.findRenderObject();
    if (node != null && box is RenderBox && box.attached && box.hasSize) {
      final found = node.rect;
      // The game itself and whole pages take the focus too: no frame
      // around the screen.
      if (found.width * found.height < screen.width * screen.height * 0.4) {
        rect = found;
      }
    }
    if (rect != _rect) {
      setState(() => _rect = rect);
    }
    // Only once the focus has sat on nothing to press for a moment: pages
    // and sheets build their buttons a frame later, and a page that hands
    // the focus to a button of its choice gets to do so first.
    if (rect != null || widget.holdFocus()) {
      _stuck = null;
    } else if (!identical(node, _stuck)) {
      _stuck = node;
      _stuckSince = elapsed;
    } else if (elapsed - _stuckSince > const Duration(milliseconds: 250)) {
      _stuckSince = elapsed;
      // Traversal needs a node that still sits in the tree.
      if (node != null && node.context != null && node.context!.mounted) {
        node.nextFocus();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final rect = _rect;
    return Stack(
      alignment: Alignment.topLeft,
      children: [
        widget.child,
        if (rect != null)
          Positioned.fromRect(
            rect: rect.inflate(5),
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: GameColors.amber, width: 3),
                  boxShadow: const [
                    BoxShadow(color: Color(0x88FFB300), blurRadius: 14),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
