# Gameplay in detail

Everything the game does, with the numbers behind it. The short version is in the [README](../README.md).

## Getting in

- The game opens right on the start page that picks single player,
  multiplayer or defense, with the call sign at the top. It is changed in
  the account page and only taken with the tick or Enter, which then says
  "Saved". Everybody starts as a guest; instead of the rank card a guest
  sees a card that invites them to sign in, and it and the account button
  open the account page that signs in or registers with an e-mail address. Signing in with an address that has
  no account yet creates one. Only a mail link that fails to sign in in
  this tab shows a welcome page first, which explains why and takes the
  code from the mail instead.
- Guests play unranked: no experience, rating, badges or vehicles beyond
  the first three, and they do not show up in the leaderboards. They can
  create an account at any time, the account keeps the guest's id and with
  it anything recorded before guests were left out.
- A tutorial behind a button on the start page and in
  the waiting room. It never opens by itself, the button stands out until
  the player went through it once. It explains the controls of the device
  it runs on, two touch sticks with an animated thumb on phones and
  tablets, keys and mouse on a desktop, each acted out on a small training
  ground, then plays a quick tour through modes, vehicles, crates, gems,
  weather, levels, the defense mode and what comes after the round. Every
  card moves on by itself once there was time to read it (at least 7.2 s on
  a controls card and 5 s in the tour, longer for a long text,
  `TutorialOverlay.cardTime`). On a controls card the player can
  take over at any time: a thumb on the sticks, a game key or a click turns
  the scene into a training ground with their own tank, the game's controls
  and a task: drive into the ring on the driving card, three hits on the
  others (a few enemy tanks stand around, grenades on the special weapon
  card). The card then folds its text away and shows the task with its
  progress; done, it says so and NEXT lights up in amber, but the card
  waits for the player instead of moving on (the aim assist scores its
  hits within a second, and the card used to leave while the thumb was
  still on the stick). The sticks and buttons of the demonstration sit
  where and as large as the game draws them, the aim assist as the game's
  pill above the aim stick. On a television the thumb on the remote or a
  controller's stick takes over the same way and drives as in a round (the
  click, A or R2 fire, play/pause or L2 the special weapon); the remote's
  swipes never turn the card there, and a click presses the button in
  focus (while practising it fires, until the task is done).

## Ways to play

- **Single player:** alone against 1 to 4 CPU tanks on three levels.
- **Multiplayer:** free for all or red against blue, with CPU tanks to fill
  up the field on request, and always when the host starts alone: up to
  four tanks in all, and always at least as
  many CPU tanks as people (6 in capture the flag, same rule). In red
  against blue a picked side stays picked, and the people on AUTO are
  spread by the rank of their vehicle so a new player gets a veteran at
  their side: with CPU tanks to fill up, the strongest and the weakest go
  together to the weaker side, pair by pair; without, each goes to the
  smaller side, the weaker one on a tie. CPU tanks even the sides out when
  the picks left one short; on the side with fewer people they first take
  the vehicles of the other side's people that have no counterpart (two
  people together meet their own two vehicles), and the rest come in
  pairs, the same vehicle on both sides. Private rooms by link, code or QR code, public
  rooms in a room list, and late joiners can watch the running round.
- **Closing zone** (single player and multiplayer): after 20 seconds the
  safe circle shrinks over 90 seconds to a radius of 120, holds there for
  30 seconds and then draws in to nothing within a minute. Outside it a
  tank loses 10 HP a second, half a point more for every second since the
  zone closed, so every round comes to an end.
- **Defense (tower defense):** together against 8 waves of enemy tanks that
  roll along the road to the base. CPU comrades fill the squad, and later the
  base sends aircraft of its own. The host may call the next wave before
  the break is over (WAVE NOW, key N). Kills bring coins for guns (key B), the
  base hands out ammunition, and destroyed tanks return after a short time.
  A base that holds well grows from a watchtower to barracks to a fortress.
  After wave 8 the win is safe and the host may extend by 4 waves at a
  time, up to wave 20: tougher enemies, a fifth step for guns and tank, a
  rocket launcher and a citadel. The round ends as a win after the last
  wave of a stretch, when the base falls or when the host ends it. Every
  extra wave beaten off earns experience, half as much when the base falls
  in the end. When
  the host leaves for good, the next player in line runs the waves on
  after a few seconds, with the enemies where they were and the host's
  guns still standing.
  See [Defense thresholds](#defense-thresholds) for the numbers.
- **Capture the flag:** red against blue on the open field, a base at the
  left and the right end with a flag each. Drive over the other side's
  flag to take it and bring it to your own base while your flag stands
  there: 3 captures win, after 8 minutes the side ahead, and a draw goes
  into overtime until the next capture. The carrier drives 15 % slower and
  cannot use its special weapon; destroyed, it drops the flag where it
  stood. A dropped flag goes home when a comrade touches it or after
  20 seconds by itself. Destroyed tanks return to their base after
  6 seconds, there is no closing zone, and CPU tanks always fill both sides
  up to three each: two in three of them go for the flags, one guards the
  base, and all of them chase whoever has their own flag. The round is
  rated like a team round.
- **Two on one screen:** on the Apple TV, in the browser and on an iPad,
  with two controllers or phones (a phone keeps one player and offers
  neither the split screen nor the duel); on a computer also the keyboard and one
  controller or phone. Single player, multiplayer, defense and
  capture the flag play on a split screen, each half from its own tank;
  single player puts both against at least two CPU tanks (2 to 4), and
  capture the flag
  puts both on one side or, as picked in the settings, against each other.
  Free of Realtime messages, see
  [Apple TV](platforms.md#apple-tv).
- **Duel (two on one screen):** red against blue on a defense map, a base
  at either end of the road. Each side's waves roll against the other's
  base, guns and tanks fight the other side, and either player sends extra
  tanks. Shown on the whole field at once, whose base falls first loses.

## On the battlefield

- Nine vehicles with animal names instead of real model or maker names
  (Hermelin, Fuchs, Spitzmaus, Habicht, Keiler, Hirsch, Dachs, Igel and
  Wolf), each with its own armour, speed and gun. Hermelin, Fuchs and
  Spitzmaus are there from the start, the others come with ranks 2, 3, 4, 5,
  6 and 8, and every later one is stronger than the ones before. The Igel
  (rank 6) is a rocket launcher: four rockets a salvo side by side, 12
  damage each, a wide spread that hurts most up close. From wave 6 of a
  defense round it rolls in among the enemies too, in one slot of ten
  (in place of a Fuchs), in rooms where everybody has this version. The lobby
  lists the unlocked ones first. Four free paint schemes and four more that
  come with higher ranks, for playing alone. With others every tank drives
  in its own colour, and in red against blue (teams, capture the flag) in
  its team's red or blue, so the lobby offers no camouflage then. The
  defense paints its sides the same way: defenders red, attackers blue, and
  in a duel each player sees their own side red and the other one blue
  (two players on one screen: the left base red, the right one blue). A
  ring in the team's colour stays only around hulls of another colour and
  shows while a hit flashes the hull white. The own tank always wears its
  ring, in the team's colour or amber without sides, with a dark rim, so it
  stands out among its side.
- Six grounds (Gefechtsplatz, Wüste, Winter, Stadt, Bergwald, Inseln), each
  with weather (clear, rain, snow, a sandstorm or fog) that may turn during
  a round, and day and night taking turns at a fixed pace: 80 seconds of
  day, 40 of night. Night, fog and sand limit the view to a circle around
  the tank.
  - *Bergwald* (mountain forest): dense conifers, scree that slows and
    hills on every difficulty, also on easy (7 gentle ones; 12 on normal,
    17 steep ones on hard).
  - *Inseln* (islands, `island_shape.dart`): more water than land. Seven
    islands of organic shape (each shore a sum of a few waves of
    different length, laid out by the seed): a middle one that takes the
    end of the closing zone and six around it that carry the start
    positions, the ones at 0 and 180 degrees the flag bases. Wooden
    bridges join every island of the ring to its neighbours and the
    middle to both flag islands, the same on the red and the blue side.
    Along every shore runs a strip of shallow water (46 units) that tanks
    wade through at 45 % of their speed; beyond it the water is deep and
    blocks them like a river bank, shells fly over. CPU tanks route over
    the bridges (`IslandShape.waypoint`, the fewest bridges to the
    target's island). Starts, depots and crates are moved onto land,
    soldiers keep to it, trees and houses stand only on the islands.
  - The two newer grounds and the two newer defense maps only come up in a
    room where every client knows them (see docs/netcode.md, "Content
    level"); a newer ground picked for a room with an older client gives way
    to a random one of the first four.
- Buildings, barriers and trees that can be shot down, and soldiers on foot
  that fight: in a team round the squads are red or blue and shoot at tanks
  and at each other. They patrol and stalk enemies that come within sight.
  They can be shot or run over.
- Limited ammunition with blue gems to refill it, and gems for a grenade
  launcher, a mortar, a kamikaze drone, a squad on foot and a drop of
  paratroopers with rocket launchers.
- Crates with repair, smoke, rapid fire, a shield, mines and artillery.
- Crates and gems go into an inventory at the left edge and are set off
  later with the keys 1 to 6 or a tap. Every gem carries a symbol of what
  it holds. Only filled slots show, empty frames would cover the field.
- A gentle start: for the first 10, 8 or 5 s of playing time (easy,
  normal, hard) CPU tanks leave people alone and only fight each other,
  unless a person hits them first, and the aim assist only aims without
  firing (`TankGame.ceasefire`). After that a person counts as nearly three
  times closer (easy) or twice as close (normal, hard) as another CPU tank
  when they pick a target (`BotLevel.humanPull`), so the CPU tanks no longer
  finish each other off while a player waits, nor all go for the player at
  once (see [Balance](#balance)). A device that
  never finished a round starts on easy, and the first round a host starts
  in a session opens by day under a clear sky for at least a minute. The
  waiting room shows difficulty, terrain and mode in one line that opens
  the settings. LAST PLAYED on the start page (from tablet width, next to
  the briefing) goes straight into a solo round with the tank and
  difficulty used last, and alone the countdown takes
  2 s instead of 3.
- CPU tanks drive the vehicles the people in the round drive
  (`GameConfig.mirrorStyle`): alone every CPU tank comes in the player's
  vehicle, with several people each draws from theirs, and in red against
  blue the n-th CPU tank of each side gets the same one. A new player in a
  starter meets starters, a pilot in a Wolf meets Wolves. CPU tanks once
  came in any vehicle, which beat new players, and then in starters only,
  which left every higher rank with weak opponents (a player at normal CPU
  level won 83 % on hard in a Wolf, 26 % in a starter; issue 24). On normal and hard they take 1.6 and 1.4 times as long between
  shots as a person in the same vehicle (`BotLevel.fireFactor`).
- The aim assist is there on every level; hard once took it away, and on a
  phone hard could then hardly be won.
- At night, in fog or sand CPU tanks fire at people only as far as those
  can see (`BotBrain.reach`): there is no arrow for a tank beyond sight, and
  in a play test on hard one shot the player from out of view.
- The difficulty picked last stays on the device for the next start
  (`TankGame.chooseLevel`), so LAST PLAYED names the level really played.
- Three levels that change more than the CPU tanks: on easy the ground is
  flat and fuel and shells never run out. On normal the land gets hilly
  (slower uphill, faster downhill) and fuel and shells must be found, fuel
  in canister gems or at the depots below. On hard the hills are steeper and an air strike gem
  sends a bomber over an enemy. A hunter drone gem launches a drone after a
  random enemy.
- Fuel stations and ammunition depots from the normal level on, in single
  player, multiplayer and capture the flag (defense has its base for that).
  A tank that stands still on the pad fills up, a full tank or magazine in
  6 s; rolling over it only shows the hint to stop. A free for all gets
  four neutral ones from the seed, fuel and ammunition by turns on a ring
  inside the start positions, so the closing zone swallows some of them.
  In capture the flag each team has one of each behind its base that
  serves only its own tanks; its own shells fly over them, the enemy can
  shoot them. A depot takes 160 damage from shells, blasts and barrages,
  then goes up and hurts tanks within 110 (45 damage, half at the edge;
  the tank that brought it down gets the kill), and stands again after
  45 s. CPU tanks drive there when they run low, top up at one close by
  and leave when an enemy comes near. Over the net a depot rides on the
  `obstacle` event (flag `d`, the shooter as `id`), no new event.
- Defense on six maps with a river, bridges, woods and farm houses (the
  newer two: *Flussufer*, along the river bank with a crossing near the
  top, and *Haarnadel*, in from the top with two hairpins across the
  river). The
  waves bring tanks, soldiers on foot, attack helicopters, jets that bomb
  the base and kamikaze drones. Cannons, flak (the only thing besides the
  Habicht that hits aircraft properly), mortars and later howitzers, three
  levels each, trenches that cover a tank, and armour, gun, engine and
  magazine upgrades for the tank, one list at a time in the panel. The
  enemy shoots guns and trenches to pieces and from wave 3 digs in cannons
  and flak of its own beside the first stretch of the road. Money comes
  with the player's own kills (rising from the wreck, less with every
  wave) and every wave beaten off (+50). On a desktop the camera may run
  past the field's edge by the width of the mini map, so the base at the
  end of the road never hides under it.
- On iOS a widget with the pilots online, a Live Activity for the running
  round, and an Apple Watch version in progress, see [Apple Watch](platforms.md#apple-watch).
- Visible battle damage, hit sparks, screen shake, a kill feed, a mini map
  and markers for enemies off screen, which slide along the edge past the
  gauges, the mini map and the panels. The mini map of the battle modes
  leaves out woods, mud and barriers, fades the buildings and shows crates
  and gems only within 450 of the own tank; tanks, soldiers, drones,
  depots, flags and the zone stay.
- Keyboard and mouse, or two touch sticks on phones and tablets. The left
  stick points where the tank should go, the right one aims and fires, and
  an aim assist (on by default, switched with a button right above the aim
  stick that says it fires by itself) turns the turret onto the nearest enemy and fires while the
  right thumb rests. Upright phones look 20 % closer
  (`GameConfig.uprightPhoneZoom`), outside defense rounds. Each stick
  follows the thumb that landed first in its zone, also when it slides
  over the buttons; a second finger in the zone takes the stick over when
  the first lifts. The special weapon fires while any finger holds it, and
  a finger that comes up after the controls were rebuilt under it (aim
  assist switched by the screen, weapon spent, round over) changes nothing.
- The phone as a controller for the game on a computer or tablet: the
  account page in the browser shows a pairing QR code, the app on the
  phone scans it (Account, Use as controller). The phone then
  shows the two sticks, armour, shells and fuel, the items in the game's
  slots (down the left edge upright, between the thumbs sideways) and, in a
  defense round, the coins beside the name and the shop in two groups,
  *Build* and *Round*: the guns to build where the tank stands, the
  upgrade of the gun next to it, the tank's upgrades, the host's *Wave now*
  and, after each stretch of waves, *+4 waves* or *End*. A dot on *Guns*
  and *Upgrades* (on the screen's buttons as well) says the coins reach for
  something behind them. Hits are felt as a buzz. Only the app on a phone
  becomes a controller (shorter side under 600 points): a tablet offers no
  *Use as controller*, and a pairing link opened on a tablet or in any
  browser (a phone camera without the app) points to the app instead of
  taking a seat. The browser game pairs controllers, it never is one.
- Game controllers: one steers the own tank in the browser, on iPhone, iPad,
  Android and the Apple TV, as a paired phone does; two play two on one
  screen of a computer, tablet or television. A touch on the screen of a
  phone or tablet brings the touch sticks back over a connected controller
  (`TankGame.touchOverPad`), until the controller is used again. On a
  split screen the second half wears the same plates as the first and goes
  by the call sign of the phone that steers it (the account's when one is
  signed in there, in the browser also the one it last played under), else
  PLAYER 2.
- An Apple TV app, played with the Siri Remote or a controller, with menus
  that fit the television without scrolling, see [Apple TV](platforms.md#apple-tv).
- The Apple Vision Pro, running the iPad app: look at a spot and pinch to
  aim and fire there, pinch and drag in the lower left to drive, without
  screen shake, see [Apple Vision Pro](platforms.md#apple-vision-pro).

## Balance

`test/game/balance_sim_test.dart` plays solo rounds with a stand-in for the
player on a faked round clock: idle, idle with the aim assist (a phone
player who only waits), and a player who drives and shoots like a CPU tank
of the easy or normal level. Against 1 to 4 CPU tanks (2.5 on average) an
even fight wins about 29 % of the rounds. It is skipped in the normal test
run; `flutter test test/game/balance_sim_test.dart --run-skipped
--dart-define=ROUNDS=60` starts it. The rounds open by day, so night and
fog are not part of it.

Wins in 100 rounds each, October 2026: before any change, after the first
pass (CPU vehicles, pull towards people) and now, with normal and hard made
easier so that hard stays playable on a phone:

| Level | Player | First | Then | Now |
| --- | --- | --- | --- | --- |
| easy | idle | 7–25 % | 5–8 % | 9 % |
| easy | aim assist only | 63 % | 80–95 % | 81 % |
| easy | like a normal CPU | 53 % | 52–63 % | 43 % |
| normal | idle | 3 % | 0–3 % | 5 % |
| normal | aim assist only | 37 % | 35–43 % | 61 % |
| normal | like a normal CPU | 10 % | 18–33 % | 28 % |
| hard | idle | 3 % | 0–2 % | 4 % |
| hard | aim assist only | 0–8 % | 0–8 % | 31 % |
| hard | like a normal CPU | 7 % | 5–8 % | 17 % |

What moved the numbers: the aim assist on hard, CPU tanks in starter
vehicles, longer pauses between their shots and a softer pull towards
people on normal and hard, a larger aim error, slower reactions and a
longer gentle start (8 s on normal, 5 s on hard). Slower fire alone barely
changed hard: three or four accurate tanks going for the player at once
was what decided.

**CPU vehicles mirror the player (issue 24).** With CPU tanks in starters
only, the odds hung on the player's vehicle: in a Wolf a player at normal
CPU level won 83 % on hard, in a starter 26 %. Now CPU tanks drive what the
people in the round drive. `--dart-define=VEHICLE=wolf` (any `TankType`
name) puts the stand-in into that vehicle. Wins in 100 rounds per vehicle,
October 2026, as the range over all nine vehicles and a random starter:

| Level | Player | Starters only | Mirrored |
| --- | --- | --- | --- |
| easy | idle | 4–15 % | 0–10 % |
| easy | aim assist only | 64–97 % | 60–79 % |
| easy | like an easy CPU | 17–84 % | 16–32 % |
| easy | like a normal CPU | 38–100 % | 37–67 % |
| normal | idle | 3–16 % | 2–7 % |
| normal | aim assist only | 42–89 % | 44–63 % |
| normal | like an easy CPU | 12–78 % | 3–24 % |
| normal | like a normal CPU | 28–96 % | 31–52 % |
| hard | idle | 0–9 % | 1–7 % |
| hard | aim assist only | 21–81 % | 18–37 % |
| hard | like an easy CPU | 4–53 % | 2–19 % |
| hard | like a normal CPU | 23–83 % | 15–33 % |

Every level stays winnable in every vehicle, and the starter numbers barely
moved (they mirror starters as before). The spread that is left comes from
the vehicles themselves: a Hirsch or an Igel against its own kind fights
differently from a Fuchs. A weak player in a heavy vehicle now meets heavy
vehicles too (6–18 % on normal), which is what a starter player met
before. Not simulated: a room where a new player and a veteran meet, where
each CPU tank draws from both of their vehicles.

**Defense builds.** `test/game/defense/trench_balance_sim_test.dart`
(skipped as well, `--run-skipped --dart-define=ROUNDS=8`, `WAVE=5` for a
later wave) puts one build a third of the way down the road and sends
three squads on foot (15 men) and two tanks of the wave past it, without
comrades and without the director's waves. Measured October 2026, 8 rounds
each, with the trench's rocket man (wave 4 on), the slowdown after
crossing and the mortar leading its shells:

| Wave | Build | Cost | Bounties | Hits on the base | Tanks at the base | Arrival | Left |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 3 | nothing | 0 | 0 | 27 | 16 of 16 | 35 s | |
| 3 | trench on the road | 60 | 60 | 11 | 16 of 16 | 38 s | 62 % |
| 3 | trench beside the road | 60 | 60 | 11 | 16 of 16 | 35 s | 74 % |
| 3 | cannon | 100 | 86 | 1 | 1 of 16 | 54 s | 60 % |
| 3 | mortar | 150 | 84 | 1 | 0 of 16 | | 41 % |
| 5 | nothing | 0 | 0 | 24 | 16 of 16 | 33 s | |
| 5 | trench on the road | 60 | 56 | 5 | 8 of 16 | 37 s | 75 % |
| 5 | trench beside the road | 60 | 49 | 7 | 13 of 16 | 41 s | 69 % |
| 5 | cannon | 100 | 67 | 0 | 0 of 16 | | 79 % |
| 5 | mortar | 150 | 63 | 2 | 1 of 16 | 42 s | 69 % |

The trench pays for itself in one wave against infantry and stops every
soldier. Against tanks it first only held them up; with the rocket man
from wave 4 and tanks staying slow after crossing it stops some and keeps
most of the damage off the base, while the cannon stays the build for
tanks, so the price of 60 holds. What the runs found on the way: shots
aimed from the middle of a trench across the road flew past the men close
by, so every man aims for himself; no gun led its aim on soldiers (they
had no speed), so shots at a soldier crossing the line of fire missed;
trenches took no shells, only blasts. All three are fixed.

The mortar first earned a third of its price (49 in wave 3), let every
tank through and left 14 hits on the base. It aimed at where its target
stood, but its shell is 1.3 s in the air: a tank on the road had moved
on by more than the blast radius of 75 when it landed, and the mortar
goes for tanks first. Now it leads its shell by the flight time, kept
inside its reach, like every other gun leads its aim, and stops the
tanks as well as the cannon does. The cannon stays the cheaper answer
to one road; the mortar's extra price pays for its reach of 620 against
420, fire over cover and a blast that catches a whole squad, which a
single build on one stretch does not show. The howitzer fires the same
shell and leads it the same way.

## Weapons and damage

All values are hit points. They live in `lib/src/game/game_config.dart`,
`lib/src/game/tank_stats.dart` and, for the guns,
`lib/src/game/defense/tower.dart`. Blasts do their full damage at
the centre and half at the edge of the radius.

**Tank guns.** Per second means with every shot landing.

| Vehicle | Armour | Damage per shot | Barrels | Seconds per shot | Per second | Magazine |
| --- | --- | --- | --- | --- | --- | --- |
| Hermelin | 100 | 8 | 1 | 0.17 | 47 | 90 |
| Spitzmaus | 60 | 38 | 1 | 1.2 | 32 | 14 |
| Fuchs | 70 | 11 | 1 | 0.26 | 42 | 55 |
| Habicht | 105 | 9 | 2 | 0.26 | 69 | 45 |
| Keiler | 165 | 33 | 1 | 0.52 | 63 | 20 |
| Hirsch | 185 | 75 | 1 | 1.05 | 71 | 12 |
| Dachs | 135 | 14 | 1 | 0.2 | 70 | 70 |
| Wolf | 190 | 50 | 1 | 0.64 | 78 | 16 |

Rapid fire from a crate shortens the time between shots to 45 % for 8
seconds. In a defense round the enemy tanks fire three times slower.

**Special weapons and crates.**

| Weapon | Damage | Radius | Range | Uses |
| --- | --- | --- | --- | --- |
| Grenade launcher (gem) | 45 | 85 | 90–380 | 3 |
| Mortar (gem) | 55 | 95 | 140–560 | 4 |
| Kamikaze drone (gem) | 60 | 75 | hunts by itself | 1 |
| Hunter drone (gem) | 60 | 75 | after a random enemy | 1 |
| Artillery (crate) | 45 | 110 | up to 360 | 1 barrage |
| Air strike (gem, hard) | 49.5 per bomb | 110 | up to 700 | 4 bombs |
| Mines (crate) | 35 | 12 | where the tank stands | 3 mines |
| Repair (crate) | +40 armour | | | |

**Soldiers.** A rifle does 1 per shot every 1.3 seconds up to 220, which is
deadly to soldiers and little to tanks. A rocket launcher does 18 every 4
seconds up to 300. Squads off the road (from the seed, paratroopers, gems)
patrol a round of up to 220 about where they stand at a walk (26 a
second), keeping round houses. Once an enemy tank out of the smoke or an
armed soldier of the other side comes within 520, they stalk it at 46 a
second to three quarters of their reach (165 for riflemen, 225 for rocket
launchers) and hold there while they fire; 6 seconds after losing sight
of it they patrol again where they stand. Squads marching down the road
of a defense round keep to the road.

**Defense.**

| Who | Damage | Notes |
| --- | --- | --- |
| Cannon | 18 per shot, 0.45 s, range 420 | +35 % per level |
| Flak | 6 per shot, 0.16 s, range 600 | 12 against aircraft (proximity fuse, bursts within 30), 1.8 on the ground |
| Mortar emplacement | 50, radius 75, range 130–620 | +35 % per level |
| Howitzer | 110, radius 75, range 240–1050 | +35 % per level |
| Helicopter (both sides) | 10 per rocket, every 1.8 s, range 420 | |
| Jet (both sides) | 49.5 per bomb, 3 bombs | |
| Enemy kamikaze drone | 60, radius 75 | |
| Enemy tank at the base | 120 per 100 armour of the tank | it blows itself up |
| Enemy soldier at the base | 25 | |

**What softens a hit.** A shield lets 40 % through, every armour upgrade
takes 15 % off and a trench halves what is left. Every gun upgrade adds 15 %
to the tank's shells. Against aircraft, flak and the Habicht do double, other
shells 40 % to a helicopter and nothing to a jet. On the ground flak
does only 30 % of its damage, about a quarter of what a cannon fires in the
same time, so a row of flak no longer holds the road. Against the sky it
got sharper instead: its shells burst within 30 of an aircraft or drone,
the mount swings 10 radians a second (the other guns 6) and every gun
works out its lead a few times over. A jet at 420 a second used to slip
through three flak guns around the base; now one stops it about one time
in three before it bombs, two almost always.

## Defense thresholds

The numbers that decide how a defense round grows. They live in
`lib/src/game/game_config.dart` and, for the guns,
`lib/src/game/defense/tower.dart`.

**The base.** It starts with 1500 hit points. A wave counts as held well
when the base loses at most 15 % of its current maximum during it. The
count of such waves decides how far the base has grown:

| Stage | Waves held well | Hit points | Comrades | Guns per player | Guns on the base |
| --- | --- | --- | --- | --- | --- |
| Watchtower | 0 | 1500 | start value | 6 | none |
| Barracks | 2 | 2000 | +1 | 8 | cannon |
| Fortress | 4 | 2500 | +2 | 10 | cannon (level 2) and flak |
| Citadel | 7 | 3000 | +3 | 12 | cannon (level 3), flak (level 2), rockets |

The 500 hit points of each step are added right away. The count is not
reset by a bad wave, the base only waits longer for the next step.

**The squad.** CPU comrades fill the squad up to 4 tanks, at least one joins
even a full room. A destroyed comrade rolls out of the base again after 10
seconds. In a room where everybody has the current version a comrade's
vehicle follows the wave it rolls out in, by the same rules as the
enemy's waves (Fuchs and Hermelin early, Habicht from wave 3, Dachs from 4,
Keiler from 5, Igel from 6, Wolf from 7); the enemy's tanks still get
tougher armour with every wave on top. With an older client in the room
every slot keeps its fixed vehicle (Keiler, Hermelin, Habicht, Keiler,
Fuchs).

**The last helicopter.** Once no enemy tank is left, an enemy helicopter
holds the wave open on its own. It then seeks out the nearest defender or
gun anywhere on the field and keeps only 150 off instead of 260, so it
comes into view and into the flak instead of being hunted across the map.
With nothing else in range the aim assist, and the comrades, take a
helicopter on with tank shells (40 %), so the wave ends without flak too:
on the Apple TV the remote aims only through the assist, which before went
for aircraft only in a Habicht, and a wave whose last enemy was a
helicopter never ended there.

**Air support.** From wave 3 the base sends an attack helicopter every wave,
which stays 40 seconds. From wave 5 a jet follows 14 seconds into the wave
and bombs the enemy closest to the base.

**Money.** 150 at the start and 50 for every wave beaten off. Bounties
shrink with the waves: in wave *w* they are the first wave's divided by
1 + 0.2 × (*w* − 1), rounded, at least 1. A tank brings 20 in wave 1, 14 in
wave 3 and 8 in wave 8; an aircraft 40, 29 and 17; a soldier 5, 4 and 2; an
enemy gun 60, 43 and 25. The waves grow, so a whole wave pays about the
same, but the guns get dearer.

**Guns and trenches.**

| Kind | Cost | From wave | Hit points (level 1) | Job |
| --- | --- | --- | --- | --- |
| Cannon | 100 | 1 | 240 | tanks |
| Flak | 120 | 1 | 200 | aircraft and drones |
| Mortar | 150 | 1 | 200 | area fire up to 620 |
| Howitzer | 220 | 4 | 300 | heavy area fire up to 1050 |
| Trench | 60 | 2 | 360 | 3 riflemen and a machine gun against infantry (range 260), from wave 4 one with an anti-tank rocket launcher; a tank in it takes half damage |
| Rockets | 260 | extension | 260 | tanks and aircraft, range 640 |

The price is for the first of a kind; every further one of the same kind a
player already has adds 30 % of it (flak 120, 156, 192, …), so a wall of one
kind gets dear. The buttons show the current price and are only bright
(affordable) or faint, never marked: the kind built last is what B, R1 or
the remote's button builds, and the key hint above the list names it.
Building says what the gun or trench is for in a notice, and when the
coins start to reach for a gun or an upgrade a notice says so once.

Each upgrade adds 30 % hit points, 35 % damage and 12 % range and fires 15 %
faster; trenches have no levels. Enemy shells, bombs, barrages and drones
wear guns and trenches down, and enemy tanks and helicopters go for them
when no tank is near. A destroyed gun frees its place. Up to 4 trenches per
player, they do not count as guns. Guns keep off the road, trenches may
cut across it (not over a bridge): on the road a trench is dug on its
middle and lies across it from edge to edge, beside the road it runs
along it. Four men sit in it, three with rifles and one with a machine
gun; they take turns firing (one shot every 0.35 s for the whole trench,
3 damage), at soldiers first and tanks after, each man aiming from where
he sits, and one of them goes with every quarter of its hit points, the
fire slowing with him. From wave 4 the first man, the last to fall,
also carries an anti-tank rocket launcher: 30 damage every 3 seconds at
the nearest enemy tank within 300, led like the rifles. At rest they look
where the enemy comes from: on the road up it, beside it over it. Enemy shells hit a trench along its
length, unless a tank of its side sits in it: that tank takes the shell,
halved. Tanks of
either side crawl over a trench at a quarter of their speed and stay that
slow for 1.5 seconds after, their tracks clogged with earth; soldiers
march on through it; only a tank of the side that dug it takes cover
there, so an enemy rolling over a trench on the road gets none.

On the easy level shells never run out, so the HUD leaves the ammunition
gauge out. On a desktop the defense panel keeps clear of the mini map and
wraps its buttons in a narrow window.

**The enemy's guns.** From wave 3 the enemy digs in guns beside the first
stretch of the road, one more every second wave up to 4 (wave 3: 1, wave 5:
2, wave 7: 3, wave 9: 4), cannon and flak by turns, on fixed spots between
14 % and 36 % of the road. They start at level 1, rise a level every third
wave and fire at 1.8 times the players' interval, at tanks, guns, soldiers
and, the flak, the base's aircraft. Every new wave rebuilds the ones that
were destroyed. The players' shells and blasts, the comrades and the
players' guns hit them; whoever hit one last on their own screen gets its
bounty. The host fires them (`tower` and `shoot` events with the id
`td-g`); not in a duel.

**The extension.** After the last of the 8 regular waves the host has 25
seconds to add 4 more waves; without an answer the round ends as a win. After
those 4 the same question comes again, and after wave 20 the round is over
whatever happens. Endless waves left no clear end in the play test. The host
may also end the secured round at any time, mid-wave too, through the exit
button, whose question then offers *Win · end*. Guns and the
tank's upgrades go up to level 5 instead of 3 (armour steps 4 and 5 shield
10 % each instead of 15 %), the rocket launcher can be built, and every wave
past the 8th makes enemy tanks 12 % tougher. If the base falls, the round is
still a win.

## Leaving a round

- Escape, or the small exit button next to the sound button (bottom left
  while watching), asks whether to leave the running round; Escape again
  or *Keep playing* takes it back, Enter or *Leave* goes. The round runs on
  behind the question, it cannot be paused for the others.
- Leaving records nothing, neither a defeat nor experience or badges, and
  the question says so. Once a defense is won (after wave 8) the host's
  question offers ending the round as a win instead.
- Alone with CPU tanks the player is straight back in the waiting room. With other people in the round the player leaves the
  room too, and the others see the tank go like a pilot who closed the tab.
- On the end screen Escape goes back to the waiting room, in a replay it
  ends the replay. The replay's end button sits in the bar at the top
  beside *Next tank*, and so does *Whole map* (key M): the camera then
  holds still over the whole arena or defense field from above instead of
  following a tank, and the choice stays for the next replay. The Apple TV keeps its Menu button from throwing anybody
  out of a round and shows no exit button.

## After the round

- A rematch button on the end screen and a replay of the last round. With
  other people in the round the end screen goes back to the waiting room
  after 15 s and counts down on its button; alone it stays until the
  player picks.
- Ranks from experience: every rank starts from 0 and rank *n* needs
  120 × *n*² to the next (120 to rank 2, 5880 from rank 7 to 8), and the
  card counts within the rank. The total of the old curve was the step
  itself, so ranks came too easily. An Elo rating, ten badges and one leaderboard of all
  pilots by points.
- Holding out counts, in a lost round too. Experience per round: 10, plus
  20 per kill, 1 per 10 damage (up to 200), 50 for the win and 10 for every
  opponent outlasted, people and CPU tanks alike (in a team round the whole
  beaten team). A defense round adds 30 for every wave beaten off beyond the
  eighth, 15 when the base fell in the end: holding out to wave 20 brings
  360 on top, falling in wave 20 still 165 (migration 0022; at most one
  wave per 15 s of the round's time, only with a round ticket). The Elo rating compares the pilot pairwise with every
  opponent: won against those who went down earlier, lost against those who
  outlasted them, so the second to last loses far less than the first one
  out. A lost battle with more than two tanks shows the place on the end
  screen ("PLACE 3 OF 5").
- Leaderboard points weigh every total a pilot has, so more rounds, wins and
  kills always count (`lib/src/db/score_points.dart`): 10 per round, 50 per
  win, 20 per kill, 1 per 20 damage, up to 20 per round for accuracy (hits
  per shot; only shells out of the own gun count, each once, not guns,
  mines or blasts), 1 per 30 s alive, and twice the rating's distance from the
  start of 1000 once a rated round moved it. Never below zero. Ties go to
  the rating, then wins, then kills. The rating alone ranked badly: it only
  moves in rounds with a rated opponent, so one even round outranked a
  dozen rounds with eleven wins.

