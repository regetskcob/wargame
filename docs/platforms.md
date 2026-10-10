# Platforms

The web game is the main target. The same code runs as apps on iOS, Android, the Mac, the Apple Watch and the Apple TV.

## Mobile apps (iOS and Android)

The project carries `ios/` and `android/` next to `macos/` and `web/`. The
apps are called Panzergefecht, with the bundle and app id
`de.regetskcob.wargame` on iOS and Android (kept from an earlier name, store
ids cannot change). The iOS product is `Panzergefecht.app`, the Xcode target
and scheme stay `Runner`, which `flutter build ios` expects. On phones
and tablets the game plays upright or sideways, hides the system bars, and
shows the on-screen touch controls. The camera shows the same stretch of the
world along the shorter side, so upright shows more of the field above and
below; in a defense round the field's height fills an upright screen. The
apps have no mute button: the sounds follow the silent switch and the volume
keys, and mix with music from other apps. Android has the `INTERNET`
permission in the main manifest, so release builds can reach Supabase.

While the app starts it reaches the server before the start page shows.
The launch screen shows the tank of the app icon on a calm version of its
ground, and `LoadingView` (`lib/src/ui/loading_view.dart`) keeps exactly
that with a spinner below, from the first Flutter frame until the game has
loaded; the web page shows the same from `web/index.html` before Flutter
starts. Android draws only the ground colour behind the tank
(`@color/launch_ground`); since Android 12 the system splash shows the tank
as its icon (`values-v31/styles.xml`), before that `launch_background.xml`
does. `python3 store/tool/launch_screen.py` draws the images for all of
them (iOS image sets, Android drawables, `assets/images/`, `web/`).

You need a full Xcode (iOS) and a JDK with the Android SDK (Android), see
`flutter doctor`. Then:

```sh
flutter run -d <device-id>   # a simulator, an emulator, or a plugged in phone
flutter build apk --release        # Android APK
flutter build appbundle --release  # Android App Bundle for Google Play
flutter build ios --release        # iOS, set your signing team in Xcode first
```

Pass `--dart-define=SUPABASE_URL=...` and `--dart-define=SUPABASE_KEY=...` as
for the web build. CI builds the iOS app without signing
(`flutter build ios --release --no-codesign`) and the Android App Bundle with
the debug key on every push. To sign, add your Apple ID in
Xcode (Settings > Accounts), open `ios/Runner.xcworkspace` and pick your team
under Signing & Capabilities. The app declares that it uses no non-exempt
encryption, so App Store Connect skips the export compliance question. On
iOS and Android sign-in mails are confirmed with the code from the mail, the
link in it opens the web game. To sign the Android release, copy
`android/key.properties.example` to `android/key.properties` and point it at
your upload key; without it Gradle signs with the debug key, which Google Play
rejects. Store texts, icons and screenshots for both stores live in
`store/ios` and `store/android`, each with a README of what goes where. The
`play` workflow (run by hand) builds the signed bundle and uploads it to a
Google Play track with fastlane, see `store/android/README.md` for the
secrets. To play
a local stack from an Android emulator use `http://10.0.2.2:54621`, from a real
phone the LAN address of your Mac.

## Mac

`macos/` builds the game as a Mac app, `Panzergefecht.app`, with the same
bundle id `de.regetskcob.wargame` as the iOS app, so both can share one App
Store record as a universal purchase. It runs the same screens as the
browser: keyboard and mouse, no touch controls (they appear after the first
touch, as in the browser), the start page as on a large screen. It starts in
full screen every time (state restoration is off, so macOS cannot reopen it
as a window); View > Exit Full Screen or ⌃⌘F leaves it for a 1280 x 800
window that keeps at least 720 x 480.

Game controllers work as on the iPad: `macos/Runner/GamepadPlugin.swift`
reads them through GameController and streams them to the same
`lib/src/tv/tv_input.dart`, the first one steers the own tank, two of them
play on a split screen (see **Two players** below), and the display stays
awake during a round. Only pads with two sticks count. The menus stay with
keyboard and mouse, as in the browser. Phones pair as controllers too, the
Mac is the screen.

The app is sandboxed and asks for two things in `Runner/*.entitlements`:
outgoing connections (`network.client`, without it Supabase is out of reach
and the app plays offline) and the camera, for the QR code button in the room
list (`mobile_scanner`, text in `NSCameraUsageDescription`). Room links from
the web do not open the app yet: associated domains need a signed build with
a provisioning profile. `python3 store/tool/app_icon.py` also writes the Mac
icon set, the square on Apple's rounded plate with a shadow, since macOS does
not round icons itself.

```sh
flutter run -d macos
flutter build macos --release \
  --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_KEY=... --dart-define=ACCOUNTS=true
```

The build signs ad hoc, enough to run it on the Mac that built it. To hand it
on, open `macos/Runner.xcworkspace`, pick the team under Signing &
Capabilities and archive (Product > Archive): from the organizer either upload
to App Store Connect or export with Developer ID, which Xcode notarizes. CI
builds it unsigned next to the iOS app.

## Apple Watch

`watchos` is the watchOS runner of the same game, built with the
[flutter-watchos](https://github.com/flutterwatch/flutter-watchos) toolchain
(Flutter 3.47.5, Apple Silicon, `flutter-watchos login` once). The watch app is
a companion of the iOS app (`de.regetskcob.wargame.watchkitapp`, embedded by the
"Embed Prebuilt watchOS App" phase of the iOS Runner) and runs the same
`lib/main.dart`. State: first version, not tried on a real watch yet. The game starts in the watch Simulator and
reaches Supabase and plays its sounds (`audioplayers_watchos`,
`path_provider_watchos`, `shared_preferences_watchos`) and taps the wrist
(`lib/src/haptics.dart`: hits and blasts close by, countdown, start, own tank
destroyed, round won or lost).

The watch has its own screens (`lib/src/watch`), used instead of the phone
overlays when `FlutterWatchosPlatform.isWatch`: a start page with the call sign
(a tap opens the watch keyboard), the three ways to play and the open rooms,
a waiting room with vehicle, level and public or private, a slim HUD (tanks
left or wave, armour, magazine, up to three inventory items, in a defense
round a button to build a gun), and an end screen. The Digital Crown scrolls
the menus. In a round it steers: the tank drives all the time and fires by
itself at the nearest enemy (the aim assist, on hard the gun fires straight
ahead), and turning the crown turns the direction of travel. The crown reports scroll
distance with the system's acceleration (about 0.75 per detent, thousands for
a flick), so `WatchSteering.steer` takes its logarithm: a detent corrects by
about two degrees, a quick turn swings at full speed. The heading stays within
`maxLead` of the hull, so the tank never overshoots far or turns the wrong way
round. Measured in the watch Simulator through Device Hub, still to be tried
on a real watch. The watch camera looks 12 % closer than the phone's
(`GameConfig.watchZoom`), and in a solo round every tank tops out 15 % slower
(`GameConfig.watchSoloSpeed`), since the crown steers slower than a thumb;
shared rounds keep the same speed for all. The watch plays as a guest, signing in takes the phone.
The app icon is the one of the phone app.

```sh
export PATH="$HOME/path/to/flutter-watchos/bin:$PATH"
flutter-watchos build watchos --simulator    # debug, Simulator only
flutter-watchos run -d <watch-simulator-id>  # hot reload
flutter-watchos run -d <watch-id> --release  # real watch: Series 9+, watchOS 26+
```

For the App Store, `tool/archive_ios.sh` builds the watch app first, then the
iOS archive, checks that `Panzergefecht.app/Watch/Runner.app` is inside with
the same version and build, and copies the archive into the Organizer as
"Panzergefecht <version> (<build>)"; with `--upload` it also sends it to App
Store Connect. The embed phase
(`tool/embed_watch_app.sh`) stops an archive without a watch app or with a
stale one; `ALLOW_NO_WATCH=1` lets one through on purpose. Older watches
(Series 4 to 8, SE 1/2, Ultra 1) get the stub slice flutter-watchos adds, which
only says that the app needs a Series 9.

Use `FlutterWatchosPlatform.isWatch` from `flutter_watchos` to branch for the
watch, never `Platform.isWatchOS` in shared code. Plugins need a `*_watchos`
package; without one calls throw `MissingPluginException`.
`app_links`, `share_plus` and `mobile_scanner` have none, so no room links, no
sharing and no QR scanning on the watch.

## Apple TV

`tvos` is the tvOS runner of the same game, built with the
[flutter-tvos](https://github.com/fluttertv/flutter-tvos) toolchain (Flutter
3.47.6, no account needed). It runs the same `lib/main.dart` and the same
screens as the browser, drawn larger (`tvScale`), and shares the bundle id
`de.regetskcob.wargame` with the iOS app, so both can be one universal
purchase. Icon, top shelf and launch screen come from the layers of the app
icon (`store/tool/tv_icons.py`). State: tried in the Apple TV Simulator only.

Nothing scrolls on the television. The menus use its width: the start page puts
the controllers, the phone pairing and the leaderboard in a column beside the
four ways to play, the account sheet has two columns, and a page that is still
too tall shrinks to fit (`FitOrScroll`) instead of scrolling. Only the legal
texts scroll.

It plays with the Siri Remote or a game controller, whichever is in hand:

| | Controller | Siri Remote |
| --- | --- | --- |
| Drive | left stick, the tank turns and drives that way | thumb on the touch surface, where it rests is the direction |
| Aim | right stick, released the aim assist takes over | aim assist (none on hard) |
| Fire | R2 or A | click |
| Special weapon | L2 | play/pause |
| Inventory | X, Y, then ←, ↑, →, ↓ for slots 1 to 6 | play/pause, the top slot, when no weapon is armed |
| Defense | R1 builds or upgrades, L1 switches the gun | play/pause builds while the inventory is empty |
| Menus | pad or stick, A selects, B back | swipe, click selects, Menu back |

`tvos/Runner/GamepadPlugin.swift` reads both through GameController and streams
them to `lib/src/tv/tv_input.dart`, which steers the tank in a round and keeps
the screen saver away. The menus take the arrow keys and enter the engine makes
of swipes and presses: up and down walk them in reading order, an amber frame
(`lib/src/tv/tv_focus_frame.dart`) shows the focus, and Menu or B steps back
from the settings to the waiting room to the start page and leaves the app only
from there. In a round they do nothing. The Apple TV can also pair phones as
controllers, like the browser: the first steers the game, a second waits for a
duel. No camera, so no QR scanning, and no room links. The briefing explains
the controls of what is in hand, the controller or the Siri Remote, and
switches when another one is picked up. The menus sit in the middle of the
screen.

**Two players** on the Apple TV, in the browser, on an iPad or Android
tablet and on the Mac: with two
controllers in (or phones, the Siri Remote counting as one, handed out
controllers first, then phones, the remote last), the second player gets a game of their own (`lib/src/tv/second_player.dart`) that
joins the first player's room. Rounds then play on a split screen, side by side
or, on a tablet held upright, one above the other, each half from its own tank
(`lib/src/tv/split_view.dart`); the menus stay with the first player. Single
player puts both against the CPU tanks, multiplayer and defense take both
pilots along. The browser reads controllers through its Gamepad API
(`lib/src/tv/web_pads.dart`, a controller shows once a button on it was
pressed), the iPhone and iPad through GameController (`ios/Runner/GamepadPlugin.swift`),
the Mac the same way (`macos/Runner/GamepadPlugin.swift`), and Android from
the key and motion events of its gamepads, which `MainActivity` hands to
`android/.../GamepadPlugin.kt` (same channels and state as on iOS; not yet
tried with a real controller).
Phones are too small for two halves. One controller alone, a phone or a
game controller, steers the own tank in every mode, and the touch sticks of
a tablet step aside for it.

The two games talk on the device (`LocalLink` in `net_service.dart`): nothing
goes over Realtime and the room takes no slot. The first player's presence
carries the second's, so people on other devices count them, and a room of two
is full for them. Only with somebody from another device in the room does the
second player join over a Supabase connection of their own, between rounds,
and the room costs what any room of that many pilots costs.

**Duel** (fourth card on the start page with two players): a defense round with
a base at either end of the road of a common layout
(`DefenseMap.duelForSeed`), red on the left, blue on the right. The waves stay
as they are, but each side's roll along the road against the other's base, so
they meet on the way, and every gun, tank and squad fights the other side. Y on
a controller, T on a keyboard, sends an extra tank against the other base for
120 funds (`troops` event, run by the host). Bases grow on their
own. Two players on one screen watch their duel on the whole field at once
instead of a split screen: the camera holds still over the map
(`TankGame.overview`), the wave and both bases on top, each player's tank,
funds and inventory in their corner (`lib/src/tv/duel_hud.dart`). Whose base
falls first loses, and the waves go on past
wave 8 by themselves. Duels are unranked. The host runs the waves and keeps the
score of every base and gun, also of the other player's shots. Phones as
the two players' controllers talk to the television on a lane each.

```sh
export PATH="$HOME/path/to/flutter-tvos/bin:$PATH"
flutter-tvos build tvos --debug --simulator  # debug, Simulator only
flutter-tvos run -d <apple-tv-simulator-id>  # hot reload
flutter-tvos run -d <apple-tv-id> --release  # real Apple TV
python3 store/tool/tv_icons.py               # icon layers, top shelf, launch image
```

Use `onTv` from `lib/src/tv/tv_input.dart` to branch for the Apple TV, never
`Platform.isIOS` alone: it is true there as well. Plugins need a `*_tvos`
package (`shared_preferences_tvos`, `path_provider_tvos`, `audioplayers_tvos`,
`url_launcher_tvos` are in), `app_links`, `share_plus` and `mobile_scanner`
have none. Run `flutter-tvos` after a plain `flutter pub get` or `flutter test`
before a hot restart: both write the Dart plugin registrant for iOS, which
breaks the sound on the Apple TV until the next `flutter-tvos` build.

