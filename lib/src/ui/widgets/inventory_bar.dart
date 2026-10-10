import 'package:flutter/material.dart';

import '../../game/inventory.dart';
import '../theme.dart';
import 'panel.dart';

/// The inventory down the left side of the screen: one slot per kind of
/// item, with its count and the number key that sets it off. A tap does the
/// same.
class InventoryBar extends StatelessWidget {
  const InventoryBar({
    required this.inventory,
    required this.onUse,
    this.compact = false,
    this.labels,
    super.key,
  });

  final Inventory inventory;
  final ValueChanged<int> onUse;
  final bool compact;

  /// What sets off each slot, in place of the number keys: the buttons of a
  /// controller on the Apple TV. An empty label shows nothing.
  final List<String>? labels;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<InventorySlot>>(
      valueListenable: inventory,
      builder: (context, slots, _) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Only what is there: empty frames on the left edge covered the
          // road the enemies come in on.
          for (var i = 0; i < slots.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: _Slot(
                slot: slots[i],
                label: labels == null
                    ? '${i + 1}'
                    : (i < labels!.length ? labels![i] : ''),
                compact: compact,
                onTap: () => onUse(i),
              ),
            ),
        ],
      ),
    );
  }
}

class _Slot extends StatelessWidget {
  const _Slot({
    required this.slot,
    required this.label,
    required this.compact,
    required this.onTap,
  });

  final InventorySlot slot;
  final String label;
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
          color: GameColors.panel,
          shape: GameShapes.chip(edge: type.color, width: 1.8),
        ),
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(type.icon, size: compact ? 16 : 20, color: type.color),
                  const SizedBox(height: 2),
                  // The longest names (SCHNELLF., ARTILLERIE) were cut off
                  // in the 44 px slot of a phone; they shrink a little
                  // instead.
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        type.short,
                        style: TextStyle(
                          fontSize: compact ? 6.5 : 7.5,
                          letterSpacing: 0,
                          color: GameColors.text,
                        ),
                        maxLines: 1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (!compact)
              Positioned(
                left: 3,
                top: 1,
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: GameColors.sand,
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
