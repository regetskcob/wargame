import 'dart:async';
import 'dart:math';
import 'dart:ui' show Rect;

import 'package:app_links/app_links.dart';
import 'package:flutter_watchos/flutter_watchos.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app/env.dart';
import 'room_code.dart';

const _guestKey = 'panzergefecht.guest';
const _tutorialKey = 'panzergefecht.tutorial';

SharedPreferencesWithCache? _store;

/// Opens the settings store of the device before the first frame, so the
/// checks below can answer right away. The login itself is kept by
/// supabase_flutter in the same store.
Future<void> openLocalStore() async {
  try {
    _store = await SharedPreferencesWithCache.create(
      cacheOptions: const SharedPreferencesWithCacheOptions(
        allowList: {_guestKey, _tutorialKey},
      ),
    );
  } on Object {
    // Without a store the welcome page and the tutorial simply ask again.
  }
}

const _alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

String _newCode() {
  final random = Random.secure();
  return [
    for (var i = 0; i < 5; i++) _alphabet[random.nextInt(_alphabet.length)],
  ].join();
}

var _hosting = true;

/// Builds the game anew for another room: the apps have no address bar to
/// reload, so the app swaps the whole game, as a reload does in the browser.
/// Set by the app shell, takes the room and whether this player hosts it.
void Function(String room, {required bool host})? onRoomSwitch;

/// The room the game is in right now, so a link to it changes nothing.
String? _current;

/// Room of this session: the fixed test room, else a fresh private one this
/// player hosts, like the start page in the browser.
String resolveRoom() => _current = Env.room.isNotEmpty ? Env.room : _newCode();

StreamSubscription<Uri>? _links;

/// Room links opened on this device, from the camera, a message or the
/// browser, lead straight into their room, also when they start the app.
void listenForRoomLinks() {
  // app_links has no watchOS implementation, and nobody opens links there.
  if (FlutterWatchosPlatform.isWatch) {
    return;
  }
  void open(Uri? uri) {
    final pad = uri?.queryParameters['pad'];
    if (pad != null) {
      onPadLink?.call(pad);
      return;
    }
    final code = uri == null ? null : roomCodeFrom(uri.toString());
    if (code != null && code != _current) {
      joinRoom(code);
    }
  }

  final links = AppLinks();
  _links ??= links.uriLinkStream.listen(open, onError: (Object _) {});
  unawaited(links.getInitialLink().then(open, onError: (Object _) {}));
}

/// Whether this device chose to play as a guest before.
bool prefersGuest() => _store?.getBool(_guestKey) ?? false;

/// Remembers that this device plays as a guest, so the welcome page does not
/// ask again.
void rememberGuest() => unawaited(_store?.setBool(_guestKey, true));

/// Forgets the guest choice, so the welcome page asks again, as after
/// signing out.
void forgetGuest() => unawaited(_store?.remove(_guestKey));

var _tutorialSeen = false;

/// Whether this device has been through the tutorial, or skipped it.
bool tutorialSeen() =>
    _tutorialSeen || (_store?.getBool(_tutorialKey) ?? false);

/// Remembers that the tutorial was seen, so it does not open by itself again.
void rememberTutorialSeen() {
  _tutorialSeen = true;
  unawaited(_store?.setBool(_tutorialKey, true));
}

/// Back from a sign-in mail: drops its code and room from the address.
/// Outside the browser there is none.
void leaveMailLink() {}

/// True when this session opened the room, false when it joined by a code.
bool isRoomHost() => _hosting;

/// Link that brings others into [room]: the browser game with the room in
/// the address. It opens there for anybody, and the apps scan it too.
String roomLink(String room) =>
    Uri.parse(Env.webUrl).replace(queryParameters: {'room': room}).toString();

/// Hands [url] to the share sheet of the device. False when there is none.
/// [origin] is where the sheet points from on an iPad.
Future<bool> shareRoomLink(String url, String text, {Rect? origin}) async {
  try {
    final result = await SharePlus.instance.share(
      ShareParams(text: '$text\n$url', sharePositionOrigin: origin),
    );
    return result.status != ShareResultStatus.unavailable;
  } on Object {
    return false;
  }
}

/// Address that sign-in links lead back to, null outside the browser.
String? authRedirect() => null;

/// Switches to [room] as a guest of whoever opened it.
bool joinRoom(String room) {
  final switcher = onRoomSwitch;
  if (switcher == null) {
    return false;
  }
  _hosting = false;
  _current = room.trim().toUpperCase();
  switcher(_current!, host: false);
  return true;
}

/// Opens a fresh room hosted by this player.
bool openFreshRoom() {
  final switcher = onRoomSwitch;
  if (switcher == null) {
    return false;
  }
  _hosting = true;
  _current = _newCode();
  switcher(_current!, host: true);
  return true;
}

String? _padCode;

/// Pairing code of a phone that steers this game. The apps keep the game
/// when they switch rooms, so memory is enough.
String? storedPadCode() => _padCode;

void rememberPadCode(String? code) => _padCode = code;

/// Set by the app shell: a pairing link opened on this device turns it
/// into the controller of that screen.
void Function(String code)? onPadLink;

/// The apps open pairing links through [onPadLink] instead.
String? padCodeOfPage() => null;

void leavePadPage() {}
