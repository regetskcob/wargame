import '../l10n/l10n.dart';

/// What the game sells once in-app purchases are live (docs/purchases.md).
/// Nothing here decides a fight: vehicles stay with the rank, experience
/// and rating cannot be bought, so the leaderboard stays honest.
enum Product {
  /// A one-time purchase to support the game: a star on the pilot card.
  supporter('supporter');

  const Product(this.key);

  /// The id in the `entitlements` table and in the edge function
  /// verify-purchase.
  final String key;

  /// The id in App Store Connect and the Play Console.
  String get storeId => 'de.regetskcob.wargame.$key';

  String get title => switch (this) {
    supporter => tr('UNTERSTÜTZER', 'SUPPORTER'),
  };

  String get benefit => switch (this) {
    supporter => tr(
      'Einmal zahlen, das Spiel unterstützen: ohne Werbung, ohne Abo. Dafür '
          'ein Stern auf der Pilotenkarte. Spielvorteile gibt es keine.',
      'Pay once to support the game: no ads, no subscription. You get a '
          'star on your pilot card. No advantage in play.',
    ),
  };

  static Product? byKey(String key) {
    for (final product in values) {
      if (product.key == key) {
        return product;
      }
    }
    return null;
  }

  static Product? byStoreId(String id) {
    for (final product in values) {
      if (product.storeId == id) {
        return product;
      }
    }
    return null;
  }
}
