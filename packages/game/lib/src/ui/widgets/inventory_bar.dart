import 'package:flutter/material.dart';

import '../../game/inventory.dart';
import '../../game_config.dart';
import '../../theme.dart';
import 'panel.dart';

/// The inventory down the left side of the screen: one slot per kind of
/// item, with its count and the number key that sets it off. A tap does the
/// same.
class InventoryBar extends StatelessWidget {
  const InventoryBar({
    required this.inventory,
    required this.onUse,
    this.compact = false,
    super.key,
  });

  final Inventory inventory;
  final ValueChanged<int> onUse;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<InventorySlot>>(
      valueListenable: inventory,
      builder: (context, slots, _) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Phones only show what is there, the screen is short.
          for (
            var i = 0;
            i < (compact ? slots.length : GameConfig.inventorySlots);
            i++
          )
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: i < slots.length
                  ? _Slot(
                      slot: slots[i],
                      number: i + 1,
                      compact: compact,
                      onTap: () => onUse(i),
                    )
                  : _Empty(compact: compact),
            ),
        ],
      ),
    );
  }
}

class _Slot extends StatelessWidget {
  const _Slot({
    required this.slot,
    required this.number,
    required this.compact,
    required this.onTap,
  });

  final InventorySlot slot;
  final int number;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final type = slot.type;
    final size = compact ? 44.0 : 56.0;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: ShapeDecoration(
          color: BwColors.panel,
          shape: BwShapes.chip(edge: type.color, width: 1.8),
        ),
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(type.icon, size: compact ? 16 : 20, color: type.color),
                  const SizedBox(height: 2),
                  Text(
                    type.short,
                    style: TextStyle(
                      fontSize: compact ? 6.5 : 7.5,
                      letterSpacing: 0,
                      color: BwColors.text,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                  ),
                ],
              ),
            ),
            if (!compact)
              Positioned(
                left: 3,
                top: 1,
                child: Text(
                  '$number',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: BwColors.sand,
                  ),
                ),
              ),
            if (slot.count > 1)
              Positioned(
                right: 3,
                top: 1,
                child: Text(
                  '×${slot.count}',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: type.color,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 44.0 : 56.0;
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: ShapeDecoration(
          color: const Color(0x33000000),
          shape: BwShapes.chip(edge: const Color(0x338A9A5B), width: 1),
        ),
      ),
    );
  }
}
