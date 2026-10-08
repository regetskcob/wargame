---
name: play-local
description: Start Panzergefecht locally and look at it - the web build in the built-in browser, two players in one room, the iOS Simulator or the watch. Use when the user wants to see, try or screenshot a change, or to verify gameplay beyond unit tests.
---

# Play it locally

**Web (fastest).** `preview_start` with the name `web` from
`.claude/launch.json` runs `flutter run -d web-server` on port 8080 with
`ROOM=dev`, against the hosted Supabase project. Open a second tab on the
same URL for a second player: both land in room `dev`. Flame draws on a
canvas, so use screenshots for the battlefield and `read_page` only for the
Flutter overlays (with semantics on). Keyboard: WASD/arrows drive, space
fires, 1-6 use inventory slots, Esc leaves a replay.

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
