import 'dart:math';

import '../../game/components/power_up.dart';
import '../../game/defense/tower.dart';
import '../../game/game_phase.dart';
import '../../game/special_weapon.dart';
import '../../game/upgrades.dart';

/// What the phone's sticks and buttons hold right now, sent to the screen
/// many times a second. It mirrors the touch controls, so the screen plays
/// it as if the thumbs were on its own glass.
class PadInput {
  const PadInput({
    required this.id,
    this.drive,
    this.aim,
    this.aimHeld = false,
    this.aimFire = false,
    this.special = false,
    this.assist = false,
  });

  final String id;
  final (double, double)? drive;
  final double? aim;
  final bool aimHeld;
  final bool aimFire;
  final bool special;
  final bool assist;

  Map<String, dynamic> toJson() => {
    'id': id,
    if (drive != null) 'd': [drive!.$1, drive!.$2],
    if (aim != null) 'a': aim,
    'h': aimHeld,
    'f': aimFire,
    's': special,
    'as': assist,
  };

  /// Null for anything a phone of this game would not send. A drive longer
  /// than a full stick is cut back to one.
  static PadInput? tryParse(Map<String, dynamic> json) {
    final id = json['id'];
    final d = json['d'];
    final a = json['a'];
    if (id is! String ||
        (d != null && (d is! List || d.length != 2)) ||
        (a != null && a is! num)) {
      return null;
    }
    (double, double)? drive;
    if (d is List) {
      final x = d[0];
      final y = d[1];
      if (x is! num || y is! num || !x.isFinite || !y.isFinite) {
        return null;
      }
      final length = sqrt(x * x + y * y);
      drive = length > 1
          ? (x / length, y / length)
          : (x.toDouble(), y.toDouble());
    }
    if (a is num && !a.isFinite) {
      return null;
    }
    bool flag(String key) => json[key] == true;
    return PadInput(
      id: id,
      drive: drive,
      aim: (a as num?)?.toDouble(),
      aimHeld: flag('h'),
      aimFire: flag('f'),
      special: flag('s'),
      assist: flag('as'),
    );
  }
}

/// A single press on the phone: an item from the inventory, or the shop of
/// a defense round. [build] and [cycle] are the first phones' way to build:
/// the gun picked last, or the next kind.
enum PadActionKind {
  item,
  build,
  cycle,

  /// A gun of the `TowerKind` with the index in the slot, where the tank
  /// stands.
  place,

  /// The own gun next to the tank one level up.
  raise,

  /// The `UpgradeKind` with the index in the slot for the tank.
  upgrade,

  /// Host: the next wave now.
  wave,

  /// Host: another stretch of waves.
  extend,

  /// Host: end the secured defense as a win.
  end,
}

class PadAction {
  const PadAction({required this.id, required this.kind, this.slot = 0});

  final String id;
  final PadActionKind kind;

  /// Inventory slot, for [PadActionKind.item].
  final int slot;

  Map<String, dynamic> toJson() => {'id': id, 'k': kind.name, 'i': slot};

  static PadAction? tryParse(Map<String, dynamic> json) {
    final id = json['id'];
    final kind = PadActionKind.values.asNameMap()[json['k']];
    final slot = json['i'] ?? 0;
    if (id is! String || kind == null || slot is! int) {
      return null;
    }
    return PadAction(id: id, kind: kind, slot: slot);
  }
}

/// What the screen tells the phone about the own tank, so the phone shows
/// the special weapon, the items and how the tank is doing without looking
/// up at the screen.
class PadStatus {
  const PadStatus({
    required this.phase,
    this.name = '',
    this.hp = 1,
    this.ammo = 0,
    this.magazine = 0,
    this.special,
    this.charges = 0,
    this.items = const [],
    this.defense = false,
    this.credits = 0,
    this.tower,
    this.assist = true,
    this.shop = const [],
    this.near,
    this.upgrades = const [],
    this.callWave = false,
    this.deciding = false,
    this.canExtend = false,
    this.canEnd = false,
  });

  final GamePhase phase;
  final String name;

  /// Share of full health, 0 to 1.
  final double hp;
  final int ammo;
  final int magazine;
  final SpecialWeapon? special;
  final int charges;
  final List<(PowerUpType, int)> items;

  /// A defense round, where guns can be built.
  final bool defense;
  final int credits;
  final TowerKind? tower;

  /// Whether the round allows the aim assist. Not on hard.
  final bool assist;

  /// The guns of a defense round that are there to build: kind, cost and
  /// whether the funds, the wave and the limit allow it now.
  final List<(TowerKind, int, bool)> shop;

  /// The own gun next to the tank: kind, level, cost of the next one (0
  /// when it cannot go up) and whether the funds reach.
  final (TowerKind, int, int, bool)? near;

  /// The tank's upgrades: kind, level, the highest for now and the cost of
  /// the next.
  final List<(UpgradeKind, int, int, int)> upgrades;

  /// The host may call the next wave now.
  final bool callWave;

  /// The last wave of a stretch is held and the host decides.
  final bool deciding;

  /// The host may add waves, or end the secured round as a win.
  final bool canExtend;
  final bool canEnd;

  /// Something to build or raise within the funds.
  bool get towerReady => (near?.$4 ?? false) || shop.any((t) => t.$3);

  /// An upgrade within the funds.
  bool get upgradeReady => upgrades.any((u) => u.$2 < u.$3 && credits >= u.$4);

  Map<String, dynamic> toJson() => {
    'ph': phase.name,
    'n': name,
    'hp': hp,
    'am': ammo,
    'mg': magazine,
    if (special != null) 'sp': special!.name,
    'ch': charges,
    'it': [
      for (final (type, count) in items) [type.name, count],
    ],
    'df': defense,
    'cr': credits,
    if (tower != null) 'tw': tower!.name,
    'as': assist,
    if (shop.isNotEmpty)
      'sh': [
        for (final (kind, cost, ready) in shop) [kind.name, cost, ready],
      ],
    if (near case (final kind, final level, final cost, final ready))
      'nr': [kind.name, level, cost, ready],
    if (upgrades.isNotEmpty)
      'up': [
        for (final (kind, level, limit, cost) in upgrades)
          [kind.name, level, limit, cost],
      ],
    if (callWave) 'cw': true,
    if (deciding) 'dq': true,
    if (canExtend) 'ex': true,
    if (canEnd) 'en': true,
  };

  static PadStatus? tryParse(Map<String, dynamic> json) {
    final phase = GamePhase.values.asNameMap()[json['ph']];
    final hp = json['hp'];
    final items = json['it'];
    if (phase == null || hp is! num || items is! List) {
      return null;
    }
    final types = PowerUpType.values.asNameMap();
    final parsed = <(PowerUpType, int)>[];
    for (final item in items.take(8)) {
      if (item is! List || item.length != 2 || item[1] is! int) {
        return null;
      }
      final type = types[item[0]];
      if (type != null) {
        parsed.add((type, item[1] as int));
      }
    }
    int whole(String key) => json[key] is int ? json[key] as int : 0;
    final name = json['n'];
    return PadStatus(
      phase: phase,
      name: name is String ? name.substring(0, min(name.length, 16)) : '',
      hp: hp.isFinite ? hp.toDouble().clamp(0, 1) : 0,
      ammo: whole('am'),
      magazine: whole('mg'),
      special: SpecialWeapon.values.asNameMap()[json['sp']],
      charges: whole('ch'),
      items: parsed,
      defense: json['df'] == true,
      credits: whole('cr'),
      tower: TowerKind.values.asNameMap()[json['tw']],
      assist: json['as'] != false,
      shop: _shop(json['sh']),
      near: _near(json['nr']),
      upgrades: _upgrades(json['up']),
      callWave: json['cw'] == true,
      deciding: json['dq'] == true,
      canExtend: json['ex'] == true,
      canEnd: json['en'] == true,
    );
  }

  /// Rows of a list in [raw] that have [length] entries, the first a name.
  /// Anything else falls away: the screen of another version may send
  /// kinds this phone does not know.
  static Iterable<List<Object?>> _rows(Object? raw, int length) sync* {
    if (raw is! List) {
      return;
    }
    for (final row in raw.take(16)) {
      if (row is List && row.length == length && row.first is String) {
        yield row;
      }
    }
  }

  static int _whole(Object? value) => value is int ? max(0, value) : 0;

  static List<(TowerKind, int, bool)> _shop(Object? raw) => [
    for (final row in _rows(raw, 3))
      if (TowerKind.values.asNameMap()[row[0]] case final kind?)
        (kind, _whole(row[1]), row[2] == true),
  ];

  static (TowerKind, int, int, bool)? _near(Object? raw) {
    final row = _rows([raw], 4).firstOrNull;
    final kind = TowerKind.values.asNameMap()[row?[0]];
    if (row == null || kind == null) {
      return null;
    }
    return (kind, _whole(row[1]), _whole(row[2]), row[3] == true);
  }

  static List<(UpgradeKind, int, int, int)> _upgrades(Object? raw) => [
    for (final row in _rows(raw, 4))
      if (UpgradeKind.values.asNameMap()[row[0]] case final kind?)
        (kind, _whole(row[1]), _whole(row[2]), _whole(row[3])),
  ];
}
