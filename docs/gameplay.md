# Gameplay in detail

This is the reference for everything the game does, with the numbers
behind it: modes, vehicles, levels, items, the defense mode and how rounds
are scored. It is for players who want the details and for developers who
change the balance. The short version is in the [README](../README.md).
Most numbers live in
[`lib/src/game/game_config.dart`](../lib/src/game/game_config.dart); where
another file holds them, the section says so.

## Contents

- [Getting started](#getting-started)
- [Game modes](#game-modes): single player, multiplayer, closing zone,
  defense, capture the flag, two on one screen, duel
- [Difficulty levels](#difficulty-levels)
- [Vehicles](#vehicles)
- [Maps, weather and terrain](#maps-weather-and-terrain)
- [The battlefield](#the-battlefield): obstacles, soldiers, fuel and
  ammunition
- [Crates, gems and the inventory](#crates-gems-and-the-inventory)
- [Weapons and damage](#weapons-and-damage)
- [Defense in detail](#defense-in-detail): base, squad, waves, money,
  guns, upgrades, extension
- [CPU tanks](#cpu-tanks)
- [Controls and devices](#controls-and-devices)
- [Leaving a round](#leaving-a-round)
- [After the round](#after-the-round): ranks, experience, rating,
  leaderboard
- [Balance](#balance): simulated win rates

## Getting started

- **Start page.** The game opens on a start page that picks single player,
  multiplayer or defense, with the call sign at the top. The call sign is
  changed on the account page and only taken with the tick or Enter.
  LAST PLAYED (from tablet width, next to the briefing) starts a solo
  round straight away with the vehicle and level used last.
- **Guests and accounts.** Everybody starts as a guest. A guest plays
  unranked: no experience, rating, badges or vehicles beyond the first
  three, and no place on the leaderboard. The account page signs in or
  registers with an e-mail address; signing in with a new address creates
  the account. The account keeps the guest's id, so whatever was recorded
  before guests were left out stays. If the mail link fails to sign in in
  this tab, a welcome page explains why and takes the code from the mail
  instead.
- **Tutorial.** A button on the start page and in the waiting room opens
  it; it never opens by itself, but the button stands out until the
  player has been through it once. It first explains the controls of the
  device it runs on (touch sticks with an animated thumb on phones and
  tablets, keys and mouse on a desktop, remote or controller on a
  television), each acted out on a small training ground, then gives a
  quick tour of modes, vehicles, crates, gems, weather, levels, defense
  and what comes after the round.
  - A card moves on by itself after at least 7.2 s (controls) or 5 s
    (tour), longer for a long text (`TutorialOverlay.cardTime`), because
    testers found cards leaving before they had read them.
  - On a controls card the player can take over at any time: touching the
    sticks, pressing a game key or clicking turns the scene into a
    training ground with their own tank and a task (drive into the ring,
    three hits, grenades on the special weapon card). The card then shows
    the task and its progress; once done, NEXT lights up in amber and the
    card waits for the player instead of moving on.
  - The sticks and buttons sit where and as large as the game draws them.
    On a television the remote's swipes never turn the card, and a click
    presses the button in focus (while practising it fires).

## Game modes

| Mode | Code | Who plays | How it ends |
| --- | --- | --- | --- |
| Single player | `GameMode.solo` | one person against 1 to 4 CPU tanks | last tank standing |
| Multiplayer | `GameMode.multi` | people, free for all or red against blue, CPU tanks on request | last tank or team standing |
| Defense | `GameMode.defense` | a squad of people and CPU comrades against waves | after the last wave, or when the base falls |
| Capture the flag | `GameMode.flag` | red against blue, CPU tanks fill up to 3 a side | 3 captures, or the side ahead after 8 minutes |

### Single player

Alone against 1 to 4 CPU tanks (`GameConfig.minBots`, `maxBots`) on one of
three [difficulty levels](#difficulty-levels). Alone the countdown takes 2 s
instead of 3. The waiting room shows difficulty, terrain and mode in one
line that opens the settings.

### Multiplayer

- **Free for all or red against blue.** CPU tanks fill the field on
  request, and always when the host starts alone: up to four tanks in all
  (`GameConfig.fillTo`), and always at least as many CPU tanks as people
  (`botsFor` in [`bot_level.dart`](../lib/src/game/bot_level.dart)).
- **Picking sides.** In red against blue a picked side stays picked. People
  on AUTO are spread by the rank of their vehicle, so a new player gets a
  veteran at their side. With CPU tanks to fill up, the strongest and the
  weakest go together to the weaker side, pair by pair; without, each goes
  to the smaller side, the weaker one on a tie. CPU tanks even out the
  sides: on the side with fewer people they first take the vehicles of the
  other side's people that have no counterpart, and the rest come in
  pairs, the same vehicle on both sides.
- **Rooms.** Private rooms by link, code or QR code, public rooms in a room
  list. Late joiners watch the running round.

### Closing zone

In single player and multiplayer the safe circle starts to shrink after
20 seconds, over 90 seconds down to a radius of 120. It holds there for 30
seconds and then draws in to nothing within a minute. Outside it a tank
loses 10 HP a second, plus half a point more for every second since the
zone closed, so every round comes to an end.

### Defense

Tower defense as a squad. Eight waves of enemy tanks, soldiers, aircraft
and drones roll along a road to the base; the players and their CPU
comrades hold them off with their tanks and the guns they build. In short:

- Kills and beaten waves bring coins for guns (key B) and tank upgrades.
  The base hands out ammunition, and destroyed tanks return after 6 s.
- A base that holds well grows from a watchtower to barracks, a fortress
  and a citadel, with more hit points, comrades and guns of its own.
- The host may call the next wave before the break is over (WAVE NOW,
  key N).
- After wave 8 the win is safe. The host may extend by 4 waves at a time,
  up to wave 20: tougher enemies, a fifth step for guns and tank, and the
  rocket launcher. The round ends as a win after the last wave of a
  stretch, or when the host ends it; it ends as a loss when the base falls
  before wave 8 is beaten off.
- If the host leaves for good, the next player in line runs the waves on
  after a few seconds, with the enemies where they were and the host's
  guns still standing.

All numbers are in [Defense in detail](#defense-in-detail).

### Capture the flag

Red against blue on the open field, a base at the left and the right end
with a flag each (`flag_match.dart`, `tank_game/flag.dart`).

- Drive over the other side's flag to take it, and bring it to your own
  base while your own flag stands there.
- 3 captures win. After 8 minutes the side ahead wins; a draw goes into
  overtime until the next capture.
- The carrier drives 15 % slower and cannot use its special weapon. When
  it is destroyed, it drops the flag where it stood. A dropped flag goes
  home when a comrade touches it, or after 20 seconds by itself.
- Destroyed tanks return to their base after 6 seconds. There is no
  closing zone.
- CPU tanks always fill both sides up to three each. Two in three go for
  the flags, one guards the base, and all of them chase whoever carries
  their own flag.
- Each team has its own fuel station and ammunition depot behind its base
  (see [Fuel and ammunition](#fuel-and-ammunition)).
- The round is rated like a team round.

### Two on one screen

On the Apple TV, in the browser and on an iPad two people can play with two
controllers or phones; on a computer also with the keyboard and one
controller or phone. (A phone runs one player and offers neither the split
screen nor the duel.) Single player, multiplayer, defense and capture the
flag play on a split screen, each half following its own tank:

- Single player puts both against 2 to 4 CPU tanks.
- Capture the flag puts both on one side or, as picked in the settings,
  against each other.
- The second half goes by the call sign of the phone that steers it, else
  PLAYER 2.

A local second player sends no extra Supabase Realtime messages; see
[Two players on one screen](platforms.md#two-players-on-one-screen) and
[Televisions](tv.md).

### Duel

A two-on-one-screen variant of defense: red against blue on a defense map,
a base at either end of the road. Each side's waves roll against the
other's base, and guns and tanks fight the other side. Either player can
send an extra tank down the road for 120 coins (`GameConfig.troopCost`).
The whole field shows at once; whose base falls first loses, both at once
is a draw. The duel has no comrades, no air support and no enemy guns.

## Difficulty levels

The level changes the ground and the supplies as well as the CPU tanks. The
CPU values live in [`bot_level.dart`](../lib/src/game/bot_level.dart), the
hills in [`terrain.dart`](../lib/src/game/terrain.dart).

| | Easy | Normal | Hard |
| --- | --- | --- | --- |
| Hills (Bergwald in brackets) | none (7 gentle) | 7 (12) | 13 steeper (17 steep) |
| Fuel and shells | never run out | must be found | must be found |
| Fuel stations, depots, ammunition and jerrycan gems | no | yes | yes |
| Air strike gem | no | no | yes |
| Gentle start (`holdFire`) | 10 s | 8 s | 5 s |
| A person counts as this share of their distance (`humanPull`) | 0.35 | 0.5 | 0.5 |
| CPU time between shots (`fireFactor`) | ×1 | ×1.6 | ×1.4 |
| Largest aim error | 0.24 rad | 0.16 rad | 0.09 rad |
| Reaction before the first shot | 0.8 s | 0.5 s | 0.3 s |
| Lead on a moving target | 40 % | 80 % | 100 % |
| Dodges barrages | no | no | yes |
| Rating of a CPU tank | 800 | 1000 | 1200 |

Hills slow a tank uphill and speed it up downhill. On easy the HUD leaves
the ammunition and fuel gauges out.

To make the first rounds kind:

- A device that never finished a round starts on easy.
- The first round a host starts in a session opens by day under a clear sky
  for at least a minute.
- The level picked last stays on the device (`TankGame.chooseLevel`), so
  LAST PLAYED names the level really played.

What the gentle start and the pull mean is explained under
[CPU tanks](#cpu-tanks).

## Vehicles

Nine vehicles with animal names instead of real model or maker names. The
stats live in [`tank_stats.dart`](../lib/src/game/tank_stats.dart), the
ranks in `TankType` in
[`components/tank_painter.dart`](../lib/src/game/components/tank_painter.dart).
Every vehicle a higher rank unlocks adds up to more over its four lobby
bars (armour, speed, turning, firepower) than every one before it; a test
keeps it so.

| Vehicle | Role | Rank | Armour | Speed | Damage per shot | Barrels | Seconds per shot | Per second | Magazine |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Hermelin | infantry fighting vehicle | 1 | 100 | 1.05 | 8 | 1 | 0.17 | 47 | 90 |
| Fuchs | wheeled armoured vehicle | 1 | 70 | 1.35 | 11 | 1 | 0.26 | 42 | 55 |
| Spitzmaus | weapon carrier (anti-tank missile) | 1 | 60 | 1.5 | 38 | 1 | 1.2 | 32 | 14 |
| Habicht | anti-aircraft | 2 | 105 | 1.05 | 9 | 2 | 0.26 | 69 | 45 |
| Keiler | main battle tank | 3 | 165 | 0.95 | 33 | 1 | 0.52 | 63 | 20 |
| Hirsch | self-propelled howitzer (155 mm) | 4 | 185 | 0.95 | 75 | 1 | 1.05 | 71 | 12 |
| Dachs | infantry fighting vehicle (35 mm) | 5 | 135 | 1.15 | 14 | 1 | 0.2 | 70 | 70 |
| Igel | rocket launcher | 6 | 160 | 1.1 | 12 | 4 | 0.65 | 74 | 18 |
| Wolf | main battle tank (130 mm) | 8 | 190 | 1.0 | 50 | 1 | 0.64 | 78 | 16 |

Speed is a factor on the shared top speed of 216. "Per second" assumes
every shot lands. A salvo of a multi-barrel gun counts once against the
magazine.

- **Habicht** is the only tank that hits aircraft properly: its shells do
  double damage to helicopters and jets, like flak.
- **Igel** fires four rockets a salvo side by side, a wide spread that hurts
  most up close. From wave 6 of a defense round it also rolls in among the
  enemies, in one slot of ten.
- **Paint.** Four free paint schemes and four more that come with ranks
  3, 5, 7 and 10, for playing alone. With others every tank drives in its
  own colour, and in red against blue (teams, capture the flag) in its
  team's red or blue, so the lobby offers no camouflage then. In defense
  the defenders are red and the attackers blue; in a duel each player sees
  their own side red (two players on one screen: the left base red).
- **Rings.** A ring in the team's colour shows only around hulls of
  another colour, and while a hit flashes the hull white. The own tank
  always wears a ring (team colour, or amber without sides) with a dark
  rim, so it stands out among its side.
- The lobby lists the unlocked vehicles first.

## Maps, weather and terrain

**Grounds.** Six battle grounds
([`map_theme.dart`](../lib/src/game/map_theme.dart)): Gefechtsplatz
(training ground), Wüste (desert), Winter, Stadt (city), Bergwald and
Inseln.

- *Bergwald* (mountain forest): dense conifers, scree that slows, and hills
  on every level, also on easy.
- *Inseln* (islands, [`island_shape.dart`](../lib/src/game/island_shape.dart)):
  more water than land. Seven islands of organic shape, laid out by the
  seed: a middle one where the closing zone ends, and six around it that
  carry the start positions (the ones at 0 and 180 degrees hold the flag
  bases). Wooden bridges join every island of the ring to its neighbours,
  and the middle to both flag islands. Along every shore runs a strip of
  shallow water (46 units) that tanks wade through at 45 % of their speed;
  beyond it the water is deep and blocks tanks like a river bank, while
  shells fly over. CPU tanks route over the fewest bridges
  (`IslandShape.waypoint`). Starts, depots and crates are moved onto land,
  and soldiers, trees and houses keep to it.

**Defense maps.** Six maps with a river, bridges, woods and farm houses
([`defense/defense_map.dart`](../lib/src/game/defense/defense_map.dart)).
The two newer ones are *Flussufer* (along the river bank, crossing near the
top) and *Haarnadel* (in from the top, two hairpins across the river).

**Content level.** The two newer grounds and the two newer defense maps
only come up in a room where every client knows them; a newer ground
picked for a room with an older client gives way to one of the first
four. See [Content level](netcode.md#content-level) in the netcode
guide.

**Weather and daylight** ([`weather.dart`](../lib/src/game/weather.dart)).
Each ground has weather (clear, rain, snow, sandstorm or fog) that may turn
during a round. Day and night take turns at a fixed pace: 80 seconds of
day, 40 of night. Night, fog and sand limit the view to a circle around
the tank.

## The battlefield

### Obstacles and soldiers

- Buildings, barriers and trees can be shot down. Mud slows tanks.
- Soldiers on foot patrol and fight. In a team round the squads are red or
  blue and shoot at tanks and at each other. They can be shot or run over.
  Their numbers are under [Soldiers](#soldiers).
- Paratroopers drop in, where and when the seed says: five drops of four,
  the first 18 s into the round, then every 22 s.

### Fuel and ammunition

From the normal level on, fuel and shells run out. A full tank lasts
95 seconds at full throttle (standing still burns 15 % of that), and an
empty tank crawls at 30 % speed. Magazine sizes are in the
[vehicle table](#vehicles).

- **Gems.** A blue ammunition gem refills 60 % of the magazine, a jerrycan
  65 % of the tank.
- **Fuel stations and ammunition depots** (`tank_game/supply.dart`) stand
  in single player, multiplayer and capture the flag. Defense has its base
  for that: within 130 of it a magazine refills in 4 s.
  - A tank that stands still on the pad fills up, a full tank or magazine
    in 6 s. Rolling over it only shows the hint to stop.
  - A free for all gets four neutral ones from the seed, fuel and
    ammunition by turns on a ring inside the start positions, so the
    closing zone swallows some of them.
  - In capture the flag each team has one of each behind its base that
    serves only its own tanks. Its own shells fly over them; the enemy can
    shoot them.
  - A depot takes 160 damage from shells, blasts and barrages, then blows
    up and hurts tanks within 110 (45 damage, half at the edge; the tank
    that brought it down gets the kill). It stands again after 45 s.
  - CPU tanks drive there when they run low, top up at one close by and
    leave when an enemy comes near.
  - Over the network a depot rides on the `obstacle` event (flag `d`, the
    shooter as `id`).

## Crates, gems and the inventory

Crates and gems drop on the field (the first after 5 s, then every 6 s; in
defense after 10 s, then every 9 s). They do not act when picked up: they
go into an inventory at the left edge (6 slots, up to 5 of a kind) and are
set off later with the keys 1 to 6 or a tap. Every gem carries a symbol of
what it holds, and only filled slots show. The kinds and their odds are in
[`components/power_up.dart`](../lib/src/game/components/power_up.dart).

| Item | Kind | What it does | Levels |
| --- | --- | --- | --- |
| Repair | crate | +40 armour | all |
| Smoke launcher | crate | a smoke cloud (radius 130, 10 s) thrown up to 300 ahead | all |
| Rapid fire | crate | 45 % of the time between shots for 8 s | all |
| Shield | crate | lets 40 % of damage through for 8 s | all |
| Mines | crate | 3 mines | all |
| Artillery | crate | one barrage | all |
| Ammunition | gem | refills 60 % of the magazine | normal, hard |
| Jerrycan | gem | refills 65 % of the fuel | normal, hard |
| Grenade launcher | gem | special weapon, 3 shots | all |
| Mortar | gem | special weapon, 4 shots | all |
| Drone | gem | special weapon, one kamikaze drone that hunts the nearest enemy | all |
| Hunter drone | gem | a drone after an enemy picked at random, wherever it is | all |
| Infantry | gem | a squad on foot that fights next to the tank | all |
| Paratroopers | gem | a drop of 4 rocket launchers up to 420 away | all |
| Air strike | gem | a bomber drops 4 bombs on the enemy nearest the aim | hard |

The special weapons fire with F or the touch button. Their damage is in
the next section.

## Weapons and damage

All values are hit points. Blasts do their full damage at the centre and
half at the edge of the radius. Tank guns are in the
[vehicle table](#vehicles), defense guns in
[Defense in detail](#defense-in-detail).

### Special weapons and crates

| Weapon | Damage | Radius | Range | Uses |
| --- | --- | --- | --- | --- |
| Grenade launcher (gem) | 45 | 85 | 90–380 | 3 |
| Mortar (gem) | 55 | 95 | 140–560 | 4 |
| Kamikaze drone (gem) | 60 | 75 | hunts by itself, 10 s | 1 |
| Hunter drone (gem) | 60 | 75 | after a random enemy, 18 s | 1 |
| Artillery (crate) | 45 | 110 | up to 360 | 1 barrage |
| Air strike (gem, hard) | 49.5 per bomb | 110 | up to 700 | 4 bombs |
| Mines (crate) | 35 | 12 | where the tank stands, armed after 1 s | 3 mines |

A bomb, whether from a jet or the air strike, is a tenth harder than an
artillery shell.

### Soldiers

| | Damage | Every | Range |
| --- | --- | --- | --- |
| Rifle | 1 | 1.3 s | 220 |
| Rocket launcher | 18 | 4 s | 300 |

A rifle is deadly to soldiers and does little to tanks. A squad has four
riflemen and one rocket launcher.

- **Patrol.** Squads off the road (from the seed, paratroopers, gems)
  patrol up to 220 around where they stand at a walk (26 a second),
  keeping clear of houses.
- **Stalking.** Once an enemy tank out of the smoke, or an armed soldier of
  the other side, comes within 520, they stalk it at 46 a second to three
  quarters of their reach (165 for riflemen, 225 for rocket launchers) and
  hold there while they fire. 6 seconds after losing sight of it they
  patrol again where they stand.
- **Paths.** Every line a squad walks is checked along its length. A patrol
  keeps to points it reaches dry. A squad sent across the river of a
  defense map or between islands takes the nearest bridge, and stops at
  the shore when no bridge leads there. Squads marching down the road of a
  defense round keep to the road.

### What softens a hit

- A shield lets 40 % through.
- Every armour upgrade takes 15 % off (10 % for steps 4 and 5), and a
  trench halves what is left. Every gun upgrade adds 15 % to the tank's
  shells.
- Against aircraft, flak and the Habicht do double; other shells do 40 %
  to a helicopter and nothing to a jet.
- On the ground flak does only 30 % of its damage, about a quarter of what
  a cannon fires in the same time, so a row of flak cannot hold the road.
  Against the sky it is sharper: its shells burst within 30 of an aircraft
  or drone, the mount swings 10 radians a second (the other guns 6), and
  every gun works out its lead a few times over. A jet at 420 a second used
  to slip through three flak guns around the base; now one flak gun stops
  it about one time in three before it bombs, two almost always.

## Defense in detail

The numbers that decide how a defense round grows. They live in
[`game_config.dart`](../lib/src/game/game_config.dart), the waves in
[`defense/defense_director.dart`](../lib/src/game/defense/defense_director.dart)
and `DefenseMap.planFor`, the guns in
[`defense/tower.dart`](../lib/src/game/defense/tower.dart). The host runs
the waves; see [netcode.md](netcode.md) for how that is shared.

### The base

It starts with 1500 hit points. A wave counts as *held well* when the base
loses at most 15 % of its current maximum during it. The count of such
waves decides how far the base has grown:

| Stage | Waves held well | Hit points | Comrades | Guns per player | Guns on the base | Own squads per wave |
| --- | --- | --- | --- | --- | --- | --- |
| Watchtower | 0 | 1500 | start value | 6 | none | 1 |
| Barracks | 2 | 2000 | +1 | 8 | cannon | 2 |
| Fortress | 4 | 2500 | +2 | 10 | cannon (level 2), flak | 3 |
| Citadel | 7 | 3000 | +3 | 12 | cannon (level 3), flak (level 2), rockets | 4 |

The 500 hit points of each step are added right away. A bad wave does not
reset the count; the base only waits longer for the next step. The base's
own guns cannot be hit, bought or upgraded. Its own squads march down the
road against every wave, 4 s apart; from the fortress on each carries two
rocket launchers instead of one.

### The squad

CPU comrades fill the squad up to 4 tanks, and at least one joins even a
full room. A destroyed comrade rolls out of the base again after 10
seconds. A comrade's vehicle follows the wave it rolls out in, by the same
rules as the enemy's tanks below. With an older client in the room every
slot keeps its fixed vehicle (Keiler, Hermelin, Habicht, Keiler, Fuchs).

### The waves

The first wave comes 8 s after the start, the next 12 s after a wave is
beaten off. Wave *w* brings 3 + 2*w* tanks, at most 6 of them on the road
at once, one every 1.6 s. A squad leads, aircraft come in between the
tanks, drones last.

| Wave | Tanks | Squads | Helicopters | Jets | Drones |
| --- | --- | --- | --- | --- | --- |
| 1 | 5 | 1 | 0 | 0 | 0 |
| 2 | 7 | 1 | 1 | 0 | 0 |
| 3 | 9 | 2 | 1 | 1 | 0 |
| 4 | 11 | 2 | 1 | 1 | 1 |
| 5 | 13 | 2 | 2 | 1 | 1 |
| 6 | 15 | 3 | 2 | 2 | 2 |
| 7 | 17 | 3 | 2 | 2 | 2 |
| 8 | 19 | 3 | 3 | 2 | 3 |
| 12 | 27 | 5 | 4 | 4 | 5 |
| 16 | 35 | 6 | 5 | 5 | 7 |
| 20 | 43 | 7 | 7 | 6 | 9 |

- **Enemy vehicles** (`DefenseMap.enemyType`): Fuchs and Hermelin from the
  start, Habicht from wave 3, Dachs from 4, Keiler from 5, Igel from 6 (in
  place of a Fuchs, only in rooms where everybody knows it), Wolf from 7.
  Enemy tanks drive at 60 % speed and fire three times slower than a
  player.
- **Enemy squads** have four riflemen, plus a rocket launcher from wave 3.
- **At the base.** An enemy tank that reaches the base blows itself up and
  does 120 damage per 100 of its armour; a soldier does 25.
- **Helicopters** (120 HP) fire a rocket of 10 every 1.8 s up to 420.
  **Jets** (80 HP, 420 a second) drop 3 bombs of 49.5 on the base.
  **Enemy drones** do 60 in a radius of 75.

**The last helicopter.** Once no enemy tank is left, an enemy helicopter
holds the wave open on its own. It then seeks out the nearest defender or
gun anywhere on the field and keeps only 150 away instead of 260, so it
comes into view and into the flak. With nothing else in range the aim
assist and the comrades take a helicopter on with tank shells (40 %), so
the wave ends without flak too. This matters on the Apple TV, where the
remote aims only through the assist.

**Air support.** From wave 3 the base sends an attack helicopter every
wave, which stays 40 seconds. From wave 5 a jet follows 14 seconds into
the wave and bombs the enemy closest to the base.

**The enemy's guns.** From wave 3 the enemy digs in guns beside the first
stretch of the road, one more every second wave up to 4 (wave 3: 1,
wave 5: 2, wave 7: 3, wave 9: 4), cannon and flak by turns, on fixed spots
between 14 % and 36 % of the road. They start at level 1, rise a level
every third wave and fire at 1.8 times the players' interval, at tanks,
guns, soldiers and (the flak) the base's aircraft. Every new wave rebuilds
the destroyed ones. Whoever hit one last on their own screen gets its
bounty. The host fires them (`tower` and `shoot` events with the id
`td-g`); not in a duel.

### Money

150 coins at the start and 50 for every wave beaten off. Kills bring a
bounty to the player who made them, rising from the wreck. Bounties shrink
with the waves: in wave *w* they are the first wave's divided by
1 + 0.2 × (*w* − 1), rounded, at least 1.

| Kill | Wave 1 | Wave 3 | Wave 8 |
| --- | --- | --- | --- |
| Tank | 20 | 14 | 8 |
| Aircraft | 40 | 29 | 17 |
| Soldier | 5 | 4 | 2 |
| Enemy gun | 60 | 43 | 25 |

The waves grow, so a whole wave pays about the same, but the guns get
dearer. When the coins first reach a gun or an upgrade, a notice says so
once, and a dot on *Guns* and *Upgrades* shows it.

### Guns and trenches

| Kind | Cost | From wave | Hit points (level 1) | Damage | Every | Range | Job |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Cannon | 100 | 1 | 240 | 18 | 0.45 s | 420 | tanks |
| Flak | 120 | 1 | 200 | 6 (12 vs aircraft, 1.8 on the ground) | 0.16 s | 600 | aircraft and drones |
| Mortar | 150 | 1 | 200 | 50, radius 75 | 2.4 s | 130–620 | area fire |
| Howitzer | 220 | 4 | 300 | 110, radius 75 | 4.2 s | 240–1050 | heavy area fire |
| Trench | 60 | 2 | 360 | 3 | 0.35 s | 260 | infantry; covers a tank |
| Rockets | 260 | extension | 260 | 42 (84 vs aircraft) | 1.4 s | 640 | tanks and aircraft |

- **Prices.** The price is for the first of a kind. Every further one of
  the same kind a player already has adds 30 % of it (flak 120, 156, 192,
  …), so a wall of one kind gets dear. The buttons show the current price
  and are bright when affordable. B, R1 or the remote's button builds the
  kind built last, and the key hint above the list names it.
- **Levels.** Guns have three levels, five in the extension. Each level
  adds 30 % hit points, 35 % damage and 12 % range, and fires 15 %
  faster. The step from level *n* costs 75 % of the gun's price times *n*
  (cannon: 75, then 150).
- **Wear.** Enemy shells, bombs, barrages and drones wear guns and trenches
  down, and enemy tanks and helicopters go for them when no tank is near.
  A destroyed gun frees its place.
- **Aim.** Guns keep off the road. Every gun leads its aim; the mortar and
  the howitzer lead their shell by its flight time of 1.3 s.

**Trenches.** Up to 4 per player; they do not count as guns and have no
levels.

- On the road a trench is dug across it from edge to edge (not on a
  bridge); beside the road it runs along it.
- Four men sit in it, three with rifles and one with a machine gun. They
  take turns firing (one shot every 0.35 s for the whole trench), at
  soldiers first and tanks after, each man aiming from where he sits. One
  man falls with every quarter of its hit points, and the fire slows with
  him.
- From wave 4 the first man, the last to fall, also carries an anti-tank
  rocket launcher: 30 damage every 3 seconds at the nearest enemy tank
  within 300.
- Enemy shells hit a trench along its length, unless a tank of its side
  sits in it: that tank takes the shell, halved.
- Tanks of either side crawl over a trench at a quarter of their speed and
  stay that slow for 1.5 seconds after. Soldiers march on through it. Only
  a tank of the side that dug it takes cover there.

### Tank upgrades

Coins also buy upgrades for the own tank
([`upgrades.dart`](../lib/src/game/upgrades.dart)), one list at a time in
the panel. They last for the round.

| Upgrade | Per step | Cost of steps 1, 2, 3 (4, 5 in the extension) |
| --- | --- | --- |
| Armour | −15 % damage taken (steps 4 and 5: −10 %) | 80, 160, 240 (320, 400) |
| Gun | +15 % damage | same |
| Engine | +8 % top speed | same |
| Magazine | +30 % ammunition | same |

### The extension

After the last of the 8 regular waves the host has 25 seconds to add 4
more waves; without an answer the round ends as a win. After those 4 the
same question comes again, and after wave 20 the round is over whatever
happens; endless waves left no clear end in play tests. The host may also
end the secured round at any time, mid-wave too, through the exit button,
whose question then offers *Win · end*.

In the extension guns and tank upgrades go up to level 5, the rocket
launcher can be built, and every wave past the 8th makes enemy tanks 12 %
tougher (damage taken divided by 1 + 0.12 per extra wave). If the base
falls, the round is still a win. Every extra wave beaten off earns
experience (see [After the round](#after-the-round)).

### Defense screen

On a desktop the camera may run past the field's edge by the width of the
mini map, so the base at the end of the road never hides under it, and
the defense panel keeps clear of the mini map.

## CPU tanks

The CPU tank logic is in [`bot_brain.dart`](../lib/src/game/bot_brain.dart)
and [`bot_items.dart`](../lib/src/game/bot_items.dart); defense comrades and
enemies use [`defense/ally_brain.dart`](../lib/src/game/defense/ally_brain.dart)
and [`defense/defense_brain.dart`](../lib/src/game/defense/defense_brain.dart).

- **Gentle start.** For the first 10, 8 or 5 s of playing time (easy,
  normal, hard) CPU tanks leave people alone and only fight each other,
  unless a person hits them first, and the aim assist only aims without
  firing (`TankGame.ceasefire`). A play test found new players destroyed
  within ten seconds, before they had found the sticks.
- **Pull towards people.** After that a person counts as nearly three
  times closer (easy) or twice as close (normal, hard) as another CPU tank
  when a CPU tank picks a target (`BotLevel.humanPull`). Left to the
  nearest target, the CPU tanks fought each other while a player waited;
  pulled too hard, they all went for the player at once.
- **Same vehicles as the people** (`GameConfig.mirrorStyle`). Alone every
  CPU tank comes in the player's vehicle; with several people each draws
  from theirs; in red against blue the n-th CPU tank of each side gets the
  same one. A new player in a starter meets starters, a pilot in a Wolf
  meets Wolves. Fixed starters left every higher rank with weak opponents
  (see [Balance](#balance)).
- **Slower fire.** On normal and hard they take 1.6 and 1.4 times as long
  between shots as a person in the same vehicle (`BotLevel.fireFactor`).
- **Sight.** At night, in fog or sand CPU tanks fire at people only as far
  as those can see (`BotBrain.reach`), since there is no arrow for a tank
  beyond sight.
- The aim assist is there on every level; without it hard could hardly be
  won on a phone.

## Controls and devices

- **Keyboard and mouse.** Drive with the keys, aim and fire with the mouse,
  F for the special weapon, 1 to 6 for the inventory; in defense B builds
  and N calls the next wave.
- **Touch.** Two sticks on phones and tablets. The left stick points where
  the tank should go, the right one aims and fires. The aim assist (on by
  default, switched with a button right above the aim stick) turns the
  turret onto the nearest enemy within 420 and fires while the right thumb
  rests. Each stick follows the thumb that landed first in its zone, also
  when it slides over the buttons. Upright phones look 20 % closer
  (`GameConfig.uprightPhoneZoom`), outside defense rounds.
- **Game controllers.** One controller steers the own tank in the browser,
  on iPhone, iPad, Android and televisions; two play two on one screen. A
  touch on a phone or tablet brings the touch sticks back over a
  connected controller (`TankGame.touchOverPad`) until the controller is
  used again.
- **Phone as a controller**
  ([`net/pad_link.dart`](../lib/src/net/pad_link.dart)). The account page
  in the browser shows a pairing QR code; the app on a phone scans it
  (Account, Use as controller). The phone shows the two sticks, armour,
  shells, fuel and the inventory, and in defense the coins and the shop
  (*Build*: guns and upgrades; *Round*: the host's *Wave now*, *+4 waves*
  or *End*). Hits are felt as a buzz. Only the app on a phone (shorter
  side under 600 points) becomes a controller: tablets and browsers point
  to the app instead. The browser game pairs controllers, it never is one.
- **Other devices.** The [Apple TV](platforms.md#apple-tv) and other
  [televisions](tv.md) play with the remote or a controller; the
  [Apple Vision Pro](platforms.md#apple-vision-pro) runs the iPad app with
  look-and-pinch; there are watch apps for
  [Apple Watch](platforms.md#apple-watch) and
  [Wear OS](platforms.md#wear-os), and an
  [iOS widget](platforms.md#home-screen-widget) with the pilots online.
- **On screen.** Visible battle damage, hit sparks, screen shake, a kill
  feed, a mini map and markers for enemies off screen that slide along the
  edge past the gauges and panels. The mini map of the battle modes leaves
  out woods, mud and barriers, fades the buildings and shows crates and
  gems only within 450 of the own tank.

## Leaving a round

- Escape, or the small exit button next to the sound button, asks whether
  to leave the running round. Escape again or *Keep playing* takes it back,
  Enter or *Leave* goes. The round runs on behind the question; it cannot
  be paused for the others.
- Leaving records nothing, neither a defeat nor experience or badges, and
  the question says so. Once a defense is won (after wave 8) the host's
  question offers ending the round as a win instead.
- Alone with CPU tanks the player goes straight back to the waiting room.
  With other people the player leaves the room too, and the others see the
  tank go like a pilot who closed the tab.
- On the end screen Escape goes back to the waiting room; in a replay it
  ends the replay.
- The Apple TV keeps its Menu button from throwing anybody out of a round
  and shows no exit button.

## After the round

- **End screen.** A rematch button and a replay of the last round. With
  other people the end screen goes back to the waiting room after 15 s and
  counts down on its button; alone it stays until the player picks. A lost
  battle with more than two tanks shows the place ("PLACE 3 OF 5").
- **Replays.** The replay's bar at the top has *Next tank* and *Whole map*
  (key M), which holds the camera still over the whole field instead of
  following a tank; the choice stays for the next replay.
- **Ranks** ([`progress.dart`](../lib/src/game/progress.dart)). Every rank
  starts from 0 and rank *n* needs 120 × *n*² to the next (120 to rank 2,
  5880 from rank 7 to 8); the card counts within the rank. Ranks unlock
  vehicles and paints. There are ten badges.
- **Experience per round**, computed by the `record_round` function
  (latest in
  [`supabase/migrations/0022_wave_xp.sql`](../supabase/migrations/0022_wave_xp.sql)).
  Holding out counts, in a lost round too:

  | For | Experience |
  | --- | --- |
  | Playing the round | 10 |
  | Each kill (up to 15) | 20 |
  | Damage dealt | 1 per 10 (up to 200) |
  | Winning | 50 |
  | Each opponent outlasted, people and CPU tanks (in a team round the whole beaten team) | 10 |
  | Each defense wave beaten off beyond the eighth | 30, or 15 when the base fell in the end |

  Holding out to wave 20 brings 360 on top, falling in wave 20 still 165.
  Waves count only with a round ticket and at most one per 15 s of the
  round's time.
- **Elo rating.** The pilot is compared pairwise with every opponent: won
  against those who went down earlier, lost against those who outlasted
  them. So the second to last loses far less than the first one out.
- **Leaderboard points**
  ([`db/score_points.dart`](../lib/src/db/score_points.dart)) weigh every
  total a pilot has, so more rounds, wins and kills always count: 10 per
  round, 50 per win, 20 per kill, 1 per 20 damage, up to 20 per round for
  accuracy (hits per shot, only shells out of the own gun), 1 per 30 s
  alive, and twice the rating's distance from the start of 1000 once a
  rated round moved it. Never below zero. Ties go to the rating, then
  wins, then kills. The rating alone ranked badly: it only moves in rounds
  with a rated opponent, so one even round outranked a dozen rounds with
  eleven wins.

## Balance

[`test/game/balance_sim_test.dart`](../test/game/balance_sim_test.dart)
plays solo rounds with a stand-in for the player on a faked round clock:
idle, idle with the aim assist (a phone player who only waits), and a
player who drives and shoots like a CPU tank of the easy or normal level.
Against 1 to 4 CPU tanks (2.5 on average) an even fight wins about 29 % of
the rounds. It is skipped in the normal test run; this starts it:

```sh
flutter test test/game/balance_sim_test.dart --run-skipped --dart-define=ROUNDS=60
```

The rounds open by day, so night and fog are not part of it.

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

**Defense builds.**
[`test/game/defense/trench_balance_sim_test.dart`](../test/game/defense/trench_balance_sim_test.dart)
(skipped as well; run it with `--run-skipped --dart-define=ROUNDS=8`, and
`--dart-define=WAVE=5` for a later wave) puts one build a third of the way
down the road and sends three squads on foot (15 men) and two tanks of the
wave past it, without comrades and without the director's waves. Measured
October 2026, 8 rounds each, with the trench's rocket man (wave 4 on), the
slowdown after crossing and the mortar leading its shells:

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
tanks, so the price of 60 holds. The runs also found three bugs, all
fixed: shots aimed from the middle of a trench flew past men close by (now
every man aims for himself), no gun led its aim on soldiers, and trenches
took no shells, only blasts.

The mortar first earned a third of its price (49 in wave 3), let every
tank through and left 14 hits on the base. It aimed at where its target
stood, but its shell is 1.3 s in the air: a tank on the road had moved on
by more than the blast radius of 75 when it landed. Now it leads its shell
by the flight time and stops tanks as well as the cannon does. The cannon
stays the cheaper answer to one road; the mortar's extra price pays for
its reach of 620 against 420, fire over cover and a blast that catches a
whole squad, which a single build on one stretch does not show. The
howitzer fires the same shell and leads it the same way.
