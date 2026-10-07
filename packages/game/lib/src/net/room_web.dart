import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:math';

import 'package:web/web.dart' as web;

const _alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

String _newCode() {
  final random = Random.secure();
  return [
    for (var i = 0; i < 5; i++) _alphabet[random.nextInt(_alphabet.length)],
  ].join();
}

bool _hosting = true;

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

const _guestKey = 'panzergefecht.guest';

/// Whether this browser chose to play as a guest before.
bool prefersGuest() {
  try {
    return web.window.localStorage.getItem(_guestKey) == '1';
  } on Object {
    return false;
  }
}

/// Remembers that this browser plays as a guest, so the welcome page does
/// not ask again.
void rememberGuest() {
  try {
    web.window.localStorage.setItem(_guestKey, '1');
  } on Object {
    // Without storage the welcome page simply asks again next time.
  }
}

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

Future<bool> shareRoomLink(String url, String text) async {
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
