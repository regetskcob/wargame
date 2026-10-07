import 'package:flutter/widgets.dart';
import 'package:flutter_deck/flutter_deck.dart';

import '../widgets/code_pane.dart';
import '../widgets/side_bullets.dart';

class GameNetcodeSlide extends FlutterDeckSlideWidget {
  const GameNetcodeSlide()
    : super(
        configuration: const FlutterDeckSlideConfiguration(
          route: '/game-netcode',
          title: 'The netcode of the reference game',
          speakerNotes:
              '- Every event is a Broadcast message on one channel per '
              'room, nothing about it is stored\n'
              '- state is the only one that flows all the time: 20 packets '
              'per second, and each client smooths the others over the gaps\n'
              '- shoot, hit and death are rare events, the victim applies '
              'its own damage and reports the result\n'
              '- obstacle and soldier tell the others what changed in the '
              'shared world: the terrain itself costs nothing, it is '
              'generated from the round seed\n'
              '- Presence is the lobby: name, vehicle, team, and a seed once '
              'a match runs so late joiners can watch\n'
              '- CPU opponents are simulated by the client that started the '
              'round and talk through the same events as a human player',
        ),
      );

  @override
  Widget build(BuildContext context) {
    return FlutterDeckSlide.split(
      leftBuilder: (context) => const SideBullets(
        items: [
          'One Realtime channel per room, one Broadcast event per kind',
          'Every client simulates its own tank, nobody owns the world',
          'The terrain comes from one shared seed and costs no bandwidth',
          'Presence is the lobby: name, vehicle, team',
        ],
      ),
      rightBuilder: (context) => const CodePane(
        fileName: 'packages/game/lib/src/net/net_events.dart',
        code: '''
enum NetEvent {
  state,      // position, turret, health: 20 per second
  shoot,      // a shell leaves a barrel
  hit,        // the victim reports its new health
  death,      // who died, and who shot
  roundStart, // seed, start time, teams, CPU opponents
  pickup,     // a power-up was taken
  smoke,      // a smoke screen went up
  obstacle,   // a building or barrier took damage
  soldier,    // a soldier was run over
}''',
      ),
    );
  }
}
