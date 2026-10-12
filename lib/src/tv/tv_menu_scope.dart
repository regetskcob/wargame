import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'tv_input.dart';

/// Holds the remote inside a menu of a running round on a television, as
/// long as [open] says it is open: the focus goes to its first button, the
/// swipes walk its buttons and come round at the end instead of leaving it,
/// and play/pause presses the button in focus, as the click does.
///
/// In a round the game keeps the focus for the tank (see `TvFocusFrame`);
/// the Menu button opens the round menu and hands it over here.
class TvMenuScope extends StatefulWidget {
  const TvMenuScope({required this.open, required this.child, super.key});

  final ValueListenable<bool> open;
  final Widget child;

  @override
  State<TvMenuScope> createState() => _TvMenuScopeState();
}

class _TvMenuScopeState extends State<TvMenuScope> {
  final _scope = FocusScopeNode(debugLabel: 'round menu');

  @override
  void initState() {
    super.initState();
    widget.open.addListener(_changed);
    _changed();
  }

  @override
  void didUpdateWidget(TvMenuScope old) {
    super.didUpdateWidget(old);
    if (old.open != widget.open) {
      old.open.removeListener(_changed);
      widget.open.addListener(_changed);
    }
  }

  @override
  void dispose() {
    widget.open.removeListener(_changed);
    _scope.dispose();
    super.dispose();
  }

  void _changed() {
    if (!onTv || !widget.open.value) {
      return;
    }
    // Once the menu's buttons are built: the first of them.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.open.value || _scope.hasFocus) {
        return;
      }
      _scope.requestFocus();
      _scope.nextFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!onTv) {
      return widget.child;
    }
    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.mediaPlayPause): ActivateIntent(),
      },
      child: FocusScope(node: _scope, child: widget.child),
    );
  }
}
