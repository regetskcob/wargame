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

/// True when this session opened the room, false when it joined by a link.
bool isRoomHost() => _hosting;

/// Reads the room from `?room=CODE`. Without one a fresh private room is
/// opened and written into the address bar, so the link can be copied.
String resolveRoom() {
  final uri = Uri.base;
  final given = uri.queryParameters['room']?.trim();
  if (given != null && given.isNotEmpty) {
    _hosting = false;
    return given.toUpperCase();
  }
  final code = _newCode();
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
