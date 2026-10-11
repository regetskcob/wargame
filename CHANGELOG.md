# Changelog

What each store version of Panzergefecht brought, newest first, as its most
important points. The build number follows in brackets; the web version at
<https://www.regetskcob.de/wargame/play/> is always the latest `main`. The
store texts for a release live in `store/ios/metadata/*/release_notes.txt`.
The German version is [`CHANGELOG.de.md`](CHANGELOG.de.md); keep both in
step, point for point.

## Unreleased

- Ranks take longer: every rank starts from 0 and needs the step the card
  used to show as the total, and the card counts within the rank
- The defense shop marks nothing after use: buttons are only bright when
  affordable or faint; building says what a gun or trench is for, and a
  notice says when the funds start to reach
- The last enemy helicopter of a wave comes in to the defenders instead of
  hanging back far out, and tank shells hurt it a little more
- The replay's end button sits in the bar beside the next tank
- Deleting the account comes last on the account page

## 1.4.1 (10) – 2026-10-11

- Tablets use their screen in the menus: the start page and the waiting
  room start at the top and take the whole width, two columns where there
  is room, vehicle cards that grow with the bars beside them
- Large tablets such as the 13" iPad draw the menus larger, as the HUD
- The account is a page of its own with two columns instead of a sheet
  that scrolled, and one way to close it
- A change of language reaches every text at once, the legal links and the
  pages below the account included
- Tablets no longer show a vibration switch they have no motor for

## 1.4.0 (9) – 2026-10-10

- A calmer, slimmer look: frames only on the outer panels, frameless boxes
  for modes, sections and tank cards, hairline buttons, outlined small icons
- Account sheet: the call sign is saved with the tick or Enter, registering
  takes that name, the language sits in the title line
- Guests find signing in on a card on the start page
- Holding out longer in a lost battle earns experience and shows the place
- The phone as a controller carries the whole defense shop
- Only the app on a phone becomes a controller, never a tablet or a browser
- Two players on one screen: each half wears its team colour
- CPU tanks see no further than people at night, in fog and in sand
- Sounds fade with distance, long defense rounds run smoother, rooms are
  guarded against floods, forged messages and short dropouts
- Apple Watch: every mode alone against CPU tanks, counted for the account
  on the iPhone

### Fixes

- Account: the e-mail field offers the saved address, the keyboard no longer
  stays up after closing the sheet, the language chip follows a tap, the
  call sign's label is no longer cut off
- Rooms: one host when a browser opens its room in two tabs, guests see the
  host's mode in the waiting room, players arriving by a room link count
  against the Realtime budget, an iPad with two paired phones no longer
  floods the server
- Split screen: starts only once the second player is in the round (no
  empty half), frames in team colours, the same mode and end screen for
  both, named second player, never offered on phones
- HUD: the aim assist stays on when the HUD is rebuilt, a touch brings the
  sticks back over a controller, enemy arrows no longer twitch or slide over
  gauges, map and panels, the inventory clears the defense panel on keyboard
  screens, notices clear the sticks
- CPU tanks drive the vehicles of their level and attack after the gentle
  start, so doing nothing no longer wins
- Stats: accuracy stays at most 100 %, a rating change of zero is hidden,
  the leaderboard hides empty and guest rows and no longer jumps
- The start button stays in place when a replay appears, the difficulty
  picked last is kept on the device
- Remote repairs, rapid fire and crate pickups are checked against what is
  possible
- The engine sound is no longer released twice

### Penetration and stress test ([#12](https://github.com/regetskcob/wargame/issues/12))

- Rooms cap messages per sender and kind and check what comes in: forged
  round starts, room closings, blasts, grenades, endless speeds and floods
  of made up tanks, aircraft, drones, guns, troops or items no longer get
  through
- A player who drops out for up to six seconds keeps tank, guns and, as
  host, the defense; deaths from before a rematch no longer count
- A builder now learns when the host destroyed their gun
- Call signs lose invisible and right to left characters
- Migration 0018: Realtime slots capped under a budget kept in the
  database, rated opponents only while online, kills and damage tied to
  the time since the last round, at most 300 rounds a day, badges stamped
  with the server's time
- A player arriving by room link is counted against the Realtime budget
- Long defense rounds no longer pile up fallen soldiers, craters, stains,
  wrecks and replay positions
- Faster drawing: on an iPad Pro 2018 a defense at wave 30 went from about
  65 to 95 fps
- A second phone paired during the results no longer leaves an empty half,
  and the inventory stays clear of the defense build panel

## 1.3.0 (8) – 2026-10-10

- Invite a chat into a room from iMessage, the round's result shows up there
- Capture the flag with two players on one screen, together or against each
  other
- The iPhone vibrates with the game (can be turned off)
- Team rounds paint every tank red or blue
- Flak stops jets with a proximity fuse, and the defense is rebalanced
- The leaderboard counts points instead of the Elo rating alone
- A gentle start for new players, and the start page no longer waits for
  the server
- On upright phones the aim assist sits right above the aim stick

## 1.2.1 (7) – 2026-10-09

- Capture the flag as a fourth mode, red against blue with CPU tanks on both
  sides
- Fuel stations and ammo depots refill the tank and blow up when hit
- A running round can be left after a short question
- Vehicles carry animal names
- The leaderboard fits a phone
- Tidier starting, joining and briefing

## 1.2.0 (6) – 2026-10-09

- The Apple Watch app embedded and checked in every build (build 5 had gone
  out without it), built by `tool/archive_ios.sh`
- New store screenshots in German and English
- Store description brought up to the current features

## 1.1.0 (3–5) – 2026-10-08 to 2026-10-09

- An Apple Watch version of the game
- A phone becomes the controller of the game on a computer or tablet by QR
  code
- Two players on one screen in the browser and on the iPad, at no Realtime
  cost
- Rooms follow what the Supabase plan carries (four pilots, a shared load
  budget) and say when all are taken
- The game stays playable alone when the server turns it away
- Tidier waiting room and settings
- Builds with glued dart-defines stop in Xcode (build 4 could not reach the
  server because of them)

## 1.0.0 (1–2) – 2026-10-08

- The first version for iPhone and iPad
- Single player, multiplayer and defense
- Eight vehicles
- Touch controls with aim assist, portrait and landscape
- Accounts by e-mail with rank, rating and badges; guests play unranked
- Build 2: the phone as a controller
