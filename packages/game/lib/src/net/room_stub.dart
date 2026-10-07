import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import '../env.dart';

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

/// Room of this session. Outside the browser there is no address to read it
/// from, so everybody meets in the default room.
String resolveRoom() => Env.room;

/// Whether this device chose to play as a guest before.
bool prefersGuest() => _store?.getBool(_guestKey) ?? false;

/// Remembers that this device plays as a guest, so the welcome page does not
/// ask again.
void rememberGuest() => unawaited(_store?.setBool(_guestKey, true));

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

/// True when this session opened the room, false when it joined by a link.
bool isRoomHost() => true;

/// Link that brings others into [room], empty when there is none to share.
String roomLink(String room) => '';

/// Hands [url] to the share sheet of the device. False when there is none.
Future<bool> shareRoomLink(String url, String text) async => false;

/// Address that sign-in links lead back to, null outside the browser.
String? authRedirect() => null;

/// Switches to [room]. Outside the browser there is no address to switch, so
/// this returns false.
bool joinRoom(String room) => false;

/// Opens a fresh room. False when this platform cannot, the game then joins
/// its one room again.
bool openFreshRoom() => false;
