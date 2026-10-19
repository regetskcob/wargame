import 'dart:async';

import 'package:flutter/material.dart';
import 'package:horizont/horizont.dart';

import '../../l10n/l10n.dart';
import '../../store/product.dart';
import '../../store/shop.dart';
import '../theme.dart';
import 'panel.dart';

/// The supporter pack on the account page, in the same sunken box as the
/// controllers. Shown only where [shop] can sell (docs/purchases.md);
/// a guest sees the offer and that it needs an account.
class SupporterSection extends StatelessWidget {
  const SupporterSection({required this.shop, required this.guest, super.key});

  final Shop shop;
  final bool guest;

  static const _product = Product.supporter;

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
        final offer = shop.offers.value
            .where((o) => o.product == _product)
            .firstOrNull;
        final owned = shop.owns(_product);
        final busy = shop.busy.value;
        return DecoratedBox(
          decoration: ShapeDecoration(
            color: GameColors.sunken,
            shape: GameShapes.card(),
          ),
          child: Padding(
            padding: const EdgeInsets.all(HzSpace.s12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      owned ? Icons.star : Icons.star_outline,
                      color: GameColors.textMuted,
                      size: HzIconSize.row,
                    ),
                    const SizedBox(width: HzSpace.s8),
                    Kennung(_product.title),
                  ],
                ),
                const SizedBox(height: HzSpace.s8),
                Text(
                  owned
                      ? tr(
                          'Danke! Du unterstützt Panzergefecht, dein Stern '
                              'steht auf deiner Pilotenkarte.',
                          'Thank you! You support Panzergefecht, your star '
                              'sits on your pilot card.',
                        )
                      : _product.benefit,
                  style: GameType.callout,
                ),
                if (!owned && guest) ...[
                  const SizedBox(height: HzSpace.s8),
                  Text(
                    tr(
                      'Käufe gibt es nur mit Konto: Melde dich oben an.',
                      'Purchases need an account: sign in above.',
                    ),
                    style: GameType.caption,
                  ),
                ],
                const SizedBox(height: HzSpace.s12),
                Row(
                  children: [
                    if (!owned)
                      Expanded(
                        child: FilledButton(
                          onPressed: busy || guest || offer == null
                              ? null
                              : () => unawaited(shop.buy(_product)),
                          child: Text(
                            offer == null
                                ? _product.title
                                : tr(
                                    'FÜR ${offer.price} UNTERSTÜTZEN',
                                    'SUPPORT FOR ${offer.price}',
                                  ),
                          ),
                        ),
                      ),
                    if (!owned) const SizedBox(width: HzSpace.s12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: busy || guest
                            ? null
                            : () => unawaited(shop.restore()),
                        child: Text(
                          tr('KÄUFE WIEDERHERSTELLEN', 'RESTORE PURCHASES'),
                        ),
                      ),
                    ),
                  ],
                ),
                if (shop.message.value case final message?) ...[
                  const SizedBox(height: HzSpace.s8),
                  Text(message, style: GameType.callout),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
