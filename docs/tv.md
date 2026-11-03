# Televisions

Where the game stands on the big screen: how to run it on the Apple TV,
Android TV and Fire TV, what they share, what is special about each, and
what is untested or next. It is for developers who want to try the game on a
television or work on its sofa screens. Two players on one screen and the
base duel, which started on the Apple TV but also run in the browser, on
tablets and on the Mac, are in
[platforms.md → Controllers and two players on one screen](platforms.md#controllers-and-two-players-on-one-screen).

Contents:

- [At a glance](#at-a-glance)
- [What all televisions share](#what-all-televisions-share)
- [Apple TV](#apple-tv)
- [Android TV and Google TV](#android-tv-and-google-tv)
- [Fire TV on Fire OS](#fire-tv-on-fire-os)
- [Fire TV on Vega OS](#fire-tv-on-vega-os)
- [Trying it](#trying-it)

## At a glance

| Platform | Devices | Build | State |
| --- | --- | --- | --- |
| Apple TV | Apple TV HD, 4K | `tvos/` (flutter-tvos) | Plays fully; tried in the Simulator only |
| Android TV / Google TV | Google TV Streamer, Chromecast with Google TV, Sony, Philips, TCL TVs … | the Android app | Plays in the Android TV emulator (Google TV, 4K); no real device yet |
| Fire TV on Fire OS | Fire TV Stick 4K Max, 4K Plus, Fire TV Cube, TVs with Fire TV built in | the Android app | Same build as Android TV; not tried, no Amazon Appstore listing yet |
| Fire TV on Vega OS | Fire TV Stick 4K Select (2025), Fire TV Stick HD (2026) | none | No Flutter; a web shell is worth a spike, see below |

## What all televisions share

`onTv` in [`lib/src/tv/tv_input.dart`](../lib/src/tv/tv_input.dart) is true
on every television and switches on the sofa screens: larger menus, the amber
focus frame ([`lib/src/tv/tv_focus_frame.dart`](../lib/src/tv/tv_focus_frame.dart)),
Back stepping out of the menus, the controllers panel and the duel on the
start page, and no touch sticks, camera or room links. `onAppleTv` is only
for what the Apple TV alone has, the Siri Remote and its settings.
`remoteName` names the remote on screen.

- **One layout size**: the menus are laid out 1280 points wide on every
  television (`tvScaleFor` in
  [`lib/src/ui/widgets/tablet_scale.dart`](../lib/src/ui/widgets/tablet_scale.dart)).
  The Apple TV is always 1920 points wide and draws them at Horizont's
  `HzTv.typeScale` of 1.5; Android TV is mostly 960 wide (1080p at twice
  the density) and draws them at 0.75. Both end up the same size on the
  panel, so the layouts tried on the Apple TV hold.
- **Safe margins**: menus and HUD keep Horizont's television margin of 80
  at the sides and 60 above and below (`TvSafeArea`, handed down as the
  screen's padding); the round itself fills the panel.
- **Nothing scrolls**: the start page puts the controllers, the phone
  pairing and the leaderboard in a column beside the four ways to play, the
  account page has two columns, and a page that is still too tall shrinks to
  fit (`FitOrScroll`). Only the legal texts scroll.
- **Text fields** are built through `SelectToType`
  ([`lib/src/tv/select_to_type.dart`](../lib/src/tv/select_to_type.dart)):
  read-only until a click, so the focus passes over them without opening
  the keyboard. On the Apple TV a focused field used to put the engine's
  keyboard stand-in in front of the remote, which swallowed the end of the
  swipe, and its key repeat walked the focus round the page.
- **Phones as controllers**: a television pairs phones like the browser does.
  The first steers the game, a second joins for two players. There is no
  camera, so no QR scanning and no room links.

## Apple TV

`tvos/` is the tvOS runner of the same game, built with the
[flutter-tvos](https://github.com/fluttertv/flutter-tvos) toolchain (tag
`v3.47.6-tvos.1.11.1`, no account needed). It runs the same `lib/main.dart`
as every other platform and shares the bundle id `de.regetskcob.wargame`
with the iOS app, so both can be one universal purchase.

```sh
export PATH="$HOME/path/to/flutter-tvos/bin:$PATH"
flutter-tvos build tvos --debug --simulator  # debug, Simulator only
flutter-tvos run -d <apple-tv-simulator-id>  # hot reload
flutter-tvos run -d <apple-tv-id> --release  # a real Apple TV
```

Run `flutter-tvos` after a plain `flutter pub get` or `flutter test` before a
hot restart: both write the Dart plugin registrant for iOS, which breaks the
sound on the Apple TV until the next `flutter-tvos` build. Plugins need a
`*_tvos` package (`shared_preferences_tvos`, `path_provider_tvos`,
`audioplayers_tvos` and `url_launcher_tvos` are in); `app_links`,
`share_plus` and `mobile_scanner` have none.

### Controls

It plays with the Siri Remote or a game controller, whichever is in hand:

| | Controller | Siri Remote |
| --- | --- | --- |
| Drive | left stick, the tank turns and drives that way | thumb on the touch surface, where it rests is the direction |
| Aim | right stick; released, the aim assist takes over | aim assist |
| Fire | R2 or A | click |
| Special weapon | L2 | play/pause |
| Inventory | X, Y, then ←, ↑, →, ↓ for slots 1 to 6 | play/pause takes the top slot when no weapon is armed |
| Defense | R1 builds or upgrades, L1 switches the gun | play/pause builds while the inventory is empty |
| Menus | pad or stick, A selects, B back | swipe, click selects, Menu back |

`tvos/Runner/GamepadPlugin.swift` reads both through GameController and
streams them to `lib/src/tv/tv_input.dart`, which steers the tank and keeps
the screen saver away. The briefing explains the controls of what is in hand
and switches when another one is picked up.

### Menus and focus

The menus take the arrow keys and Enter that the engine makes of swipes and
presses. Up and down walk them in reading order, and Menu or B steps back
from the settings to the waiting room to the start page; only there does it
leave the app.

In a running round, Menu or B opens the round menu instead (`TankGame.tvMenu`,
[`lib/src/tv/tv_menu_scope.dart`](../lib/src/tv/tv_menu_scope.dart)). The tank
stops taking the remote, the focus moves into the menu and stays there,
swipes walk its buttons, the click or play/pause presses one, and Menu closes
it. In a defense round it is the defense panel with KEEP PLAYING and LEAVE
ROUND on top, so every gun, upgrade and the next wave can be reached; in the
other modes a small panel with the two. Leaving still asks first.

### Icons and signing

The icon (a back and a front layer), the top shelf with the name on the
horizon and the launch image come from Horizont via
`python3 tool/store/horizont_icons.py`. Signing comes from
[`apple/Signing.xcconfig`](../apple/Signing.xcconfig) as on iOS (see
[platforms.md → iOS and Android](platforms.md#ios-and-android)); `tvos/` also
repeats the team in its project, because flutter-tvos reads it there. A
tvOS development profile needs an Apple TV registered with the team. Release
archives: [platforms.md → Release builds](platforms.md#release-builds-maintainer).

**Not tried yet:** a real Apple TV with the Siri Remote. The simulator gets
no remote presses, so swipes and clicks need a real remote to be sure.

## Android TV and Google TV

The Android app is the television app as well: one APK or bundle for
phones, tablets and televisions, as Google Play wants it.

What is in place:

- **Detection**: `detectTv()` asks `GamepadPlugin.kt` (channel `wargame/tv`,
  method `info`) before the game starts. A television is UI mode
  `UI_MODE_TYPE_TELEVISION`, the `android.software.leanback` feature or
  Fire OS's `amazon.hardware.fire_tv`.
- **The remote as a controller**: `GamepadPlugin.kt` reports the remote as a
  pad of kind `remote`, last in the list like the Siri Remote. The d-pad
  drives (two keys at once drive diagonally), OK fires, play/pause or menu
  set off the special weapon or the top item and build a gun in defense.
  `MainActivity` hands it every key that is not from a gamepad; the keys
  still reach Flutter, so the d-pad walks the menus, OK presses
  (`LogicalKeyboardKey.select` is a default activator) and Back steps back
  through the same `PopScope` as on the Apple TV.
- **Game controllers** use the gamepad path that serves Android phones and
  tablets.
- **Manifest**: `LEANBACK_LAUNCHER`, a banner (`@drawable/tv_banner`), and
  touch screen, camera, gamepad and leanback declared as not required, so
  Google Play and the Amazon Appstore list the app for televisions.
- **Texts**: the tutorial, the controls dialog, the duel help and the
  controllers panel speak of the d-pad and OK instead of the touch surface.
- **Screen on**: the window keeps the screen awake in a round
  (`FLAG_KEEP_SCREEN_ON`).

Tried in the Google TV emulator (4K, 960 × 540 logical): the app shows on
the home screen, the start page has the television layout with the remote as
controller 1, the d-pad walks the focus, OK opens and Back steps back. The
waiting room hands the focus to Start (`_TvFirstFocus` in
`lib/src/ui/lobby_overlay.dart`), so OK starts right away and up reaches the
tanks and colours. In a round the d-pad drives, OK fires with the aim assist,
menu builds a gun in defense and play/pause tries to (short of coins it says
so), and the defense HUD names those buttons.

Open:

- A game controller (the emulator has none) and a real Google TV or
  Android TV device.
- Remotes without play/pause or menu (some Chromecast remotes) have no
  button for items and special weapons yet; a long press on OK could take
  it.
- Sign-in on a television: typing an e-mail with the d-pad is slow. A code
  shown on the TV and confirmed on the phone would fit better.
- Google Play (maintainer): opt in to the TV form factor in the console and
  pass the TV review. Screenshots and banner are ready in
  `store/android/metadata/` (see `store/android/README.md`).
- The Wear OS bundle merges the same main manifest; check that the launcher
  category and banner do no harm there.

## Fire TV on Fire OS

Fire OS 7 and 8 are Android 9 and 11 underneath, so the Android TV build
runs there unchanged. Nothing in the game needs Google Play Services
(Supabase and Realtime are plain HTTPS and WebSockets); only the QR scanner
uses Google ML Kit, and televisions have no camera, so it never shows. The
Fire TV remote has play/pause and menu, so items and special weapons work as
on Android TV.

Open:

- Try it on a real Fire TV Stick (see [Trying it](#trying-it)). Amazon hides
  the developer options on newer Fire OS updates; on some sticks they come
  back after tapping "About → Fire TV Stick" seven times.
- Amazon Appstore (maintainer): a free Amazon Developer account, the same
  APK or App Bundle marked for Fire TV, TV screenshots and a 1280 × 720
  icon.

## Fire TV on Vega OS

Amazon's own Linux-based system, on the Fire TV Stick 4K Select since
October 2025 and the Fire TV Stick HD of 2026. Findings (October 2026):

- **Only the entry sticks.** The 4K Max, the 4K Plus, the Cube and
  televisions with Fire TV built in still run Fire OS and are covered by
  the Android build above.
- **No Android apps, no sideloading, no Flutter.** Apps are built with the
  Vega Developer Tools (once called Kepler) in React Native for Vega, or as
  a web app in the Vega WebView, packaged as `.vpkg` and installed only from
  the Amazon Appstore. Porting the game to React Native is out of the
  question.
- **The web build could work.** A thin Vega app around a WebView that loads
  `/play/`, with the television screens switched on, would keep one code
  base. That needs a way to turn them on in the browser (a `?tv=1`
  parameter, say), since `onTv` is always false on the web today.
- **Unknowns for that shell:** whether Flutter web with CanvasKit and Flame
  keeps a steady frame rate in the WebView of an entry stick, whether the
  remote's d-pad arrives as key events, and whether the Gamepad API
  ([`lib/src/tv/web_pads.dart`](../lib/src/tv/web_pads.dart)) is there for
  controllers.

Next step, after Android TV: a half-day spike with the Vega Virtual Device
(the Vega Developer Tools need macOS or Linux), a WebView app loading the
web build, measuring the frame rate and checking remote and controller.
Amazon requires a test on a real stick before the Appstore takes an app.

Sources: [Getting started with Vega OS (Amazon, 2026)](https://developer.amazon.com/apps-and-games/blogs/2026/07/guide-to-building-for-fire-tv-on-vega-os),
[Announcing Vega Developer Tools](https://developer.amazon.com/apps-and-games/blogs/2025/09/announcing-vega-os),
[Run apps on the Vega Virtual Device](https://developer.amazon.com/docs/vega/0.23/run-apps),
[Powering Vega OS with React Native](https://swmansion.com/blog/amazon-x-software-mansion-powering-vega-os-with-react-native-75c4cf522fd7/).

## Trying it

```sh
# Apple TV Simulator: see "Apple TV" above for the toolchain
flutter-tvos run -d <apple-tv-simulator-id>

# Android TV emulator: create a "Television (1080p)" device with a Google TV
# image in Android Studio's Device Manager, start it, then
flutter run -d emulator-5554

# Fire TV Stick on the same network, developer options and ADB debugging on
adb connect <ip-of-the-stick>
flutter run -d <ip-of-the-stick>:5555

# Copy the banner, the icons and the Apple TV top shelf from Horizont
python3 tool/store/horizont_icons.py
```

In the Android TV emulator the arrow keys of the computer are the d-pad,
Enter is OK and Escape is Back. `adb shell input keyevent` presses and
releases within the same frame, so a round can miss such a tap; hold it with
`--duration 200` as a real press does.
