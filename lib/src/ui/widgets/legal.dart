import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
    const style = TextStyle(fontSize: 12, color: GameColors.textDim);
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
          const Text('·', style: style),
          TextButton(
            onPressed: () => _show(
              context,
              tr('DATENSCHUTZ', 'PRIVACY POLICY'),
              L10n.current == AppLang.de ? privacy : privacyEn,
            ),
            child: Text(tr('Datenschutz', 'Privacy'), style: style),
          ),
          const Text('·', style: style),
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

  static var _fontRegistered = false;

  /// Flutter collects the licences of all packages and the engine by itself,
  /// but not of the bundled Roboto, which Apache 2.0 asks to pass on too.
  static void _showComponentLicenses(BuildContext context) {
    if (!_fontRegistered) {
      _fontRegistered = true;
      LicenseRegistry.addLicense(() async* {
        final text = await rootBundle.loadString(
          'assets/fonts/Roboto_LICENSE.txt',
        );
        yield LicenseEntryWithLineBreaks(
          const ['Roboto'],
          'Roboto, Copyright 2011 Google Inc. Cut down to Latin letters for this game.\n\n$text',
        );
      });
    }
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
        insetPadding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680, maxHeight: 720),
          child: Panel(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      tooltip: tr('Schließen', 'Close'),
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(right: 8),
                    child: SelectionArea(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final block in text) ...[
                            if (block.heading != null)
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: 14,
                                  bottom: 4,
                                ),
                                child: Text(
                                  block.heading!,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: GameColors.sand,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ),
                            Text(
                              block.body,
                              style: const TextStyle(
                                fontSize: 14,
                                height: 1.45,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                if (action != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
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
