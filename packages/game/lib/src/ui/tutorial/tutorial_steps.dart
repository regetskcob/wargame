import 'package:flutter/material.dart';

import '../../game/components/power_up.dart';
import '../../game/components/tank_painter.dart';
import '../../game/defense/tower.dart';
import '../../game_config.dart';
import '../../theme.dart';

/// What the stage behind a tutorial card acts out.
enum DemoScene {
  drive,
  aim,
  fire,
  assist,
  inventory,
  special,
  defense,

  /// Only the ground, the card brings a row of chips.
  tour,

  /// The vehicles side by side.
  vehicles,

  /// The tank on parade at the end.
  ready,
}

/// A symbol with a word, shown in the quick tour.
class TutorialChip {
  const TutorialChip(this.icon, this.label, [this.color = BwColors.amber]);

  final IconData icon;
  final String label;
  final Color color;
}

/// One card of the tutorial.
class TutorialStep {
  const TutorialStep({
    required this.title,
    required this.text,
    required this.icon,
    this.scene = DemoScene.tour,
    this.chips = const [],
  });

  final String title;
  final String text;
  final IconData icon;
  final DemoScene scene;
  final List<TutorialChip> chips;

  /// Steps of the quick tour play on by themselves.
  bool get quick => scene == DemoScene.tour || scene == DemoScene.vehicles;
}

/// The controls for [touch] or for keyboard and mouse, then the quick tour
/// through everything the game has, and a last card to start.
List<TutorialStep> tutorialSteps({required bool touch}) => [
  ...touch ? _touch : _desktop,
  ..._tour,
  _ready,
];

/// How many of the steps for [touch] explain the controls.
int controlSteps({required bool touch}) => (touch ? _touch : _desktop).length;

const _touch = [
  TutorialStep(
    title: 'FAHREN',
    icon: Icons.open_with,
    scene: DemoScene.drive,
    text:
        'Setz den linken Daumen irgendwo unten links auf, dort erscheint der '
        'Stick. Schieb ihn dorthin, wohin der Panzer soll: Er dreht sich von '
        'selbst und fährt los.',
  ),
  TutorialStep(
    title: 'ZIELEN',
    icon: Icons.track_changes,
    scene: DemoScene.aim,
    text:
        'Der rechte Daumen richtet den Turm aus, ganz gleich, wohin der '
        'Panzer fährt. Innerhalb des Rings wird nur gezielt.',
  ),
  TutorialStep(
    title: 'FEUERN',
    icon: Icons.local_fire_department,
    scene: DemoScene.fire,
    text:
        'Schieb den rechten Stick über den Ring hinaus, dann feuert der '
        'Panzer, solange du ihn dort hältst. Die Munition ist begrenzt, '
        'blaue Gems füllen sie auf.',
  ),
  TutorialStep(
    title: 'ZIELHILFE',
    icon: Icons.gps_fixed,
    scene: DemoScene.assist,
    text:
        'Ruht der rechte Daumen, dreht die Zielhilfe den Turm auf den '
        'nächsten Gegner in Reichweite und feuert. Der Knopf ZIELHILFE über '
        'dem Stick schaltet sie aus und wieder an.',
  ),
  TutorialStep(
    title: 'INVENTAR',
    icon: Icons.inventory_2,
    scene: DemoScene.inventory,
    text:
        'Fahr über Kisten und Gems, sie landen im Inventar am linken Rand. '
        'Ein Tipp auf das Feld setzt sie ein, hier einen Schild.',
  ),
  TutorialStep(
    title: 'SPEZIALWAFFE',
    icon: Icons.sports_baseball,
    scene: DemoScene.special,
    text:
        'Granatwerfer, Mörser und Drohne aus Gems bekommen einen runden Knopf '
        'über dem rechten Stick. Ein Druck feuert, die Zahl zeigt, wie oft '
        'noch.',
  ),
  TutorialStep(
    title: 'VERTEIDIGUNG',
    icon: Icons.shield,
    scene: DemoScene.defense,
    text:
        'Im Modus Verteidigung bringen Abschüsse Geld. Ein Tipp auf ein '
        'Geschütz baut es neben deinem Panzer, steht er an einem Geschütz, '
        'rüstest du es dort auf.',
  ),
];

const _desktop = [
  TutorialStep(
    title: 'FAHREN',
    icon: Icons.keyboard,
    scene: DemoScene.drive,
    text:
        'W fährt vorwärts, S bremst und setzt zurück, A und D lenken. Die '
        'Pfeiltasten tun dasselbe.',
  ),
  TutorialStep(
    title: 'ZIELEN',
    icon: Icons.mouse,
    scene: DemoScene.aim,
    text:
        'Der Turm folgt der Maus, ganz gleich, wohin der Panzer fährt. Ohne '
        'Maus drehen Q und E den Turm.',
  ),
  TutorialStep(
    title: 'FEUERN',
    icon: Icons.local_fire_department,
    scene: DemoScene.fire,
    text:
        'Linksklick oder Leertaste feuert, gedrückt halten heißt Dauerfeuer. '
        'Die Munition ist begrenzt, blaue Gems füllen sie auf.',
  ),
  TutorialStep(
    title: 'INVENTAR',
    icon: Icons.inventory_2,
    scene: DemoScene.inventory,
    text:
        'Fahr über Kisten und Gems, sie landen im Inventar am linken Rand. '
        'Die Tasten 1 bis 6 oder ein Klick auf das Feld setzen sie ein, hier '
        'einen Schild.',
  ),
  TutorialStep(
    title: 'SPEZIALWAFFE',
    icon: Icons.sports_baseball,
    scene: DemoScene.special,
    text:
        'Granatwerfer, Mörser und Drohne aus Gems löst du mit F aus. Granaten '
        'und Mörser fliegen über Mauern hinweg dorthin, wo die Maus steht.',
  ),
  TutorialStep(
    title: 'VERTEIDIGUNG',
    icon: Icons.shield,
    scene: DemoScene.defense,
    text:
        'Im Modus Verteidigung bringen Abschüsse Geld. B baut ein Geschütz '
        'neben deinem Panzer, V wechselt den Typ.',
  ),
];

final _tour = [
  const TutorialStep(
    title: 'DREI WEGE ZU SPIELEN',
    icon: Icons.flag,
    text:
        'Allein gegen CPU-Panzer, mit anderen per Link, Code oder Raumliste, '
        'oder gemeinsam gegen ${GameConfig.defenseWaves} Wellen.',
    chips: [
      TutorialChip(Icons.person, 'EINZELSPIELER'),
      TutorialChip(Icons.groups, 'MEHRSPIELER'),
      TutorialChip(Icons.compare_arrows, 'ROT GEGEN BLAU'),
      TutorialChip(Icons.shield, 'VERTEIDIGUNG'),
    ],
  ),
  TutorialStep(
    title: '${_count(TankType.values.length)} FAHRZEUGE',
    icon: Icons.directions_car,
    scene: DemoScene.vehicles,
    text:
        'Jedes mit eigener Panzerung, Tempo und Kanone. Weitere Fahrzeuge '
        'und Tarnfarben kommen mit höheren Rängen.',
  ),
  TutorialStep(
    title: 'KISTEN',
    icon: Icons.all_inbox,
    text: 'Im Feld liegen Kisten mit Hilfe für den Notfall.',
    chips: [
      for (final type in PowerUpType.values.where((t) => !t.gem))
        TutorialChip(type.icon, type.label, type.color),
    ],
  ),
  TutorialStep(
    title: 'GEMS',
    icon: Icons.diamond,
    text:
        'Gems bringen Munition, Treibstoff und Spezialwaffen, bis hin zu '
        'Fallschirmjägern mit Panzerfäusten.',
    chips: [
      for (final type in PowerUpType.values.where((t) => t.gem))
        TutorialChip(type.icon, type.label, type.color),
    ],
  ),
  const TutorialStep(
    title: 'GELÄNDE UND WETTER',
    icon: Icons.terrain,
    text:
        'Vier Gelände bei Tag oder Nacht, mit Regen, Schnee, Sandsturm oder '
        'Nebel, die die Sicht begrenzen. Häuser, Sperren und Bäume lassen '
        'sich zerschießen.',
    chips: [
      TutorialChip(Icons.park, 'ÜBUNGSPLATZ'),
      TutorialChip(Icons.wb_sunny, 'WÜSTE'),
      TutorialChip(Icons.ac_unit, 'WINTER'),
      TutorialChip(Icons.location_city, 'STADT'),
      TutorialChip(Icons.water_drop, 'REGEN'),
      TutorialChip(Icons.blur_on, 'NEBEL'),
      TutorialChip(Icons.nightlight_round, 'NACHT'),
    ],
  ),
  const TutorialStep(
    title: 'DREI STUFEN',
    icon: Icons.signal_cellular_alt,
    text:
        'Leicht: flaches Land, Treibstoff und Munition gehen nie aus. '
        'Normal: Hügel und Nachschub, der gesucht werden muss. Schwer: '
        'steile Hügel und Luftschläge.',
    chips: [
      TutorialChip(Icons.signal_cellular_alt_1_bar, 'LEICHT'),
      TutorialChip(Icons.signal_cellular_alt_2_bar, 'NORMAL'),
      TutorialChip(Icons.signal_cellular_alt, 'SCHWER', BwColors.danger),
    ],
  ),
  TutorialStep(
    title: 'STÜTZPUNKT HALTEN',
    icon: Icons.fort,
    text:
        'Geschütze, Gräben und Upgrades für den Panzer. Hält der Stützpunkt '
        'gut, wächst er vom Wachturm zur Festung und schickt eigene '
        'Hubschrauber und Jets.',
    chips: [
      for (final kind in TowerKind.values)
        TutorialChip(_towerIcon(kind), kind.label),
      const TutorialChip(Icons.upgrade, 'UPGRADES'),
    ],
  ),
  const TutorialStep(
    title: 'NACH DER RUNDE',
    icon: Icons.emoji_events,
    text:
        'Revanche auf Knopfdruck, die letzte Runde als Wiederholung, dazu '
        'Ränge, Wertung, Abzeichen und Bestenlisten.',
    chips: [
      TutorialChip(Icons.replay, 'REVANCHE'),
      TutorialChip(Icons.movie_outlined, 'WIEDERHOLUNG'),
      TutorialChip(Icons.military_tech, 'RÄNGE'),
      TutorialChip(Icons.workspace_premium, 'ABZEICHEN'),
      TutorialChip(Icons.leaderboard, 'BESTENLISTE'),
    ],
  ),
];

const _ready = TutorialStep(
  title: 'BEREIT, KOMMANDANT',
  icon: Icons.military_tech,
  scene: DemoScene.ready,
  text:
      'Das war die Einweisung. Du findest sie jederzeit wieder auf der '
      'Startseite und im Warteraum.',
);

IconData _towerIcon(TowerKind kind) => switch (kind) {
  TowerKind.cannon => Icons.adjust,
  TowerKind.flak => Icons.flight,
  TowerKind.mortar => Icons.vertical_align_top,
  TowerKind.howitzer => Icons.gps_fixed,
  TowerKind.trench => Icons.horizontal_rule,
};

/// Small numbers spelled out, as on the cards.
String _count(int n) => switch (n) {
  7 => 'SIEBEN',
  8 => 'ACHT',
  9 => 'NEUN',
  10 => 'ZEHN',
  _ => '$n',
};
