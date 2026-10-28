import 'package:flutter/material.dart';
import 'package:horizont/horizont.dart';

import '../db/account_service.dart';
import '../game/tank_game.dart';
import 'theme.dart';
import 'widgets/account_panel.dart';
import 'widgets/legal.dart';
import 'widgets/mute_button.dart';
import 'widgets/tutorial_button.dart';
import 'widgets/panel.dart';
import '../l10n/l10n.dart';
import 'widgets/language_button.dart';

/// Only after a mail link failed to sign in here: explains why, takes the
/// code from the mail, or lets the player go on as a guest. Everybody else
/// starts on the start page and signs in from its account button.
class WelcomeView extends StatelessWidget {
  const WelcomeView({required this.game, super.key});

  final TankGame game;

  @override
  Widget build(BuildContext context) {
    final account = _Box(
      icon: HorizontSymbols.verifiedUser,
      title: tr('MIT KONTO', 'WITH ACCOUNT'),
      kicker: tr('FORTSCHRITT AUF JEDEM GERÄT', 'PROGRESS ON EVERY DEVICE'),
      child: AccountPanel(
        accounts: game.accounts,
        embedded: true,
        onCallSign: game.claimCallSign,
        callSign: game.myName,
      ),
    );
    // Side by side the guest box is as tall as the account box, and its
    // button sits on the same line as the account's.
    Widget guest({bool stretched = false}) => _Box(
      icon: HorizontSymbols.person,
      title: tr('ALS GAST', 'AS GUEST'),
      kicker: tr('OHNE KONTO SPIELEN', 'PLAY WITHOUT AN ACCOUNT'),
      stretched: stretched,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: HzSpace.s12),
          Text(
            tr(
              'Sofort los, ohne E-Mail, aber ohne Wertung: EP, Rang, '
                  'Abzeichen und neue Fahrzeuge gibt es nur mit Konto. Im '
                  'Warteraum kannst du jederzeit eins anlegen.',
              'Jump right in, no e-mail, but no ranking: XP, rank, badges '
                  'and new vehicles need an account. You can create one in '
                  'the waiting room at any time.',
            ),
            style: GameType.callout,
          ),
          if (stretched) const Spacer(),
          const SizedBox(height: HzSpace.s16),
          FilledButton.icon(
            onPressed: game.playAsGuest,
            icon: const Icon(HorizontSymbols.chevronRight),
            label: Text(tr('ALS GAST SPIELEN', 'PLAY AS GUEST')),
          ),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  'PANZERGEFECHT',
                  maxLines: 1,
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
              ),
            ),
            const LanguageButton(),
            const MuteButton(),
          ],
        ),
        const SizedBox(height: HzSpace.s4),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: HzSpace.s12,
          children: [
            Text(
              tr('Willkommen, Panzerkommandant.', 'Welcome, tank commander.'),
              style: GameType.body.copyWith(color: GameColors.textMuted),
            ),
            TutorialButton(game: game),
          ],
        ),
        if (AccountService.mailLinkFailed) ...[
          const SizedBox(height: HzSpace.s16),
          _Notice(
            tr(
              'Der Link aus der Mail ließ sich in diesem Tab nicht abschließen. '
                  'Hast du dich gerade registriert, ist deine Adresse trotzdem '
                  'bestätigt: Wechsle zurück in den Tab, in dem du die Mail '
                  'angefordert hast, dort geht es von selbst weiter. Sonst melde '
                  'dich hier an und gib den Code aus der Mail ein.',
              'The link from the e-mail could not be completed in this tab. '
                  'If you just registered, your address is confirmed anyway: '
                  'switch back to the tab where you requested the e-mail and '
                  'it will carry on by itself. Otherwise sign in here and '
                  'enter the code from the e-mail.',
            ),
          ),
        ],
        const SizedBox(height: HzSpace.s24),
        LayoutBuilder(
          builder: (context, box) => box.maxWidth >= 640
              // Both boxes as tall as the taller one.
              ? IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(flex: 3, child: account),
                      const SizedBox(width: HzSpace.s12),
                      Expanded(flex: 2, child: guest(stretched: true)),
                    ],
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    account,
                    const SizedBox(height: HzSpace.s12),
                    guest(),
                  ],
                ),
        ),
        const SizedBox(height: HzSpace.s12),
        const LegalLinks(),
      ],
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return HorizontNotice(HorizontStatus.info, child: Text(text));
  }
}

class _Box extends StatelessWidget {
  const _Box({
    required this.icon,
    required this.title,
    required this.kicker,
    required this.child,
    this.stretched = false,
  });

  final IconData icon;
  final String title;
  final String kicker;
  final Widget child;

  /// Fills the height it is given, the child takes what is left.
  final bool stretched;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: GameColors.surface,
        shape: GameShapes.card(),
      ),
      child: Padding(
        padding: const EdgeInsets.all(HzSpace.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: GameColors.text, size: 28),
            const SizedBox(height: HzSpace.s12),
            Text(title, style: GameType.title),
            const SizedBox(height: HzSpace.s4),
            Kennung(kicker),
            if (stretched) Expanded(child: child) else child,
          ],
        ),
      ),
    );
  }
}
