import 'package:flutter/widgets.dart';

import '../../l10n/l10n.dart';

/// Builds everything below it anew when the language changes. Texts come
/// from `tr` at build time, so a widget that is not rebuilt keeps the old
/// language: const widgets such as the legal links or the sound button, and
/// the overlays of the game and the pages under the one on top, which
/// nothing else rebuilds. Their state stays, only the texts change.
class LanguageRebuild extends StatefulWidget {
  const LanguageRebuild({required this.child, super.key});

  final Widget child;

  @override
  State<LanguageRebuild> createState() => _LanguageRebuildState();
}

class _LanguageRebuildState extends State<LanguageRebuild> {
  @override
  void initState() {
    super.initState();
    L10n.lang.addListener(_changed);
  }

  @override
  void dispose() {
    L10n.lang.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (!mounted) {
      return;
    }
    void mark(Element element) {
      element
        ..markNeedsBuild()
        ..visitChildren(mark);
    }

    (context as Element).visitChildren(mark);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
