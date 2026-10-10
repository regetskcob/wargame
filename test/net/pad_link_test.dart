import 'package:flutter_test/flutter_test.dart';
import 'package:wargame/src/game/components/power_up.dart';
import 'package:wargame/src/game/defense/tower.dart';
import 'package:wargame/src/game/game_phase.dart';
import 'package:wargame/src/game/special_weapon.dart';
import 'package:wargame/src/game/upgrades.dart';
import 'package:wargame/src/net/pad_link.dart';
import 'package:wargame/src/net/payloads/pad_payload.dart';

void main() {
  group('pairing codes', () {
    test('a fresh code reads back', () {
      final code = newPadCode();
      expect(code, hasLength(padCodeLength));
      expect(padCodeFrom(code), code);
    });

    test('typed with a gap, in small letters or as a link', () {
      expect(padCodeFrom('abcd efgh'), 'ABCDEFGH');
      expect(padCodeFrom('ABCD-EFGH'), 'ABCDEFGH');
      expect(padCodeFrom('ABCD\u200bEFGH\n'), 'ABCDEFGH');
      expect(
        padCodeFrom('https://www.regetskcob.de/wargame/?pad=ABCDEFGH'),
        'ABCDEFGH',
      );
    });

    test('room links, short codes and look-alike letters are refused', () {
      expect(
        padCodeFrom('https://www.regetskcob.de/wargame/?room=ABCDE'),
        isNull,
      );
      expect(padCodeFrom('ABCDE'), isNull);
      // O, I, 0 and 1 are left out of the alphabet.
      expect(padCodeFrom('ABCDEFG0'), isNull);
      expect(padCodeFrom(''), isNull);
    });
  });

  group('pad input', () {
    test('goes through and back', () {
      const input = PadInput(
        id: 'p',
        drive: (0.6, -0.8),
        aim: 1.5,
        aimHeld: true,
        aimFire: true,
        special: true,
        assist: true,
      );
      final back = PadInput.tryParse(input.toJson())!;
      expect(back.drive, (0.6, -0.8));
      expect(back.aim, 1.5);
      expect(back.aimHeld && back.aimFire && back.special && back.assist, true);
    });

    test('a resting phone sends no drive and no aim', () {
      final back = PadInput.tryParse(const PadInput(id: 'p').toJson())!;
      expect(back.drive, isNull);
      expect(back.aim, isNull);
      expect(back.aimFire, false);
    });

    test('an overlong drive is cut to a full stick', () {
      final back = PadInput.tryParse({
        'id': 'p',
        'd': [30, 40],
      })!;
      expect(back.drive!.$1, closeTo(0.6, 1e-9));
      expect(back.drive!.$2, closeTo(0.8, 1e-9));
    });

    test('hostile messages are dropped', () {
      expect(PadInput.tryParse({}), isNull);
      expect(PadInput.tryParse({'id': 1}), isNull);
      expect(PadInput.tryParse({'id': 'p', 'd': 'x'}), isNull);
      expect(
        PadInput.tryParse({
          'id': 'p',
          'd': [1],
        }),
        isNull,
      );
      expect(
        PadInput.tryParse({
          'id': 'p',
          'd': ['a', 1],
        }),
        isNull,
      );
      expect(
        PadInput.tryParse({
          'id': 'p',
          'd': [double.nan, 0],
        }),
        isNull,
      );
      expect(PadInput.tryParse({'id': 'p', 'a': double.infinity}), isNull);
      expect(PadInput.tryParse({'id': 'p', 'a': '1'}), isNull);
    });
  });

  group('pad action', () {
    test('goes through and back', () {
      final back = PadAction.tryParse(
        const PadAction(id: 'p', kind: PadActionKind.item, slot: 2).toJson(),
      )!;
      expect(back.kind, PadActionKind.item);
      expect(back.slot, 2);
    });

    test('unknown kinds are dropped', () {
      expect(PadAction.tryParse({'id': 'p', 'k': 'nuke'}), isNull);
      expect(PadAction.tryParse({'id': 'p', 'k': 'item', 'i': '1'}), isNull);
    });
  });

  group('pad status', () {
    test('goes through and back', () {
      const status = PadStatus(
        phase: GamePhase.playing,
        name: 'Wolf',
        hp: 0.5,
        ammo: 7,
        magazine: 20,
        special: SpecialWeapon.drone,
        charges: 2,
        items: [(PowerUpType.repair, 2), (PowerUpType.smoke, 1)],
        defense: true,
        credits: 300,
        tower: TowerKind.cannon,
        assist: false,
      );
      final back = PadStatus.tryParse(status.toJson())!;
      expect(back.phase, GamePhase.playing);
      expect(back.name, 'Wolf');
      expect(back.hp, 0.5);
      expect(back.ammo, 7);
      expect(back.magazine, 20);
      expect(back.special, SpecialWeapon.drone);
      expect(back.charges, 2);
      expect(back.items, [(PowerUpType.repair, 2), (PowerUpType.smoke, 1)]);
      expect(back.defense, true);
      expect(back.credits, 300);
      expect(back.tower, TowerKind.cannon);
      expect(back.assist, false);
    });

    test('carries the defense shop and the host\'s calls', () {
      const status = PadStatus(
        phase: GamePhase.playing,
        defense: true,
        credits: 150,
        shop: [(TowerKind.cannon, 100, true), (TowerKind.howitzer, 220, false)],
        near: (TowerKind.flak, 2, 180, false),
        upgrades: [
          (UpgradeKind.armor, 1, 3, 100),
          (UpgradeKind.gun, 3, 3, 400),
        ],
        callWave: true,
        deciding: true,
        canExtend: true,
        canEnd: true,
      );
      final back = PadStatus.tryParse(status.toJson())!;
      expect(back.shop, status.shop);
      expect(back.near, status.near);
      expect(back.upgrades, status.upgrades);
      expect(back.callWave, isTrue);
      expect(back.deciding, isTrue);
      expect(back.canExtend, isTrue);
      expect(back.canEnd, isTrue);
      // A gun or an armour step within the funds, the maxed gun is not.
      expect(back.towerReady, isTrue);
      expect(back.upgradeReady, isTrue);
      // An older screen sends none of it.
      final plain = PadStatus.tryParse(
        const PadStatus(phase: GamePhase.playing).toJson(),
      )!;
      expect(plain.shop, isEmpty);
      expect(plain.near, isNull);
      expect(plain.towerReady, isFalse);
    });

    test('a shop it does not know is dropped row by row', () {
      final odd = PadStatus.tryParse({
        'ph': 'playing',
        'hp': 1,
        'it': [],
        'sh': [
          ['laser', 10, true],
          ['cannon', -5, true],
          'x',
        ],
        'nr': ['flak', 'two', 3, true],
        'up': [
          ['armor', 1, 3],
          ['gun', 1, 3, 200],
        ],
      })!;
      expect(odd.shop, [(TowerKind.cannon, 0, true)]);
      expect(odd.near, (TowerKind.flak, 0, 3, true));
      expect(odd.upgrades, [(UpgradeKind.gun, 1, 3, 200)]);
      expect(
        PadStatus.tryParse({'ph': 'playing', 'hp': 1, 'it': [], 'nr': 4})?.near,
        isNull,
      );
    });

    test('odd values are tamed, broken ones dropped', () {
      final odd = PadStatus.tryParse({
        'ph': 'lobby',
        'hp': 5,
        'it': [
          ['laser', 1],
        ],
        'n': 'x' * 40,
        'sp': 'nuke',
      })!;
      expect(odd.hp, 1);
      expect(odd.items, isEmpty);
      expect(odd.name, hasLength(16));
      expect(odd.special, isNull);
      expect(PadStatus.tryParse({'ph': 'party', 'hp': 1, 'it': []}), isNull);
      expect(PadStatus.tryParse({'ph': 'lobby', 'hp': 1, 'it': 'x'}), isNull);
      expect(
        PadStatus.tryParse({
          'ph': 'lobby',
          'hp': 1,
          'it': [
            ['repair', 'x'],
          ],
        }),
        isNull,
      );
    });
  });
}
