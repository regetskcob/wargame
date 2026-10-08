---
name: play-local
description: Start Panzergefecht locally and look at it - the web build in the built-in browser, two players in one room, the iOS Simulator or the watch. Use when the user wants to see, try or screenshot a change, or to verify gameplay beyond unit tests.
---

# Play it locally

**Web (fastest).** `preview_start` with the name `web` from
`.claude/launch.json` runs `flutter run -d web-server` on port 8080 against
the hosted Supabase project. The first compile takes about half a minute and
the tab opened before it is blank (`main.dart.js` with MIME type text/html):
navigate to the URL again once the log stops at "Waiting for connection".
In the browser the room comes from the URL (`?room=XXXXX`), so open the same
URL in a second tab for a second player. Flame draws on a canvas: use
screenshots for the battlefield, `read_page` only for Flutter overlays.
Keyboard: WASD/arrows drive, space fires, B builds or upgrades a gun and V
switches its type in defense, 1-6 use inventory slots, Esc leaves a replay.
Single key taps from the browser tool are often shorter than a frame and get
lost, so check effects (ammo, credits) rather than assuming a shot fired.

**Against the local stack** (needs Docker): `supabase start`, then add
`--dart-define=SUPABASE_URL=http://127.0.0.1:54621` and the local
publishable key from `supabase status`.

**Accounts flow**: add `--dart-define=ACCOUNTS=true`; without it there is no
welcome page and everybody is a guest.

**iOS**: attach the simulator panel first, then `flutter run -d <sim-id>` or
`flutter build ios --simulator` and launch the `.app`. Touch controls and the
upright layout only show on phones.

**Watch**: needs the `flutter-watchos` toolchain on the PATH
(`flutter-watchos run -d <watch-sim-id>`), see README "Apple Watch".

**Phone controller**: the screen shows a QR code with `?pad=<CODE>`; open
that URL in a second tab to act as the phone.

Gameplay worth checking by hand: a full solo round, a defense round to wave
3+ (aircraft), the round-over screen and rematch. Say what you checked and
what you could not.
