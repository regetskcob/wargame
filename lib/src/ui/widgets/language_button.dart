import 'package:flutter/material.dart';
import 'package:horizont/horizont.dart';

import '../../l10n/l10n.dart';
import '../theme.dart';

/// Switches between the languages of the game. Shows the one in use.
class LanguageButton extends StatelessWidget {
  const LanguageButton({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLang>(
      valueListenable: L10n.lang,
      builder: (context, lang, _) {
        final next = AppLang.values[(lang.index + 1) % AppLang.values.length];
        return Tooltip(
          message: next.label,
          child: TextButton.icon(
            onPressed: () => L10n.set(next),
            icon: const Icon(Icons.language_outlined, size: HzIconSize.bar),
            label: Text(
              lang.code,
              style: GameType.data.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        );
      },
    );
  }
}
