import 'dart:math';

import '../../game/components/power_up.dart';
import '../../game/defense/tower.dart';
import '../../game/game_phase.dart';
import '../../game/special_weapon.dart';

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

/// A single press on the phone: an item from the inventory, or building and
/// switching guns in a defense round.
enum PadActionKind { item, build, cycle }

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
    );
  }
}
