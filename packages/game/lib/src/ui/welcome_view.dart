import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../db/account_service.dart';
import '../game/space_game.dart';
import '../theme.dart';
import 'widgets/account_panel.dart';
import 'widgets/legal.dart';
import 'widgets/mute_button.dart';

/// First page when accounts are switched on: sign in or create an account,
/// or play on as a guest. Players who are signed in never see it.
class WelcomeView extends StatelessWidget {
  const WelcomeView({required this.game, super.key});

  final SpaceGame game;

  @override
  Widget build(BuildContext context) {
    final account = _Box(
      icon: Icons.verified_user,
      title: 'MIT KONTO',
      kicker: 'FORTSCHRITT AUF JEDEM GERÄT',
      child: AccountPanel(
        accounts: game.accounts,
        embedded: true,
        onCallSign: game.claimCallSign,
        callSign: game.myName,
      ),
    );
    final guest = _Box(
      icon: Icons.person_outline,
      title: 'ALS GAST',
      kicker: 'OHNE KONTO SPIELEN',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 6),
          const Text(
            'Sofort los, ohne E-Mail. Dein Fortschritt hängt an diesem '
            '${kIsWeb ? 'Browser' : 'Gerät'}. Im Warteraum kannst du dein Gastkonto jederzeit '
            'sichern.',
            style: TextStyle(color: BwColors.text, fontSize: 14, height: 1.35),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: game.playAsGuest,
            icon: const Icon(Icons.chevron_right),
            label: const Text('ALS GAST SPIELEN'),
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
            const MuteButton(),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Willkommen, Panzerkommandant.',
          style: TextStyle(color: BwColors.textDim),
        ),
        if (AccountService.mailLinkFailed) ...[
          const SizedBox(height: 16),
          const _Notice(
            'Der Link aus der Mail ließ sich in diesem Tab nicht abschließen. '
            'Hast du dich gerade registriert, ist deine Adresse trotzdem '
            'bestätigt: Wechsle zurück in den Tab, in dem du die Mail '
            'angefordert hast, dort geht es von selbst weiter. Sonst melde '
            'dich hier an und gib den Code aus der Mail ein.',
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
                      Expanded(flex: 2, child: guest),
                    ],
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [account, const SizedBox(height: 12), guest],
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
      decoration: BoxDecoration(
        color: const Color(0x33FFB300),
        border: Border.all(color: BwColors.amber),
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
  });

  final IconData icon;
  final String title;
  final String kicker;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: const Color(0x44000000),
        shape: BeveledRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: BwColors.oliveLight, width: 1.5),
        ),
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
            child,
          ],
        ),
      ),
    );
  }
}
