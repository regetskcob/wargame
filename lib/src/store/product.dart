import '../l10n/l10n.dart';

/// What the game sells once in-app purchases are live (docs/purchases.md):
/// two packs, bought apart or together, neither containing the other.
/// Nothing here decides a fight: vehicles stay with the rank, experience
/// and rating cannot be bought, so the leaderboard stays honest.
enum Product {
  /// The look: exclusive paints, a mark on the tank and a star in the room.
  supporter('supporter'),

  /// The battle: the opening weather and light for the whole room, the
  /// replay archive and the service record.
  commander('commander');

  const Product(this.key);

  /// The id in the `entitlements` table and in the edge function
  /// verify-purchase.
  final String key;

  /// The id in App Store Connect and the Play Console.
  String get storeId => 'de.regetskcob.wargame.$key';

  String get title => switch (this) {
    supporter => tr('UNTERSTÜTZER', 'SUPPORTER'),
    commander => tr('KOMMANDEUR', 'COMMANDER'),
  };

  String get benefit => switch (this) {
    supporter => tr(
      'Zeig, dass du dabei bist. Einmal zahlen, kein Abo, kein Vorteil im '
          'Gefecht.',
      'Show that you are in. Pay once, no subscription, no advantage in '
          'battle.',
    ),
    commander => tr(
      'Bestimme das Gefecht und behalte es. Einmal zahlen, kein Abo, kein '
          'Vorteil im Gefecht.',
      'Set the battle and keep it. Pay once, no subscription, no advantage '
          'in battle.',
    ),
  };

  /// What the pack brings, one line each.
  List<String> get perks => switch (this) {
    supporter => [
      tr(
        'Vier exklusive Tarnungen für deine Einzelgefechte',
        'Four exclusive paints for your solo battles',
      ),
      tr(
        'Feldzeichen auf deinem Panzer, für alle im Gefecht sichtbar',
        'A mark on your tank that everybody in battle sees',
      ),
      tr(
        'Ehrenzeichen in der Raumliste, Stern auf deiner Pilotenkarte',
        'A mark of honour in the room list, a star on your pilot card',
      ),
    ],
    commander => [
      tr(
        'Als Gastgeber Startwetter und Tageszeit wählen, der ganze Raum '
            'spielt mit',
        'As the host pick the opening weather and time of day, the whole '
            'room plays along',
      ),
      tr(
        'Einsatzarchiv: deine letzten ${ProductLimits.archivedReplays} '
            'Gefechte auf dem Gerät, jederzeit wieder ansehen',
        'Battle archive: your last ${ProductLimits.archivedReplays} battles '
            'on the device, to watch again at any time',
      ),
      tr(
        'Einsatzakte: Bilanz je Fahrzeug auf deiner Pilotenkarte',
        'Service record: the score per vehicle on your pilot card',
      ),
    ],
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

/// Numbers the packs promise, in one place with the texts that name them.
abstract final class ProductLimits {
  static const archivedReplays = 10;
}
