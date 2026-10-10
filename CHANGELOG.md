# Changelog

What each store version of Panzergefecht brought, newest first. The build
number follows in brackets; the web version at
<https://www.regetskcob.de/wargame/play/> is always the latest `main`. The
store texts for a release live in `store/ios/metadata/*/release_notes.txt`.

## 1.4.0 (9) – 2026-10-10

A calmer, slimmer look: frames only on the outer panels, frameless dark
boxes for the modes, sections and tank cards, softly rounded buttons with
hairlines, round camo dabs, and outlined small icons. The account sheet is
tidier: the call sign is saved with the tick or Enter, registering takes
that name instead of asking twice, the language sits in the title line, and
guests find signing in on a card on the start page. Last played moves next
to the briefing on tablets and up. Holding out longer in a lost battle earns
experience and shows the place reached. The phone as a controller carries
the whole defense shop, and only the app on a phone becomes one, never a
tablet or a browser. With two players on one screen each half wears its
team colour. CPU tanks see no further than people at night, in fog and in
sand, sounds fade with distance, long defense rounds run smoother, and rooms
are guarded against floods, forged messages and short dropouts. On the Apple
Watch every mode can be played alone against CPU tanks, counted for the
account on the iPhone. Fixes include the e-mail field's autofill and the
keyboard left standing after closing the account.

## 1.3.0 (8) – 2026-10-10

Invite a chat into a room straight from iMessage, and the result of the
round shows up there afterwards. Two players on one screen can capture the
flag too, together or against each other. The iPhone vibrates with the game
(can be turned off). In team rounds every tank is painted red or blue, flak
stops jets with a proximity fuse, the defense is rebalanced, and the
leaderboard counts points instead of the Elo rating alone. New players get a
gentle start, the start page no longer waits for the server, and on upright
phones the aim assist sits right above the aim stick.

## 1.2.1 (7) – 2026-10-09

Capture the flag as a fourth mode, red against blue with CPU tanks on both
sides. Fuel stations and ammo depots on the map refill the tank and blow up
when hit. A running round can be left after a short question. The vehicles
carry animal names, the leaderboard fits a phone, and starting, joining and
the briefing are tidier.

## 1.2.0 (6) – 2026-10-09

The first build with the Apple Watch app embedded and checked (build 5 had
gone out without it), built by `tool/archive_ios.sh`. New store screenshots
in German and English.

## 1.1.0 (3–5) – 2026-10-08 to 2026-10-09

An Apple Watch version of the game. A phone becomes the controller of the
game on a computer or tablet by QR code. Two players on one screen in the
browser and on the iPad, at no Realtime cost. Rooms follow what the Supabase
plan carries (four pilots, a shared load budget) and say when all are
taken, and the game stays playable alone when the server turns it away.
Tidier waiting room and settings. Build 4 could not reach the server (its
dart-defines were glued together); since then such builds stop in Xcode.

## 1.0.0 (1–2) – 2026-10-08

The first version for iPhone and iPad: single player, multiplayer and
defense, eight vehicles, touch controls with aim assist, portrait and
landscape, accounts by e-mail with rank, rating and badges, and guests who
play unranked. Build 2 added the phone as a controller.
