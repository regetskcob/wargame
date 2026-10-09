# Gameplay in detail

Everything the game does, with the numbers behind it. The short version is in the [README](../README.md).

## Getting in

- The game opens right on the start page that picks single player,
  multiplayer or defense, with the call sign at the top to see and change
  it. Everybody starts as a guest; the account button next to it signs in
  or registers with an e-mail address. Signing in with an address that has
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
  weather, levels, the defense mode and what comes after the round.

## Ways to play

- **Single player:** alone against 1 to 4 CPU tanks on three levels.
- **Multiplayer:** free for all or red against blue, with CPU tanks to fill
  up the field on request. Private rooms by link, code or QR code, public
  rooms in a room list, and late joiners can watch the running round.
- **Defense (tower defense):** together against 8 waves of enemy tanks that
  roll along the road to the base. CPU comrades fill the squad, and later the
  base sends aircraft of its own. Kills bring money for guns (key B), the
  base hands out ammunition, and destroyed tanks return after a short time.
  A base that holds well grows from a watchtower to barracks to a fortress.
  After wave 8 the win is safe and the host may extend: endless waves with
  tougher enemies, a fifth step for guns and tank, a rocket launcher and a
  citadel, until the base falls (still a win) or the host pulls out.
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
  with two controllers or phones. Single player, multiplayer and defense
  play on a split screen, each half from its own tank; single player puts
  both against the CPU tanks. Free of Realtime messages, see
  [Apple TV](platforms.md#apple-tv).
- **Duel (two on one screen):** red against blue on a defense map, a base
  at either end of the road. Each side's waves roll against the other's
  base, guns and tanks fight the other side, and either player sends extra
  tanks. Shown on the whole field at once, whose base falls first loses.

## On the battlefield

- Eight vehicles with animal names instead of real model or maker names
  (Hermelin, Fuchs, Spitzmaus, Habicht, Keiler, Hirsch, Dachs and
  Wolf), each with its own armour, speed and gun. Hermelin, Fuchs and
  Spitzmaus are there from the start, the others come with ranks 2, 3, 4, 5
  and 8, and every later one is stronger than the ones before. The lobby
  lists the unlocked ones first. Four free paint schemes and four more that come with higher ranks.
- Four grounds (Gefechtsplatz, Wüste, Winter, Stadt), each with weather
  (clear, rain, snow, a sandstorm or fog) that may turn during a round, and
  day and night taking turns at a fixed pace: 80 seconds of day, 40 of
  night. Night, fog and sand limit the view to a circle around the tank.
- Buildings, barriers and trees that can be shot down, and soldiers on foot
  that fight: in a team round the squads are red or blue and shoot at tanks
  and at each other. They can be shot or run over.
- Limited ammunition with blue gems to refill it, and gems for a grenade
  launcher, a mortar, a kamikaze drone, a squad on foot and a drop of
  paratroopers with rocket launchers.
- Crates with repair, smoke, rapid fire, a shield, mines and artillery.
- Crates and gems go into an inventory at the left edge and are set off
  later with the keys 1 to 6 or a tap. Every gem carries a symbol of what
  it holds.
- Three levels that change more than the CPU tanks: on easy the ground is
  flat and fuel and shells never run out. On normal the land gets hilly
  (slower uphill, faster downhill) and fuel and shells must be found, fuel
  in canister gems. On hard the hills are steeper and an air strike gem
  sends a bomber over an enemy. A hunter drone gem launches a drone after a
  random enemy.
- Defense on four maps with a river, bridges, woods and farm houses. The
  waves bring tanks, soldiers on foot, attack helicopters, jets that bomb
  the base and kamikaze drones. Cannons, flak (the only thing besides the
  Habicht that hits aircraft properly), mortars and later howitzers, three
  levels each, trenches that cover a tank, and armour, gun, engine and
  magazine upgrades for the tank. The enemy shoots guns and trenches to
  pieces.
- On iOS a widget with the pilots online, a Live Activity for the running
  round, and an Apple Watch version in progress, see [Apple Watch](platforms.md#apple-watch).
- Visible battle damage, hit sparks, screen shake, a kill feed, a mini map
  and markers for enemies off screen.
- Keyboard and mouse, or two touch sticks on phones and tablets. The left
  stick points where the tank should go, the right one aims and fires, and
  an aim assist (on by default, switched with a button) turns the turret
  onto the nearest enemy while the right thumb rests.
- The phone as a controller for the game on a computer or tablet: the
  account sheet in the browser shows a pairing QR code, the app scans it
  (Account, Use as controller) or the phone camera opens it. The phone then
  shows the two sticks, the special weapon, the items and, in a defense
  round, the gun buttons, and feels hits as a buzz. Without the app the
  phone's browser does the same.
- Game controllers: one steers the own tank in the browser, on an iPad and
  on the Apple TV, as a paired phone does; two play two on one screen.
- An Apple TV app, played with the Siri Remote or a controller, with menus
  that fit the television without scrolling, see [Apple TV](platforms.md#apple-tv).

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
seconds up to 300.

**Defense.**

| Who | Damage | Notes |
| --- | --- | --- |
| Cannon | 18 per shot, 0.45 s, range 420 | +35 % per level |
| Flak | 6 per shot, 0.16 s, range 480 | double against aircraft |
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
shells a quarter to a helicopter and nothing to a jet.

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
seconds.

**Air support.** From wave 3 the base sends an attack helicopter every wave,
which stays 40 seconds. From wave 5 a jet follows 14 seconds into the wave
and bombs the enemy closest to the base.

**Money.** 150 at the start, 20 per tank, 40 per aircraft, 5 per soldier and
50 for every wave beaten off.

**Guns and trenches.**

| Kind | Cost | From wave | Hit points (level 1) | Job |
| --- | --- | --- | --- | --- |
| Cannon | 100 | 1 | 240 | tanks |
| Flak | 120 | 1 | 200 | aircraft and drones |
| Mortar | 150 | 1 | 200 | area fire up to 620 |
| Howitzer | 220 | 4 | 300 | heavy area fire up to 1050 |
| Trench | 60 | 2 | 360 | a tank in it takes half damage |
| Rockets | 260 | extension | 260 | tanks and aircraft, range 640 |

Each upgrade adds 30 % hit points, 35 % damage and 12 % range and fires 15 %
faster; trenches have no levels. Enemy shells, bombs, barrages and drones
wear guns and trenches down, and enemy tanks and helicopters go for them
when no tank is near. A destroyed gun frees its place. Up to 4 trenches per
player, they do not count as guns.

**The extension.** After the last of the 8 regular waves the host has 25
seconds to extend; without an answer the round ends as a win. Extended, the
waves go on without end and the host may pull out in any break. Guns and the
tank's upgrades go up to level 5 instead of 3 (armour steps 4 and 5 shield
10 % each instead of 15 %), the rocket launcher can be built, and every wave
past the 8th makes enemy tanks 12 % tougher. If the base falls, the round is
still a win.

## Leaving a round

- Escape, or the small exit button next to the sound button (bottom left
  while watching), asks whether to leave the running round; Escape again
  or *Keep playing* takes it back, Enter or *Leave* goes. The round runs on
  behind the question, it cannot be paused for the others.
- Alone with CPU tanks the player is straight back in the waiting room and
  nothing is recorded. With other people in the round the player leaves the
  room too, and the others see the tank go like a pilot who closed the tab.
- On the end screen Escape goes back to the waiting room, in a replay it
  ends the replay. The Apple TV keeps its Menu button from throwing anybody
  out of a round and shows no exit button.

## After the round

- A rematch button on the end screen and a replay of the last round.
- Ranks from experience, an Elo rating, ten badges and one leaderboard of all
  pilots by rating.

