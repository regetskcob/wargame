import 'package:flutter/material.dart';

import '../game/space_game.dart';
import '../theme.dart';
import 'widgets/account_panel.dart';
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
      title: 'ANMELDEN',
      kicker: 'ODER REGISTRIEREN',
      child: AccountPanel(accounts: game.accounts, embedded: true),
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
            'Browser. Im Warteraum kannst du dein Gastkonto jederzeit '
            'sichern.',
            style: TextStyle(color: BwColors.textDim, fontSize: 12),
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
        const SizedBox(height: 20),
        LayoutBuilder(
          builder: (context, box) => box.maxWidth >= 640
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: account),
                    const SizedBox(width: 12),
                    Expanded(flex: 2, child: guest),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [account, const SizedBox(height: 12), guest],
                ),
        ),
      ],
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
                fontSize: 11,
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
