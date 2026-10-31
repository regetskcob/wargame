import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../store/product.dart';
import 'net_events.dart';
import 'payloads/round_start_payload.dart';
import 'replay.dart';

/// What the archive knows about a kept battle without opening its file.
class ArchivedReplay {
  const ArchivedReplay({
    required this.startedAt,
    required this.seed,
    required this.lengthMs,
    required this.kind,
  });

  final int startedAt;
  final int seed;
  final int lengthMs;

  /// `s` alone or against others, `d` defense, `f` capture the flag.
  final String kind;

  String get fileName => '${startedAt}_${seed}_${lengthMs}_$kind.rpl';

  static final _name = RegExp(r'^(\d+)_(-?\d+)_(\d+)_([sdf])\.rpl$');

  static ArchivedReplay? parse(String fileName) {
    final match = _name.firstMatch(fileName);
    if (match == null) {
      return null;
    }
    return ArchivedReplay(
      startedAt: int.parse(match[1]!),
      seed: int.parse(match[2]!),
      lengthMs: int.parse(match[3]!),
      kind: match[4]!,
    );
  }

  static ArchivedReplay of(Replay replay) => ArchivedReplay(
    startedAt: replay.round.startedAt,
    seed: replay.round.seed,
    lengthMs: replay.length,
    kind: replay.round.defense
        ? 'd'
        : replay.round.flag
        ? 'f'
        : 's',
  );
}

/// The commander's battles on this device, newest first. Replays stay local
/// like the last one always did: nothing here goes to a server, so the
/// archive costs neither storage nor Realtime budget.
abstract interface class ReplayStore {
  Future<List<ArchivedReplay>> list();
  Future<void> save(Replay replay);
  Future<Replay?> load(ArchivedReplay entry);
  Future<void> delete(ArchivedReplay entry);
}

abstract final class ReplayArchive {
  static const keep = ProductLimits.archivedReplays;

  /// Rounds shorter than this are left out.
  static const shortestMs = 15000;

  static Map<String, dynamic> toJson(Replay replay) => {
    'round': replay.round.toJson(),
    'names': replay.names,
    'styles': replay.styles,
    'events': [
      for (final event in replay.events)
        [event.at, event.event.name, event.payload],
    ],
  };

  /// Null for anything that is no replay of a version this client can
  /// read; events of a newer version are skipped.
  static Replay? fromJson(Object? json) {
    try {
      json as Map<String, dynamic>;
      return Replay(
        round: RoundStartPayload.fromJson(
          json['round'] as Map<String, dynamic>,
        ),
        names: (json['names'] as Map<String, dynamic>).cast<String, String>(),
        styles: (json['styles'] as Map<String, dynamic>).cast<String, int>(),
        events: [
          for (final raw in json['events'] as List<dynamic>)
            if (_event((raw as List<dynamic>)[1]) case final event?)
              ReplayEvent(raw[0] as int, event, raw[2] as Map<String, dynamic>),
        ],
      );
    } on Object {
      return null;
    }
  }

  static NetEvent? _event(Object? name) {
    for (final event in NetEvent.values) {
      if (event.name == name) {
        return event;
      }
    }
    return null;
  }
}

/// The store on this device, null where no files can be kept.
ReplayStore? openReplayStore() => kIsWeb
    ? null
    : FileReplayStore(() async {
        final base = await getApplicationSupportDirectory();
        return Directory('${base.path}/replays');
      });

/// One gzipped JSON file per battle. The name holds what the list shows, so
/// listing never opens a file of several megabytes. Everything fails quietly:
/// a full disk costs an archive entry, never the round.
class FileReplayStore implements ReplayStore {
  FileReplayStore(this._directory);

  final Future<Directory> Function() _directory;

  @override
  Future<List<ArchivedReplay>> list() async {
    try {
      final dir = await _directory();
      if (!await dir.exists()) {
        return const [];
      }
      final entries = <ArchivedReplay>[];
      await for (final file in dir.list()) {
        final name = file.uri.pathSegments.last;
        if (ArchivedReplay.parse(name) case final entry?) {
          entries.add(entry);
        }
      }
      return entries..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    } on Object {
      return const [];
    }
  }

  @override
  Future<void> save(Replay replay) async {
    try {
      final dir = await _directory();
      await dir.create(recursive: true);
      // Off the game's isolate: a long defense round packs for a moment.
      final bytes = await compute(_pack, ReplayArchive.toJson(replay));
      final entry = ArchivedReplay.of(replay);
      await File('${dir.path}/${entry.fileName}').writeAsBytes(bytes);
      final all = await list();
      for (final old in all.skip(ReplayArchive.keep)) {
        await delete(old);
      }
    } on Object {
      // See the class.
    }
  }

  @override
  Future<Replay?> load(ArchivedReplay entry) async {
    try {
      final dir = await _directory();
      final bytes = await File('${dir.path}/${entry.fileName}').readAsBytes();
      return ReplayArchive.fromJson(await compute(_unpack, bytes));
    } on Object {
      return null;
    }
  }

  @override
  Future<void> delete(ArchivedReplay entry) async {
    try {
      final dir = await _directory();
      await File('${dir.path}/${entry.fileName}').delete();
    } on Object {
      // Already gone.
    }
  }
}

List<int> _pack(Map<String, dynamic> json) =>
    gzip.encode(utf8.encode(jsonEncode(json)));

Object? _unpack(List<int> bytes) => jsonDecode(utf8.decode(gzip.decode(bytes)));
