import 'package:flutter/material.dart';
import 'package:horizont/horizont.dart';

import '../../legal/legal_text.dart';
import '../theme.dart';
import 'panel.dart';
import '../../l10n/l10n.dart';

/// "Impressum · Datenschutz · Lizenzen" along the bottom edge of the welcome
/// and the start page. Each opens its text in a dialog.
class LegalLinks extends StatelessWidget {
  const LegalLinks({super.key});

  @override
  Widget build(BuildContext context) {
    final style = GameType.caption;
    return Center(
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          TextButton(
            onPressed: () => _show(
              context,
              tr('IMPRESSUM', 'LEGAL NOTICE'),
              L10n.current == AppLang.de ? imprint : imprintEn,
            ),
            child: Text(tr('Impressum', 'Legal notice'), style: style),
          ),
          Text('·', style: style),
          TextButton(
            onPressed: () => _show(
              context,
              tr('DATENSCHUTZ', 'PRIVACY POLICY'),
              L10n.current == AppLang.de ? privacy : privacyEn,
            ),
            child: Text(tr('Datenschutz', 'Privacy'), style: style),
          ),
          Text('·', style: style),
          TextButton(
            onPressed: () => _show(
              context,
              tr('LIZENZEN', 'LICENCES'),
              L10n.current == AppLang.de ? licenses : licensesEn,
              action: (
                tr(
                  'Lizenztexte der Komponenten',
                  'Licence texts of components',
                ),
                () => _showComponentLicenses(context),
              ),
            ),
            child: Text(tr('Lizenzen', 'Licences'), style: style),
          ),
        ],
      ),
    );
  }

  /// Flutter collects the licences of all packages and the engine by itself,
  /// but not of the fonts and symbols Horizont bundles, whose OFL 1.1 and
  /// Apache 2.0 ask to pass them on too. Registering twice does nothing.
  static void _showComponentLicenses(BuildContext context) {
    registerHorizontLicenses();
    showLicensePage(
      context: context,
      applicationName: 'Panzergefecht',
      applicationLegalese: '© 2026 Daniel Bocksteger',
    );
  }

  static void _show(
    BuildContext context,
    String title,
    List<LegalBlock> text, {
    (String, VoidCallback)? action,
  }) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(HzSpace.s16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680, maxHeight: 720),
          child: Panel(
            padding: const EdgeInsets.fromLTRB(
              HzSpace.s24,
              HzSpace.s16,
              HzSpace.s12,
              HzSpace.s12,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(title, style: GameType.title)),
                    IconButton(
                      tooltip: tr('Schließen', 'Close'),
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_outlined),
                    ),
                  ],
                ),
                const SizedBox(height: HzSpace.s8),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(right: HzSpace.s8),
                    child: SelectionArea(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final block in text) ...[
                            if (block.heading != null)
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: HzSpace.s16,
                                  bottom: HzSpace.s4,
                                ),
                                child: Kennung(block.heading!),
                              ),
                            // Long text to read: Literata.
                            Text(block.body, style: GameType.reading),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                if (action != null)
                  Padding(
                    padding: const EdgeInsets.only(top: HzSpace.s8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: action.$2,
                        icon: const Icon(Icons.description_outlined),
                        label: Text(action.$1),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
