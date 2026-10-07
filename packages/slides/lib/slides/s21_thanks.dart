import 'package:flutter/widgets.dart';
import 'package:flutter_deck/flutter_deck.dart';

import '../widgets/repo_qr_card.dart';

class ThanksSlide extends FlutterDeckSlideWidget {
  const ThanksSlide()
    : super(
        configuration: const FlutterDeckSlideConfiguration(
          route: '/thanks',
          title: 'Thanks',
          speakerNotes:
              '- Share the repository link\n'
              '- Point at flame-engine.org and supabase.com/docs\n'
              '- Invite everyone to connect on LinkedIn through the QR code\n'
              '- Questions',
        ),
      );

  @override
  Widget build(BuildContext context) {
    return FlutterDeckSlide.custom(
      builder: (context) {
        final theme = FlutterDeckTitleSlideTheme.of(context);
        final configuration = context.flutterDeck.configuration;

        return FlutterDeckSlideBase(
          contentBuilder: (context) => Padding(
            padding: const EdgeInsets.all(64),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Thank you!', style: theme.titleTextStyle),
                const SizedBox(height: 8),
                Text(
                  'github.com/regetskcob/wargame\n'
                  'flame-engine.org\n'
                  'supabase.com',
                  style: theme.subtitleTextStyle,
                ),
                const SizedBox(height: 48),
                const RepoQrCard(
                  label:
                      'Feel free to connect with me on LinkedIn if you have '
                      'further questions',
                  url: 'https://www.linkedin.com/in/spydon',
                  displayUrl: 'linkedin.com/in/spydon',
                  qrSize: 420,
                  textScale: 1.5,
                ),
              ],
            ),
          ),
          footerBuilder: configuration.footer.showFooter
              ? (context) => FlutterDeckFooter.fromConfiguration(
                  configuration: configuration.footer,
                )
              : null,
          headerBuilder: configuration.header.showHeader
              ? (context) => FlutterDeckHeader.fromConfiguration(
                  configuration: configuration.header,
                )
              : null,
        );
      },
    );
  }
}
