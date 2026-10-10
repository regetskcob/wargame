import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:math';
import 'dart:ui' show Rect;

import 'package:web/web.dart' as web;

const _alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

String _newCode() {
  final random = Random.secure();
  return [
    for (var i = 0; i < 5; i++) _alphabet[random.nextInt(_alphabet.length)],
  ].join();
}

bool _hosting = true;

/// The apps follow room links opened on the device. In the browser the link
/// is the address itself.
void listenForRoomLinks() {}

/// Used by the apps to swap the game for another room. The browser loads
/// the room's address instead, so this stays unset here.
void Function(String room, {required bool host})? onRoomSwitch;

const _hostedKey = 'panzergefecht.hostedRooms';

/// Rooms this browser opened, so reloading the page keeps you their host.
Set<String> _hostedRooms() {
  try {
    final stored = web.window.localStorage.getItem(_hostedKey);
    return stored == null || stored.isEmpty ? {} : stored.split(',').toSet();
  } on Object {
    return {};
  }
}

void _rememberHosted(String code) {
  try {
    // Only the latest few, the list must not grow forever.
    final rooms = [..._hostedRooms().where((r) => r != code), code];
    web.window.localStorage.setItem(
      _hostedKey,
      rooms.skip(max(0, rooms.length - 10)).join(','),
    );
  } on Object {
    // Without storage a reload simply joins as a guest.
  }
}

/// The browser keeps its settings in `localStorage`, nothing to open.
Future<void> openLocalStore() async {}

const _tutorialKey = 'panzergefecht.tutorial';

/// Whether this browser has been through the tutorial, or skipped it.
bool tutorialSeen() {
  try {
    return web.window.localStorage.getItem(_tutorialKey) == '1';
  } on Object {
    return false;
  }
}

/// Remembers that the tutorial was seen, so it does not open by itself again.
void rememberTutorialSeen() {
  try {
    web.window.localStorage.setItem(_tutorialKey, '1');
  } on Object {
    // Without storage the tutorial simply opens again next time.
  }
}

const _veteranKey = 'panzergefecht.veteran';

/// Whether this browser has played a round to its end. Until then the CPU
/// tanks start on the easy level.
bool roundPlayed() {
  try {
    return web.window.localStorage.getItem(_veteranKey) == '1';
  } on Object {
    return false;
  }
}

/// Remembers that a round was played to its end.
void rememberRoundPlayed() {
  try {
    web.window.localStorage.setItem(_veteranKey, '1');
  } on Object {
    // Without storage the next visit simply starts on easy again.
  }
}

const _pilotKey = 'panzergefecht.pilot';

/// Call sign and style last used in this browser, at hand before the
/// server answers and without one.
(String, int)? storedPilot() {
  try {
    final text = web.window.localStorage.getItem(_pilotKey);
    final bar = text?.indexOf('|') ?? -1;
    final style = bar > 0 ? int.tryParse(text!.substring(0, bar)) : null;
    if (style == null || text!.length <= bar + 1) {
      return null;
    }
    return (text.substring(bar + 1), style);
  } on Object {
    return null;
  }
}

/// Keeps call sign and style in this browser.
void rememberPilot(String name, int style) {
  try {
    web.window.localStorage.setItem(_pilotKey, '$style|$name');
  } on Object {
    // Without storage the server's copy still counts.
  }
}

/// Back from a sign-in mail: drops its one time code and any room from the
/// address, so a reload does not try the code again and the game opens a
/// fresh room on the start page.
void leaveMailLink() {
  final uri = Uri.base;
  final params = Map.of(uri.queryParameters)
    ..remove('code')
    ..remove('room');
  // Built anew: replace() keeps the old query when given none.
  web.window.history.replaceState(
    null,
    '',
    Uri(
      scheme: uri.scheme,
      host: uri.host,
      port: uri.hasPort ? uri.port : null,
      path: uri.path,
      queryParameters: params.isEmpty ? null : params,
    ).toString(),
  );
}

/// True when this session opened the room, false when it joined by a link.
bool isRoomHost() => _hosting;

/// Reads the room from `?room=CODE`. Without one a fresh private room is
/// opened and written into the address bar, so the link can be copied.
String resolveRoom() {
  final uri = Uri.base;
  final given = uri.queryParameters['room']?.trim();
  if (given != null && given.isNotEmpty) {
    final code = given.toUpperCase();
    _hosting = _hostedRooms().contains(code);
    return code;
  }
  final code = _newCode();
  _rememberHosted(code);
  web.window.history.replaceState(
    null,
    '',
    uri
        .replace(queryParameters: {...uri.queryParameters, 'room': code})
        .toString(),
  );
  return code;
}

String roomLink(String room) {
  final uri = Uri.base;
  return Uri(
    scheme: uri.scheme,
    host: uri.host,
    port: uri.hasPort ? uri.port : null,
    path: uri.path,
    queryParameters: {'room': room},
  ).toString();
}

/// Address that sign-in links lead back to: the start page of the game, not
/// the room the mail was asked for in.
String? authRedirect() => Uri(
  scheme: Uri.base.scheme,
  host: Uri.base.host,
  port: Uri.base.hasPort ? Uri.base.port : null,
  path: Uri.base.path,
).toString();

/// Opens [room] in this window, as if its link had been followed.
bool joinRoom(String room) {
  web.window.location.assign(roomLink(room.trim().toUpperCase()));
  return true;
}

/// [origin] only matters to the share sheet of the apps.
Future<bool> shareRoomLink(String url, String text, {Rect? origin}) async {
  final navigator = web.window.navigator;
  if (!(navigator as JSObject).has('share')) {
    return false;
  }
  try {
    await navigator
        .share(web.ShareData(title: 'Panzergefecht', text: text, url: url))
        .toDart;
    return true;
  } on Object {
    return false;
  }
}

/// Reloads the page without a room, which opens a fresh one with this
/// session as its host.
bool openFreshRoom() {
  final uri = Uri.base;
  final params = Map.of(uri.queryParameters)..remove('room');
  web.window.location.assign(
    Uri(
      scheme: uri.scheme,
      host: uri.host,
      port: uri.hasPort ? uri.port : null,
      path: uri.path,
      queryParameters: params.isEmpty ? null : params,
    ).toString(),
  );
  return true;
}

const _padKey = 'panzergefecht.pad';

/// Pairing code of a phone that steers this tab. Kept for the tab only, so
/// loading another room keeps the phone, and a new tab starts unpaired.
String? storedPadCode() {
  try {
    return web.window.sessionStorage.getItem(_padKey);
  } on Object {
    return null;
  }
}

void rememberPadCode(String? code) {
  try {
    if (code == null) {
      web.window.sessionStorage.removeItem(_padKey);
    } else {
      web.window.sessionStorage.setItem(_padKey, code);
    }
  } on Object {
    // Without storage the phone pairs again after the next room.
  }
}

/// The browser reads a pairing link from its own address at the start.
void Function(String code)? onPadLink;

/// Chat invitations open the apps only: in the browser the guest's link
/// simply joins the room, whose host picks the mode.
void Function(String mode)? onModeLink;

/// The pairing code this page was opened with, from `?pad=CODE`: the page
/// is then a phone's controller instead of the game.
String? padCodeOfPage() => Uri.base.queryParameters['pad'];

/// Leaves the controller for the game, by loading the page without the
/// pairing code.
void leavePadPage() {
  final uri = Uri.base;
  final params = Map.of(uri.queryParameters)..remove('pad');
  web.window.location.assign(
    Uri(
      scheme: uri.scheme,
      host: uri.host,
      port: uri.hasPort ? uri.port : null,
      path: uri.path,
      queryParameters: params.isEmpty ? null : params,
    ).toString(),
  );
}
