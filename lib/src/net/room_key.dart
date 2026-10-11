import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:x25519/x25519.dart' as x25519;

/// The key a game speaks with in a room, made afresh for every game.
///
/// Anybody with the project's public key can broadcast into any room and
/// write any `id` into a message, so an id alone proves nothing. The id of
/// a game is therefore taken from its public key ([idOf]): a presence
/// carries the key, and only a key whose hash is the id counts for it.
/// Every pair of games in a room agrees on a secret from their keys
/// (X25519), and each message carries a short tag per receiver made with
/// that secret ([RoomMac]). Nobody but the sender can make a tag that the
/// receiver accepts, not even another player in the room.
class RoomKey {
  RoomKey._(this._private, this.public);

  /// A new key from the system's secure random numbers.
  factory RoomKey.generate() {
    final pair = x25519.generateKeyPair();
    return RoomKey._(
      Uint8List.fromList(pair.privateKey),
      Uint8List.fromList(pair.publicKey),
    );
  }

  final Uint8List _private;
  final Uint8List public;

  /// The id this key speaks as.
  late final String id = idOf(public);

  /// The public key as presences carry it.
  late final String encoded = encode(public);

  /// Length of an id in hex digits: 64 bits, far too many to find a second
  /// key for a given id.
  static const idLength = 16;

  /// The id that belongs to [public]: the start of its SHA-256 in hex, as
  /// long as the random ids of older builds.
  static String idOf(List<int> public) =>
      sha256.convert(public).toString().substring(0, idLength);

  static String encode(List<int> public) =>
      base64Url.encode(public).replaceAll('=', '');

  /// A public key from a presence, or null when [text] is none.
  static Uint8List? decode(Object? text) {
    if (text is! String || text.length != 43) {
      return null;
    }
    try {
      final bytes = base64Url.decode('$text=');
      return bytes.length == 32 ? bytes : null;
    } on FormatException {
      return null;
    }
  }

  /// Whether [key] (as a presence carries it) is the key of [id].
  static bool belongsTo(String id, Object? key) {
    final public = decode(key);
    return public != null && idOf(public) == id;
  }

  /// The secret this game shares with the owner of [peer] in [room], or
  /// null for a key that agrees on nothing (a point of low order, which
  /// only a forged key is).
  Uint8List? sharedWith(Uint8List peer, String room) {
    final List<int> shared;
    try {
      shared = x25519.X25519(_private, peer);
    } on Object {
      return null;
    }
    // Bound to the room, so a tag from one room means nothing in another.
    return Uint8List.fromList(
      sha256.convert([
        ...utf8.encode('panzergefecht-room|$room|'),
        ...shared,
      ]).bytes,
    );
  }
}

/// Tags that prove who sent a message, one per receiver.
abstract final class RoomMac {
  /// Field of a message that holds the sender (`s`), the sender's running
  /// number (`n`, so a tag copied from an older message does not count
  /// again) and the tags by receiver id (`t`). Older builds ignore it.
  static const field = 'mac';

  /// Bytes of a tag: 72 bits, beyond guessing in a game's lifetime.
  static const tagBytes = 9;

  /// The tag of [event] with [payload], sent by [sender] as its message
  /// number [counter], for the holder of [secret].
  static String tag(
    Uint8List secret,
    String event,
    Map<String, dynamic> payload,
    String sender,
    int counter,
  ) {
    final digest = Hmac(
      sha256,
      secret,
    ).convert(utf8.encode(canonical(event, payload, sender, counter)));
    return base64Url
        .encode(digest.bytes.sublist(0, tagBytes))
        .replaceAll('=', '');
  }

  /// Fields the Realtime client writes into every broadcast it sends
  /// (`type: broadcast` and the event's name) and hands on to the
  /// receiver with the message. The sender tags the payload before they
  /// are in it, so they stay out of what a tag covers; the event is
  /// covered on its own.
  static const _wireFields = {field, 'type', 'event'};

  /// What a tag covers: event, sender, number and every field but [field],
  /// written the same way on every platform. The channel hands a message
  /// on as JSON, and a browser reads `1.0` as `1` and keeps keys in any
  /// order, so keys are sorted and numbers written in thousandths.
  static String canonical(
    String event,
    Map<String, dynamic> payload,
    String sender,
    int counter,
  ) {
    final out = StringBuffer(event)
      ..write('\n')
      ..write(sender)
      ..write('\n')
      ..write(counter)
      ..write('\n');
    _write(out, {
      for (final entry in payload.entries)
        if (!_wireFields.contains(entry.key)) entry.key: entry.value,
    });
    return out.toString();
  }

  /// 2^53, the largest whole number a browser holds exactly.
  static const _maxSafe = 9007199254740992;

  static void _write(StringBuffer out, Object? value) {
    switch (value) {
      case null:
        out.write('n');
      case bool():
        out.write(value ? 't' : 'f');
      case num():
        // Only finite numbers come through JSON, and integers beyond 2^53
        // differ between the platforms; no game sends such numbers. Large
        // whole numbers (times in milliseconds, the start of a round) are
        // written as they are, so a tag covers them as well.
        if (value.isFinite && value.abs() < 1e12) {
          out.write((value * 1000).round());
        } else if (value.isFinite &&
            value.abs() <= _maxSafe &&
            value == value.roundToDouble()) {
          out
            ..write('i')
            ..write(value.toInt());
        } else {
          out.write('x');
        }
      case String():
        out
          ..write('s')
          ..write(value.length)
          ..write(':')
          ..write(value);
      case List<Object?>():
        out.write('[');
        for (final item in value) {
          _write(out, item);
          out.write(',');
        }
        out.write(']');
      case Map<Object?, Object?>():
        final keys = [for (final key in value.keys) key.toString()]..sort();
        out.write('{');
        for (final key in keys) {
          _write(out, key);
          out.write(':');
          _write(out, value[key]);
          out.write(',');
        }
        out.write('}');
      default:
        out.write('?');
    }
  }
}
