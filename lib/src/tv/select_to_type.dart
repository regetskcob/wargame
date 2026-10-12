import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'tv_input.dart';

/// Builds a text field that on a television asks for the keyboard only once
/// it is selected, not as soon as the focus passes over it.
///
/// A focused text field opens its text input connection at once. On the
/// Apple TV the engine then puts a native stand-in for the keyboard in front
/// of the remote, which swallows the end of the swipe that brought the focus
/// there: the engine's key repeat never hears the remote let go and keeps
/// sending "down" every 80 ms, and the focus ran round and round the account
/// page. Read-only, the field opens no connection; a click (select, which the
/// engine sends as enter) makes it writable and brings the keyboard up.
/// Elsewhere the field is built as it is.
class SelectToType extends StatefulWidget {
  const SelectToType({required this.builder, super.key});

  /// Builds the field with the focus node and read-only flag to pass on.
  final Widget Function(FocusNode focusNode, bool readOnly) builder;

  @override
  State<SelectToType> createState() => _SelectToTypeState();
}

class _SelectToTypeState extends State<SelectToType> {
  final _node = FocusNode();
  var _typing = false;

  @override
  void initState() {
    super.initState();
    _node.addListener(_focusChanged);
  }

  @override
  void dispose() {
    _node
      ..removeListener(_focusChanged)
      ..dispose();
    super.dispose();
  }

  void _focusChanged() {
    if (_node.hasFocus || !_typing) {
      return;
    }
    setState(() => _typing = false);
    // Closing the keyboard drops the focus to the page, and the focus frame
    // would carry it on to the next button. Back to the field instead, so
    // the remote goes on from where the typing was; not when the focus went
    // somewhere on purpose or the page is leaving.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final now = FocusManager.instance.primaryFocus;
      final route = mounted ? ModalRoute.of(context) : null;
      if (mounted &&
          (route == null || route.isCurrent) &&
          (now == null || now is FocusScopeNode)) {
        _node.requestFocus();
      }
    });
  }

  KeyEventResult _key(FocusNode _, KeyEvent event) {
    final select =
        event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.select;
    if (_typing || !select) {
      return KeyEventResult.ignored;
    }
    // Down opens the keyboard, up must not reach the button behind it.
    if (event is KeyDownEvent) {
      setState(() => _typing = true);
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    if (!onTv) {
      return widget.builder(_node, false);
    }
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: _key,
      child: widget.builder(_node, !_typing),
    );
  }
}
