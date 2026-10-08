import 'package:flutter/foundation.dart';

import 'game_config.dart';
import 'components/power_up.dart';

/// One kind of item in the inventory and how many of it.
@immutable
class InventorySlot {
  const InventorySlot(this.type, this.count);

  final PowerUpType type;
  final int count;
}

/// What the local player picked up and has not used yet. Crates and gems no
/// longer act the moment the tank drives over them: they go in here, at the
/// side of the screen, and the player sets them off when it suits, with the
/// number keys or a tap.
class Inventory extends ValueNotifier<List<InventorySlot>> {
  Inventory() : super(const []);

  /// Whether [type] still fits: in its own slot, or in a free one.
  bool canTake(PowerUpType type) {
    for (final slot in value) {
      if (slot.type == type) {
        return slot.count < GameConfig.inventoryStack;
      }
    }
    return value.length < GameConfig.inventorySlots;
  }

  /// Puts one [type] in. Returns false when there is no room.
  bool add(PowerUpType type) {
    if (!canTake(type)) {
      return false;
    }
    final index = value.indexWhere((slot) => slot.type == type);
    if (index < 0) {
      value = [...value, InventorySlot(type, 1)];
    } else {
      value = [
        for (var i = 0; i < value.length; i++)
          i == index ? InventorySlot(type, value[i].count + 1) : value[i],
      ];
    }
    return true;
  }

  /// Takes one item out of slot [index], null when the slot is empty. A slot
  /// that runs out closes, the ones below move up.
  PowerUpType? take(int index) {
    if (index < 0 || index >= value.length) {
      return null;
    }
    final slot = value[index];
    value = [
      for (var i = 0; i < value.length; i++)
        if (i != index)
          value[i]
        else if (slot.count > 1)
          InventorySlot(slot.type, slot.count - 1),
    ];
    return slot.type;
  }

  void clear() => value = const [];
}
