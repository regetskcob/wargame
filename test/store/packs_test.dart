import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:wargame/src/game/game_config.dart';
import 'package:wargame/src/game/weather.dart';
import 'package:wargame/src/net/net_events.dart';
import 'package:wargame/src/net/payloads/lobby_presence.dart';
import 'package:wargame/src/net/payloads/round_start_payload.dart';
import 'package:wargame/src/net/replay.dart';
import 'package:wargame/src/net/replay_store.dart';
import 'package:wargame/src/store/product.dart';

Replay _replay(int startedAt, {int length = 20000}) => Replay(
  round: RoundStartPayload(
    seed: 4242,
    startedAt: startedAt,
    participants: const ['a'],
  ),
  names: const {'a': 'Anna'},
  styles: const {'a': 3},
  events: [
    ReplayEvent(length, NetEvent.state, const {'id': 'a', 'x': 1.5}),
  ],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the two packs', () {
    test('are two products with a store id each and perks of their own', () {
      expect(Product.values, hasLength(2));
      expect(
        Product.byStoreId('de.regetskcob.wargame.commander'),
        Product.commander,
      );
      expect(Product.byKey('supporter'), Product.supporter);
      for (final product in Product.values) {
        expect(product.perks, isNotEmpty);
      }
    });

    test('supporter paints leave the wire format alone', () {
      // The look on the wire is vehicle * 8 + paint for every older client.
      expect(GameConfig.tankColors, hasLength(8));
      expect(
        GameConfig.supporterColors,
        isNot(contains(GameConfig.tankColors)),
      );
      for (var i = 0; i < GameConfig.supporterColors.length; i++) {
        expect(GameConfig.supporterColorName(i), isNotEmpty);
      }
    });

    test('the star travels in the presence and older clients lack it', () {
      const member = LobbyPresence(
        id: 'a',
        name: 'A',
        colorIndex: 0,
        phase: 'lobby',
        star: true,
      );
      expect(LobbyPresence.fromJson(member.toJson()).star, isTrue);
      final plain = {...member.toJson()}..remove('star');
      expect(LobbyPresence.fromJson(plain).star, isFalse);
      expect(
        LobbyPresence.tryParse({...member.toJson(), 'star': 'yes'})?.star,
        isFalse,
      );
    });
  });

  group('sky wish', () {
    // Seeds as the host's search walks through them.
    Iterable<int> seeds() sync* {
      for (var s = 1; s < 40000; s += 7) {
        yield s;
      }
    }

    test('an empty wish takes any seed', () {
      expect(const SkyWish().isEmpty, isTrue);
      expect(seeds().every(const SkyWish().fits), isTrue);
    });

    test('fog at night opens in fog and stays dark for a while', () {
      const wish = SkyWish(sky: Sky.fog, night: true);
      final fitting = seeds().where(wish.fits).toList();
      expect(fitting, isNotEmpty);
      for (final seed in fitting) {
        expect(Conditions.forSeed(seed).sky, Sky.fog);
        expect(Conditions.nightAt(seed, 0), isTrue);
        expect(Conditions.nightAt(seed, 20), isTrue);
      }
    });

    test('the hardest wish fits often enough for the 400 tries', () {
      const wish = SkyWish(sky: Sky.fog, night: true);
      final all = seeds().toList();
      expect(all.where(wish.fits).length / all.length, greaterThan(0.01));
    });

    test('a day stays day for the first minute', () {
      const wish = SkyWish(night: false);
      for (final seed in seeds().where(wish.fits).take(50)) {
        expect(Conditions.nightAt(seed, 0), isFalse);
        expect(Conditions.nightAt(seed, 60), isFalse);
      }
    });
  });

  group('archive', () {
    late Directory dir;
    late FileReplayStore store;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('replays');
      store = FileReplayStore(() async => dir);
    });

    tearDown(() async {
      await dir.delete(recursive: true);
    });

    test('a replay comes back as it went in', () async {
      await store.save(_replay(1000));
      final entry = (await store.list()).single;
      expect(entry.seed, 4242);
      expect(entry.lengthMs, 20000);
      final back = await store.load(entry);
      expect(back!.round.seed, 4242);
      expect(back.names['a'], 'Anna');
      expect(back.styles['a'], 3);
      expect(back.events.single.event, NetEvent.state);
      expect(back.events.single.payload['x'], 1.5);
    });

    test('keeps the newest ones, newest first', () async {
      for (var i = 0; i < ReplayArchive.keep + 3; i++) {
        await store.save(_replay(1000 + i));
      }
      final entries = await store.list();
      expect(entries, hasLength(ReplayArchive.keep));
      expect(entries.first.startedAt, 1000 + ReplayArchive.keep + 2);
      expect(entries.last.startedAt, 1003);
    });

    test(
      'deletes, and a stranger in the folder or broken file is no replay',
      () async {
        await store.save(_replay(1000));
        await File('${dir.path}/notes.txt').writeAsString('hello');
        final entry = (await store.list()).single;
        await File('${dir.path}/${entry.fileName}').writeAsString('broken');
        expect(await store.load(entry), isNull);
        await store.delete(entry);
        expect(await store.list(), isEmpty);
      },
    );

    test('events of a newer version are skipped', () {
      final json = ReplayArchive.toJson(_replay(1000));
      (json['events'] as List<dynamic>).add([
        1,
        'fromTheFuture',
        <String, dynamic>{},
      ]);
      expect(ReplayArchive.fromJson(json)!.events, hasLength(1));
      expect(ReplayArchive.fromJson('nonsense'), isNull);
    });
  });
}
