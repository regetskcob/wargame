import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../store/product.dart';
import '../../store/shop.dart';
import '../theme.dart';

/// The supporter pack on the account page, in the same quiet dark box as
/// the controllers. Shown only where [shop] can sell (docs/purchases.md);
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
          decoration: BoxDecoration(
            color: const Color(0x55000000),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      owned ? Icons.star : Icons.star_outline,
                      color: GameColors.sand,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _product.title,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                        color: GameColors.textDim,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  owned
                      ? tr(
                          'Danke! Du unterstützt Panzergefecht, dein Stern '
                              'steht auf deiner Pilotenkarte.',
                          'Thank you! You support Panzergefecht, your star '
                              'sits on your pilot card.',
                        )
                      : _product.benefit,
                ),
                if (!owned && guest) ...[
                  const SizedBox(height: 6),
                  Text(
                    tr(
                      'Käufe gibt es nur mit Konto: Melde dich oben an.',
                      'Purchases need an account: sign in above.',
                    ),
                    style: const TextStyle(color: GameColors.textDim),
                  ),
                ],
                const SizedBox(height: 12),
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
                    if (!owned) const SizedBox(width: 12),
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
                  const SizedBox(height: 8),
                  Text(message),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
