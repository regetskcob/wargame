import 'dart:async';

import 'package:flutter/material.dart';
import 'package:horizont/horizont.dart';

import '../../l10n/l10n.dart';
import '../../store/product.dart';
import '../../store/shop.dart';
import '../theme.dart';
import 'panel.dart';

/// The two packs on the account page, each in the same sunken box as the
/// controllers, with one way to restore below them. Shown only where [shop]
/// can sell (docs/purchases.md); a guest sees the offers and that they need
/// an account. Each pack stands alone: a store that lists only one sells
/// that one.
class SupporterSection extends StatelessWidget {
  const SupporterSection({required this.shop, required this.guest, super.key});

  final Shop shop;
  final bool guest;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        shop.offers,
        shop.owned,
        shop.busy,
        shop.message,
      ]),
      builder: (context, _) {
        final busy = shop.busy.value;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final product in Product.values)
              if (shop.owns(product) ||
                  shop.offers.value.any((o) => o.product == product)) ...[
                _pack(product, busy),
                const SizedBox(height: HzSpace.s12),
              ],
            if (guest)
              Text(
                tr(
                  'Käufe gibt es nur mit Konto: Melde dich oben an.',
                  'Purchases need an account: sign in above.',
                ),
                style: GameType.caption,
              )
            else
              OutlinedButton(
                onPressed: busy ? null : () => unawaited(shop.restore()),
                child: Text(tr('KÄUFE WIEDERHERSTELLEN', 'RESTORE PURCHASES')),
              ),
            if (shop.message.value case final message?) ...[
              const SizedBox(height: HzSpace.s8),
              Text(message, style: GameType.callout),
            ],
          ],
        );
      },
    );
  }

  Widget _pack(Product product, bool busy) {
    final owned = shop.owns(product);
    final offer = shop.offers.value
        .where((o) => o.product == product)
        .firstOrNull;
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: GameColors.sunken,
        shape: GameShapes.card(),
      ),
      child: Padding(
        padding: const EdgeInsets.all(HzSpace.s12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  switch (product) {
                    Product.supporter =>
                      owned ? HorizontSymbols.starFill : HorizontSymbols.star,
                    Product.commander => HorizontSymbols.militaryTech,
                  },
                  color: GameColors.textMuted,
                  size: HzIconSize.row,
                ),
                const SizedBox(width: HzSpace.s8),
                Kennung(product.title),
              ],
            ),
            const SizedBox(height: HzSpace.s8),
            Text(
              owned
                  ? tr(
                      'Danke! Du unterstützt Panzergefecht, alles ist '
                          'freigeschaltet.',
                      'Thank you! You support Panzergefecht, everything is '
                          'unlocked.',
                    )
                  : product.benefit,
              style: GameType.callout,
            ),
            const SizedBox(height: HzSpace.s8),
            for (final perk in product.perks)
              Padding(
                padding: const EdgeInsets.only(bottom: HzSpace.s4),
                child: Text('– $perk', style: GameType.caption),
              ),
            if (!owned && offer != null) ...[
              const SizedBox(height: HzSpace.s8),
              FilledButton(
                onPressed: busy || guest
                    ? null
                    : () => unawaited(shop.buy(product)),
                child: Text(
                  tr('FÜR ${offer.price} KAUFEN', 'BUY FOR ${offer.price}'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
