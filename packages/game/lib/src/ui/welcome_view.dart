import 'package:flutter/material.dart';

import '../db/account_service.dart';
import '../game/space_game.dart';
import '../theme.dart';
import 'widgets/account_panel.dart';
import 'widgets/legal.dart';
import 'widgets/mute_button.dart';
import 'widgets/tutorial_button.dart';
import 'widgets/panel.dart';
import '../l10n/l10n.dart';
import 'widgets/language_button.dart';

/// First page when accounts are switched on: sign in or create an account,
/// or play on as a guest. Players who are signed in never see it.
class WelcomeView extends StatelessWidget {
  const WelcomeView({required this.game, super.key});

  final SpaceGame game;

  @override
  Widget build(BuildContext context) {
    final account = _Box(
      icon: Icons.verified_user,
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
      icon: Icons.person_outline,
      title: tr('ALS GAST', 'AS GUEST'),
      kicker: tr('OHNE KONTO SPIELEN', 'PLAY WITHOUT AN ACCOUNT'),
      stretched: stretched,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 14),
          Text(
            tr(
              'Sofort los, ohne E-Mail, aber ohne Wertung: EP, Rang, '
                  'Abzeichen und neue Fahrzeuge gibt es nur mit Konto. Im '
                  'Warteraum kannst du jederzeit eins anlegen.',
              'Jump right in, no email, but no ranking: XP, rank, badges '
                  'and new vehicles need an account. You can create one in '
                  'the waiting room at any time.',
            ),
            style: const TextStyle(
              color: BwColors.text,
              fontSize: 14,
              height: 1.35,
            ),
          ),
          if (stretched) const Spacer(),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: game.playAsGuest,
            icon: const Icon(Icons.chevron_right),
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
        const SizedBox(height: 4),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          children: [
            Text(
              tr('Willkommen, Panzerkommandant.', 'Welcome, tank commander.'),
              style: const TextStyle(color: BwColors.textDim),
            ),
            TutorialButton(game: game),
          ],
        ),
        if (AccountService.mailLinkFailed) ...[
          const SizedBox(height: 16),
          _Notice(
            tr(
              'Der Link aus der Mail ließ sich in diesem Tab nicht abschließen. '
                  'Hast du dich gerade registriert, ist deine Adresse trotzdem '
                  'bestätigt: Wechsle zurück in den Tab, in dem du die Mail '
                  'angefordert hast, dort geht es von selbst weiter. Sonst melde '
                  'dich hier an und gib den Code aus der Mail ein.',
              'The link from the email could not be completed in this tab. '
                  'If you just registered, your address is confirmed anyway: '
                  'switch back to the tab where you requested the email and '
                  'it will carry on by itself. Otherwise sign in here and '
                  'enter the code from the email.',
            ),
          ),
        ],
        const SizedBox(height: 20),
        LayoutBuilder(
          builder: (context, box) => box.maxWidth >= 640
              // Both boxes as tall as the taller one.
              ? IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(flex: 3, child: account),
                      const SizedBox(width: 12),
                      Expanded(flex: 2, child: guest(stretched: true)),
                    ],
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [account, const SizedBox(height: 12), guest()],
                ),
        ),
        const SizedBox(height: 12),
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
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: const Color(0x33FFB300),
        shape: BwShapes.card(edge: BwColors.amber),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline, color: BwColors.amber),
            const SizedBox(width: 10),
            Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
          ],
        ),
      ),
    );
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
        color: const Color(0x44000000),
        shape: BwShapes.card(),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: BwColors.amber, size: 32),
            const SizedBox(height: 10),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
                color: BwColors.sand,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              kicker,
              style: const TextStyle(
                color: BwColors.amber,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
              ),
            ),
            if (stretched) Expanded(child: child) else child,
          ],
        ),
      ),
    );
  }
}
