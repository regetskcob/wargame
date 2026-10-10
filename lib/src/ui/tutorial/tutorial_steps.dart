import 'package:flutter/material.dart';

import '../../game/bot_level.dart';
import '../../game/components/power_up.dart';
import '../../game/components/supply_depot.dart';
import '../../game/components/tank_painter.dart';
import '../../game/defense/tower.dart';
import '../../game/map_theme.dart';
import '../../game/game_config.dart';
import '../../l10n/l10n.dart';
import '../../tv/tv_input.dart';
import '../../vision/vision_support.dart';
import '../theme.dart';

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
  const TutorialChip(this.icon, this.label, [this.color = GameColors.amber]);

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

/// The controls for [touch] or for keyboard and mouse, on the Apple TV for
/// controller and remote, then the quick tour through everything the game
/// has, and a last card to start.
List<TutorialStep> tutorialSteps({required bool touch}) => [
  ..._controls(touch),
  ..._tour,
  _ready,
];

/// How many of the steps for [touch] explain the controls.
int controlSteps({required bool touch}) => _controls(touch).length;

List<TutorialStep> _controls(bool touch) => !onTv
    ? (touch ? (onVision ? _vision : _touch) : _desktop)
    : tvPadForTutorial == TvPadKind.gamepad
    ? _gamepad
    : _remote;

/// What the Apple TV explains: the controller in hand, else the remote.
TvPadKind get tvPadForTutorial =>
    TvInput.instance.kind.value == TvPadKind.gamepad
    ? TvPadKind.gamepad
    : TvPadKind.remote;

List<TutorialStep> get _gamepad => [
  TutorialStep(
    title: tr('FAHREN', 'DRIVE'),
    icon: Icons.sports_esports_outlined,
    scene: DemoScene.drive,
    text: tr(
      'Der linke Stick zeigt, wohin der Panzer soll: Er dreht sich von selbst '
          'und fährt los.',
      'The left stick points where the tank should go: it turns by itself '
          'and drives off.',
    ),
  ),
  TutorialStep(
    title: tr('ZIELEN', 'AIM'),
    icon: Icons.track_changes_outlined,
    scene: DemoScene.aim,
    text: tr(
      'Der rechte Stick richtet den Turm aus, ganz gleich, wohin der Panzer '
          'fährt. Lässt du ihn los, dreht die Zielhilfe den Turm auf den '
          'nächsten Gegner. Auf Schwer gibt es keine.',
      'The right stick aims the turret, no matter where the tank is driving. '
          'Let go and the aim assist turns it to the nearest enemy. On Hard '
          'there is none.',
    ),
  ),
  TutorialStep(
    title: tr('FEUERN', 'FIRE'),
    icon: Icons.local_fire_department_outlined,
    scene: DemoScene.fire,
    text: tr(
      'R2 oder A feuert, gedrückt halten heißt Dauerfeuer. Die Munition ist '
          'begrenzt, blaue Gems füllen sie auf.',
      'R2 or A fires, holding it down means continuous fire. Ammunition is '
          'limited, blue gems refill it.',
    ),
  ),
  TutorialStep(
    title: tr('INVENTAR', 'INVENTORY'),
    icon: Icons.inventory_2_outlined,
    scene: DemoScene.inventory,
    text: tr(
      'Kisten und Gems landen im Inventar am linken Rand. X setzt das erste '
          'Feld ein, Y das zweite, das Steuerkreuz die übrigen. Die Taste '
          'steht am Feld.',
      'Crates and gems land in the inventory on the left edge. X uses the '
          'first slot, Y the second, the d-pad the others. The button is on '
          'the slot.',
    ),
  ),
  TutorialStep(
    title: tr('SPEZIALWAFFE', 'SPECIAL WEAPON'),
    icon: Icons.sports_baseball_outlined,
    scene: DemoScene.special,
    text: tr(
      'Granatwerfer, Mörser und Drohne aus Gems feuert L2.',
      'Grenade launcher, mortar and drone from gems fire with L2.',
    ),
  ),
  TutorialStep(
    title: tr('VERTEIDIGUNG', 'DEFENSE'),
    icon: Icons.shield_outlined,
    scene: DemoScene.defense,
    text: tr(
      'Im Modus Verteidigung bringen Abschüsse Geld. R1 baut ein Geschütz '
          'neben deinem Panzer oder rüstet das auf, an dem er steht, L1 '
          'wechselt die Art.',
      'In defense mode kills bring money. R1 builds a turret next to your '
          'tank or upgrades the one it stands at, L1 switches the kind.',
    ),
  ),
];

/// The button of the remote for items and special weapons. Android TV
/// remotes without play/pause, as the Google TV Streamer's, use the menu
/// button (`GamepadPlugin.kt`).
String get _playDe => onAppleTv ? 'Play/Pause' : 'Play/Pause (oder Menü)';
String get _playEn => onAppleTv ? 'play/pause' : 'play/pause (or menu)';

List<TutorialStep> get _remote => [
  TutorialStep(
    title: tr('FAHREN', 'DRIVE'),
    icon: Icons.settings_remote_outlined,
    scene: DemoScene.drive,
    text: onAppleTv
        ? tr(
            'Leg den Daumen auf die Touchfläche der Siri Remote, dorthin, wohin '
                'der Panzer soll: oben fährt er nach oben, rechts nach rechts. '
                'Hebst du ihn ab, hält er an.',
            'Rest your thumb on the touch surface of the Siri Remote where the '
                'tank should go: at the top it drives up, at the right to the '
                'right. Lift it and the tank stops.',
          )
        : tr(
            'Halt das Steuerkreuz der Fernbedienung in die Richtung, in die der '
                'Panzer soll, zwei Tasten zusammen fahren schräg. Lässt du los, '
                'hält er an.',
            'Hold the d-pad of the remote the way the tank should go, two '
                'buttons together drive diagonally. Let go and the tank stops.',
          ),
  ),
  TutorialStep(
    title: tr('ZIELEN', 'AIM'),
    icon: Icons.track_changes_outlined,
    scene: DemoScene.aim,
    text: tr(
      'Mit der Remote zielt die Zielhilfe: Sie dreht den Turm auf den '
          'nächsten Gegner in Reichweite und feuert. Auf Schwer gibt es keine, '
          'dann schaut der Turm nach vorn.',
      'With the remote the aim assist aims: it turns the turret to the '
          'nearest enemy in range and fires. On Hard there is none, then the '
          'turret looks ahead.',
    ),
  ),
  TutorialStep(
    title: tr('FEUERN', 'FIRE'),
    icon: Icons.local_fire_department_outlined,
    scene: DemoScene.fire,
    text: onAppleTv
        ? tr(
            'Ein Klick auf die Touchfläche feuert, gedrückt halten heißt '
                'Dauerfeuer. Die Munition ist begrenzt, blaue Gems füllen sie '
                'auf.',
            'A click on the touch surface fires, holding it down means '
                'continuous fire. Ammunition is limited, blue gems refill it.',
          )
        : tr(
            'OK in der Mitte des Steuerkreuzes feuert, gedrückt halten heißt '
                'Dauerfeuer. Die Munition ist begrenzt, blaue Gems füllen sie '
                'auf.',
            'OK in the middle of the d-pad fires, holding it down means '
                'continuous fire. Ammunition is limited, blue gems refill it.',
          ),
  ),
  TutorialStep(
    title: tr('INVENTAR', 'INVENTORY'),
    icon: Icons.inventory_2_outlined,
    scene: DemoScene.inventory,
    text: tr(
      'Kisten und Gems landen im Inventar am linken Rand. $_playDe setzt '
          'das oberste Feld ein.',
      'Crates and gems land in the inventory on the left edge. $_playEn '
          'uses the top slot.',
    ),
  ),
  TutorialStep(
    title: tr('SPEZIALWAFFE', 'SPECIAL WEAPON'),
    icon: Icons.sports_baseball_outlined,
    scene: DemoScene.special,
    text: tr(
      'Granatwerfer, Mörser und Drohne aus Gems feuert $_playDe. Solange '
          'eine davon geladen ist, geht sie dem Inventar vor.',
      'Grenade launcher, mortar and drone from gems fire with $_playEn. '
          'While one is loaded it comes before the inventory.',
    ),
  ),
  TutorialStep(
    title: tr('VERTEIDIGUNG', 'DEFENSE'),
    icon: Icons.shield_outlined,
    scene: DemoScene.defense,
    text: tr(
      'Im Modus Verteidigung bringen Abschüsse Geld. Ist das Inventar leer, '
          'baut $_playDe ein Geschütz neben deinem Panzer oder rüstet das '
          'auf, an dem er steht. Mehr Auswahl gibt ein Controller.',
      'In defense mode kills bring money. With an empty inventory, '
          '$_playEn builds a turret next to your tank or upgrades the one it '
          'stands at. A controller gives more choice.',
    ),
  ),
];

List<TutorialStep> get _touch => [
  TutorialStep(
    title: tr('FAHREN', 'DRIVE'),
    icon: Icons.open_with_outlined,
    scene: DemoScene.drive,
    text: tr(
      'Setz den linken Daumen irgendwo unten links auf, dort erscheint der '
          'Stick. Schieb ihn dorthin, wohin der Panzer soll: Er dreht sich von '
          'selbst und fährt los.',
      'Put your left thumb anywhere at the bottom left, the stick appears '
          'there. Push it where the tank should go: it turns by itself and '
          'drives off.',
    ),
  ),
  TutorialStep(
    title: tr('ZIELEN', 'AIM'),
    icon: Icons.track_changes_outlined,
    scene: DemoScene.aim,
    text: tr(
      'Der rechte Daumen richtet den Turm aus, ganz gleich, wohin der '
          'Panzer fährt. Innerhalb des Rings wird nur gezielt.',
      'The right thumb aims the turret, no matter where the tank is '
          'driving. Inside the ring you only aim.',
    ),
  ),
  TutorialStep(
    title: tr('FEUERN', 'FIRE'),
    icon: Icons.local_fire_department_outlined,
    scene: DemoScene.fire,
    text: tr(
      'Schieb den rechten Stick über den Ring hinaus, dann feuert der '
          'Panzer, solange du ihn dort hältst. Die Munition ist begrenzt, '
          'blaue Gems füllen sie auf.',
      'Push the right stick past the ring and the tank fires as long as '
          'you hold it there. Ammunition is limited, blue gems refill it.',
    ),
  ),
  TutorialStep(
    title: tr('ZIELHILFE', 'AIM ASSIST'),
    icon: Icons.gps_fixed_outlined,
    scene: DemoScene.assist,
    text: tr(
      'Ruht der rechte Daumen, dreht die Zielhilfe den Turm auf den '
          'nächsten Gegner in Reichweite und feuert. Der Knopf ZIELHILFE über '
          'dem Stick schaltet sie aus und wieder an. Auf Schwer gibt es keine '
          'Zielhilfe.',
      'While the right thumb rests, the aim assist turns the turret to the '
          'nearest enemy in range and fires. The AIM ASSIST button above the '
          'stick switches it off and on again. On Hard there is no aim '
          'assist.',
    ),
  ),
  TutorialStep(
    title: tr('INVENTAR', 'INVENTORY'),
    icon: Icons.inventory_2_outlined,
    scene: DemoScene.inventory,
    text: tr(
      'Fahr über Kisten und Gems, sie landen im Inventar am linken Rand. '
          'Ein Tipp auf das Feld setzt sie ein, hier einen Schild.',
      'Drive over crates and gems, they land in the inventory on the left '
          'edge. A tap on the slot uses them, here a shield.',
    ),
  ),
  TutorialStep(
    title: tr('SPEZIALWAFFE', 'SPECIAL WEAPON'),
    icon: Icons.sports_baseball_outlined,
    scene: DemoScene.special,
    text: tr(
      'Granatwerfer, Mörser und Drohne aus Gems bekommen einen runden Knopf '
          'über dem rechten Stick. Ein Druck feuert, die Zahl zeigt, wie oft '
          'noch.',
      'Grenade launcher, mortar and drone from gems get a round button '
          'above the right stick. A press fires, the number shows how many '
          'shots are left.',
    ),
  ),
  TutorialStep(
    title: tr('VERTEIDIGUNG', 'DEFENSE'),
    icon: Icons.shield_outlined,
    scene: DemoScene.defense,
    text: tr(
      'Im Modus Verteidigung bringen Abschüsse Geld. Ein Tipp auf ein '
          'Geschütz baut es neben deinem Panzer, steht er an einem Geschütz, '
          'rüstest du es dort auf.',
      'In defense mode kills bring money. A tap on a turret builds it next '
          'to your tank, and when it stands at a turret you upgrade that '
          'one.',
    ),
  ),
];

/// Apple Vision Pro: the left hand drives with a pinch and drag, the eyes aim
/// and a pinch fires. Inventory and defense work as on a tablet.
List<TutorialStep> get _vision => [
  TutorialStep(
    title: tr('FAHREN', 'DRIVE'),
    icon: Icons.open_with,
    scene: DemoScene.drive,
    text: tr(
      'Schau unten links ins Fenster, führ Daumen und Zeigefinger zusammen '
          'und zieh die Hand dorthin, wohin der Panzer soll: Er dreht sich '
          'von selbst und fährt los.',
      'Look at the lower left of the window, pinch and move your hand where '
          'the tank should go: it turns by itself and drives off.',
    ),
  ),
  TutorialStep(
    title: tr('ZIELEN', 'AIM'),
    icon: Icons.visibility,
    scene: DemoScene.aim,
    text: tr(
      'Der Turm zielt dorthin, wo du hinsiehst, sobald du die Finger '
          'zusammenführst, ganz gleich, wohin der Panzer fährt.',
      'The turret aims where you look as soon as you pinch, no matter '
          'where the tank is driving.',
    ),
  ),
  TutorialStep(
    title: tr('FEUERN', 'FIRE'),
    icon: Icons.local_fire_department,
    scene: DemoScene.fire,
    text: tr(
      'Solange die Finger zusammenbleiben, feuert der Panzer. Fahren und '
          'Feuern gehen zugleich, mit jeder Hand eins. Die Munition ist '
          'begrenzt, blaue Gems füllen sie auf.',
      'The tank fires as long as you keep the pinch. Driving and firing go '
          'together, one hand each. Ammunition is limited, blue gems refill '
          'it.',
    ),
  ),
  TutorialStep(
    title: tr('ZIELHILFE', 'AIM ASSIST'),
    icon: Icons.gps_fixed,
    scene: DemoScene.assist,
    text: tr(
      'Ohne Pinch dreht die Zielhilfe den Turm auf den nächsten Gegner in '
          'Reichweite und feuert. Der Knopf ZIELHILFE unten rechts schaltet '
          'sie aus und wieder an. Auf Schwer gibt es keine Zielhilfe.',
      'Without a pinch the aim assist turns the turret to the nearest enemy '
          'in range and fires. The AIM ASSIST button at the lower right '
          'switches it off and on again. On Hard there is no aim assist.',
    ),
  ),
  ..._touch.skip(4).take(1),
  TutorialStep(
    title: tr('SPEZIALWAFFE', 'SPECIAL WEAPON'),
    icon: Icons.sports_baseball,
    scene: DemoScene.special,
    text: tr(
      'Granatwerfer, Mörser und Drohne aus Gems bekommen einen runden Knopf '
          'unten rechts. Granaten landen dort, wo du zuletzt hingesehen hast, '
          'die Zahl zeigt, wie oft noch.',
      'Grenade launcher, mortar and drone from gems get a round button at '
          'the lower right. Grenades land where you last looked, the number '
          'shows how many shots are left.',
    ),
  ),
  ..._touch.skip(6),
];

List<TutorialStep> get _desktop => [
  TutorialStep(
    title: tr('FAHREN', 'DRIVE'),
    icon: Icons.keyboard_outlined,
    scene: DemoScene.drive,
    text: tr(
      'W fährt vorwärts, S bremst und setzt zurück, A und D lenken. Die '
          'Pfeiltasten tun dasselbe.',
      'W drives forward, S brakes and reverses, A and D steer. The arrow '
          'keys do the same.',
    ),
  ),
  TutorialStep(
    title: tr('ZIELEN', 'AIM'),
    icon: Icons.mouse_outlined,
    scene: DemoScene.aim,
    text: tr(
      'Der Turm folgt der Maus, ganz gleich, wohin der Panzer fährt. Ohne '
          'Maus drehen Q und E den Turm.',
      'The turret follows the mouse, no matter where the tank is driving. '
          'Without a mouse, Q and E turn the turret.',
    ),
  ),
  TutorialStep(
    title: tr('FEUERN', 'FIRE'),
    icon: Icons.local_fire_department_outlined,
    scene: DemoScene.fire,
    text: tr(
      'Linksklick oder Leertaste feuert, gedrückt halten heißt Dauerfeuer. '
          'Die Munition ist begrenzt, blaue Gems füllen sie auf.',
      'Left click or space fires, holding it down means continuous fire. '
          'Ammunition is limited, blue gems refill it.',
    ),
  ),
  TutorialStep(
    title: tr('INVENTAR', 'INVENTORY'),
    icon: Icons.inventory_2_outlined,
    scene: DemoScene.inventory,
    text: tr(
      'Fahr über Kisten und Gems, sie landen im Inventar am linken Rand. '
          'Die Tasten 1 bis 6 oder ein Klick auf das Feld setzen sie ein, hier '
          'einen Schild.',
      'Drive over crates and gems, they land in the inventory on the left '
          'edge. The keys 1 to 6 or a click on the slot use them, here a '
          'shield.',
    ),
  ),
  TutorialStep(
    title: tr('SPEZIALWAFFE', 'SPECIAL WEAPON'),
    icon: Icons.sports_baseball_outlined,
    scene: DemoScene.special,
    text: tr(
      'Granatwerfer, Mörser und Drohne aus Gems löst du mit F aus. Granaten '
          'und Mörser fliegen über Mauern hinweg dorthin, wo die Maus steht.',
      'Grenade launcher, mortar and drone from gems are fired with F. '
          'Grenades and mortar shells fly over walls to where the mouse is.',
    ),
  ),
  TutorialStep(
    title: tr('VERTEIDIGUNG', 'DEFENSE'),
    icon: Icons.shield_outlined,
    scene: DemoScene.defense,
    text: tr(
      'Im Modus Verteidigung bringen Abschüsse Geld. B baut ein Geschütz '
          'neben deinem Panzer, V wechselt den Typ.',
      'In defense mode kills bring money. B builds a turret next to your '
          'tank, V switches the type.',
    ),
  ),
];

List<TutorialStep> get _tour => [
  TutorialStep(
    title: tr('DREI WEGE ZU SPIELEN', 'THREE WAYS TO PLAY'),
    icon: Icons.flag_outlined,
    text: tr(
      'Allein gegen CPU-Panzer, mit anderen per Link, Code oder Raumliste, '
          'oder gemeinsam gegen ${GameConfig.defenseWaves} Wellen.',
      'Alone against CPU tanks, with others by link, code or room list, '
          'or together against ${GameConfig.defenseWaves} waves.',
    ),
    chips: [
      TutorialChip(Icons.person_outlined, tr('EINZELSPIELER', 'SINGLE PLAYER')),
      TutorialChip(Icons.groups_outlined, tr('MEHRSPIELER', 'MULTIPLAYER')),
      TutorialChip(
        Icons.compare_arrows_outlined,
        tr('ROT GEGEN BLAU', 'RED VS BLUE'),
      ),
      TutorialChip(Icons.shield_outlined, tr('VERTEIDIGUNG', 'DEFENSE')),
    ],
  ),
  TutorialStep(
    title: tr(
      '${_count(TankType.values.length)} FAHRZEUGE',
      '${_countEn(TankType.values.length)} VEHICLES',
    ),
    icon: Icons.directions_car_outlined,
    scene: DemoScene.vehicles,
    text: tr(
      'Jedes mit eigener Panzerung, Tempo und Kanone. Weitere Fahrzeuge '
          'und Tarnfarben kommen mit höheren Rängen.',
      'Each with its own armour, speed and cannon. More vehicles and '
          'camouflage colours come with higher ranks.',
    ),
  ),
  TutorialStep(
    title: tr('KISTEN', 'CRATES'),
    icon: Icons.all_inbox_outlined,
    text: tr(
      'Im Feld liegen Kisten mit Hilfe für den Notfall.',
      'Crates with emergency help lie around the field.',
    ),
    chips: [
      for (final type in PowerUpType.values.where((t) => !t.gem))
        TutorialChip(type.icon, type.label, type.color),
    ],
  ),
  TutorialStep(
    title: 'GEMS',
    icon: Icons.diamond_outlined,
    text: tr(
      'Gems bringen Munition, Treibstoff und Spezialwaffen, bis hin zu '
          'Fallschirmjägern mit Panzerfäusten.',
      'Gems bring ammunition, fuel and special weapons, even paratroopers '
          'with rocket launchers.',
    ),
    chips: [
      for (final type in PowerUpType.values.where((t) => t.gem))
        TutorialChip(type.icon, type.label, type.color),
    ],
  ),
  TutorialStep(
    title: tr('NACHSCHUB', 'SUPPLIES'),
    icon: Icons.local_gas_station_outlined,
    text: tr(
      'Ab Stufe Normal stehen Tankstellen und Munitionsdepots auf der Karte. '
          'Halte darauf an, um aufzufüllen. Beschuss lässt sie in die Luft '
          'fliegen und reißt Panzer in der Nähe mit, nach einer Weile stehen '
          'sie wieder. Bei Capture the Flag hat jedes Team eigene hinter '
          'seiner Basis, die nur der Gegner zerstören kann.',
      'From the normal level on, fuel stations and ammo depots stand on the '
          'map. Stop on one to fill up. Shells blow them up, taking nearby '
          'tanks along, and after a while they stand again. In capture the '
          'flag each team has its own behind its base that only the enemy '
          'can destroy.',
    ),
    chips: [
      for (final kind in DepotKind.values)
        TutorialChip(
          kind == DepotKind.fuel
              ? Icons.local_gas_station_outlined
              : Icons.inventory_2_outlined,
          kind.label,
          kind.color,
        ),
    ],
  ),
  TutorialStep(
    title: tr('GELÄNDE UND WETTER', 'TERRAIN AND WEATHER'),
    icon: Icons.terrain_outlined,
    text: tr(
      'Vier Gelände, auf denen Tag und Nacht sich abwechseln, mit Regen, '
          'Schnee, Sandsturm oder Nebel, die die Sicht begrenzen. Häuser, '
          'Sperren und Bäume lassen sich zerschießen.',
      'Four terrains where day and night alternate, with rain, snow, '
          'sandstorm or fog that limit your view. Houses, barriers and trees '
          'can be shot to pieces.',
    ),
    chips: [
      TutorialChip(Icons.park_outlined, MapTheme.forest.name.toUpperCase()),
      TutorialChip(Icons.wb_sunny_outlined, MapTheme.desert.name.toUpperCase()),
      TutorialChip(Icons.ac_unit_outlined, MapTheme.winter.name.toUpperCase()),
      TutorialChip(
        Icons.location_city_outlined,
        MapTheme.city.name.toUpperCase(),
      ),
      TutorialChip(Icons.water_drop_outlined, tr('REGEN', 'RAIN')),
      TutorialChip(Icons.blur_on_outlined, tr('NEBEL', 'FOG')),
      TutorialChip(Icons.nightlight_round_outlined, tr('NACHT', 'NIGHT')),
    ],
  ),
  TutorialStep(
    title: tr('DREI STUFEN', 'THREE LEVELS'),
    icon: Icons.signal_cellular_alt_outlined,
    text: tr(
      'Leicht: flaches Land, Treibstoff und Munition gehen nie aus. '
          'Normal: Hügel und Nachschub, der gesucht werden muss. Schwer: '
          'steile Hügel und Luftschläge.',
      'Easy: flat land, fuel and ammunition never run out. Normal: hills '
          'and supplies that have to be found. Hard: steep hills and air '
          'strikes.',
    ),
    chips: [
      TutorialChip(
        Icons.signal_cellular_alt_1_bar_outlined,
        BotLevel.easy.label,
      ),
      TutorialChip(
        Icons.signal_cellular_alt_2_bar_outlined,
        BotLevel.normal.label,
      ),
      TutorialChip(
        Icons.signal_cellular_alt_outlined,
        BotLevel.hard.label,
        GameColors.danger,
      ),
    ],
  ),
  TutorialStep(
    title: tr('STÜTZPUNKT HALTEN', 'HOLD THE BASE'),
    icon: Icons.fort_outlined,
    text: tr(
      'Geschütze, Gräben und Upgrades für den Panzer. Hält der Stützpunkt '
          'gut, wächst er vom Wachturm zur Festung und schickt eigene '
          'Hubschrauber und Jets. Nach Welle ${GameConfig.defenseWaves} könnt '
          'ihr verlängern: höhere Stufen, Raketenwerfer, zähere Gegner.',
      'Turrets, trenches and upgrades for the tank. If the base holds '
          'well, it grows from a watchtower into a fortress and sends its '
          'own helicopters and jets. After wave ${GameConfig.defenseWaves} '
          'you can extend: higher levels, rocket launchers, tougher '
          'enemies.',
    ),
    chips: [
      for (final kind in TowerKind.values)
        TutorialChip(_towerIcon(kind), kind.label),
      TutorialChip(Icons.upgrade_outlined, 'UPGRADES'),
    ],
  ),
  TutorialStep(
    title: tr('NACH DER RUNDE', 'AFTER THE ROUND'),
    icon: Icons.emoji_events_outlined,
    text: tr(
      'Revanche auf Knopfdruck, die letzte Runde als Wiederholung, dazu '
          'Ränge, Wertung, Abzeichen und Bestenlisten.',
      'A rematch at the push of a button, the last round as a replay, plus '
          'ranks, rating, badges and leaderboards.',
    ),
    chips: [
      TutorialChip(Icons.replay_outlined, tr('REVANCHE', 'REMATCH')),
      TutorialChip(Icons.movie_outlined, tr('WIEDERHOLUNG', 'REPLAY')),
      TutorialChip(Icons.military_tech_outlined, tr('RÄNGE', 'RANKS')),
      TutorialChip(Icons.workspace_premium_outlined, tr('ABZEICHEN', 'BADGES')),
      TutorialChip(
        Icons.leaderboard_outlined,
        tr('BESTENLISTE', 'LEADERBOARD'),
      ),
    ],
  ),
];

TutorialStep get _ready => TutorialStep(
  title: tr('BEREIT, KOMMANDANT', 'READY, COMMANDER'),
  icon: Icons.military_tech_outlined,
  scene: DemoScene.ready,
  text: tr(
    'Das war die Einweisung. Du findest sie jederzeit wieder auf der '
        'Anmeldeseite, der Startseite und im Warteraum.',
    'That was the briefing. You can find it again at any time on the '
        'sign-in page, the start page and in the waiting room.',
  ),
);

IconData _towerIcon(TowerKind kind) => switch (kind) {
  TowerKind.cannon => Icons.adjust_outlined,
  TowerKind.flak => Icons.flight_outlined,
  TowerKind.mortar => Icons.vertical_align_top_outlined,
  TowerKind.howitzer => Icons.gps_fixed_outlined,
  TowerKind.trench => Icons.horizontal_rule_outlined,
  TowerKind.rockets => Icons.rocket_launch_outlined,
};

/// Small numbers spelled out, as on the cards.
String _count(int n) => switch (n) {
  7 => 'SIEBEN',
  8 => 'ACHT',
  9 => 'NEUN',
  10 => 'ZEHN',
  _ => '$n',
};

String _countEn(int n) => switch (n) {
  7 => 'SEVEN',
  8 => 'EIGHT',
  9 => 'NINE',
  10 => 'TEN',
  _ => '$n',
};
