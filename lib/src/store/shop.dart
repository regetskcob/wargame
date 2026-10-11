import 'dart:async';

import 'package:flutter/foundation.dart';

import '../l10n/l10n.dart';
import 'product.dart';

/// A product as the store offers it, with the price in the buyer's
/// currency.
class Offer {
  const Offer({required this.product, required this.price});

  final Product product;
  final String price;
}

/// A purchase the store reports, new or restored, still to be checked by
/// the server.
class StorePurchase {
  const StorePurchase({
    required this.product,
    required this.transactionId,
    required this.proof,
    this.restored = false,
    this.pending = false,
    this.failed = false,
    this.canceled = false,
    this.handle,
  });

  final Product product;
  final String transactionId;

  /// What the server shows the store: the signed transaction on Apple's
  /// side, the purchase token on Google's.
  final String proof;
  final bool restored;

  /// Waiting for a parent's approval or a payment to clear.
  final bool pending;
  final bool failed;

  /// The buyer closed the store's sheet: nothing to say.
  final bool canceled;

  /// The plugin's own purchase object, handed back to finish it.
  final Object? handle;
}

/// Apple's or Google's store, behind one face so the shop can be tested
/// without either.
abstract interface class StoreGateway {
  /// `app_store` or `play`, as the database writes it.
  String get store;
  Future<bool> available();
  Future<List<Offer>> offers(Set<Product> products);
  Future<void> buy(Product product);
  Future<void> restore();
  Stream<List<StorePurchase>> get purchases;

  /// Tells the store the purchase was handled, so it stops reporting it.
  Future<void> finish(StorePurchase purchase);
}

/// The server's side: the edge function verify-purchase asks Apple or
/// Google whether a purchase is real and only then enters it, and the
/// table `entitlements` says what the signed in account owns.
abstract interface class PurchaseServer {
  /// Whether the server accepted [purchase] for the signed in account.
  Future<bool> verify(String store, StorePurchase purchase);

  /// What the signed in account owns; empty when it cannot be read.
  Future<Set<Product>> owned();
}

/// The shop on the account page. Off unless the build has `PURCHASES=true`
/// and the platform has a store (docs/purchases.md); purchases need an
/// account, never a guest, so a purchase is never lost with a device and
/// counts wherever the account signs in, the web, the watch and the TV
/// included.
class Shop {
  Shop({
    required this._gateway,
    required this._server,
    required this._signedIn,
  });

  /// A shop that sells nothing, for builds and platforms without one. It
  /// still knows what the account owns.
  Shop.closed({
    required PurchaseServer server,
    required bool Function() signedIn,
  }) : this(gateway: null, server: server, signedIn: signedIn);

  final StoreGateway? _gateway;
  final PurchaseServer _server;
  final bool Function() _signedIn;
  StreamSubscription<List<StorePurchase>>? _updates;

  /// Whether this device can buy at all. The section stays away otherwise.
  final open = ValueNotifier<bool>(false);
  final offers = ValueNotifier<List<Offer>>(const []);
  final owned = ValueNotifier<Set<Product>>(const {});
  final busy = ValueNotifier<bool>(false);

  /// What the last purchase or restore came to, for a line under the
  /// buttons.
  final message = ValueNotifier<String?>(null);

  bool owns(Product product) => owned.value.contains(product);

  Future<void> start() async {
    await refresh();
    final gateway = _gateway;
    if (gateway == null || !await gateway.available()) {
      return;
    }
    _updates = gateway.purchases.listen(_handle);
    offers.value = await gateway.offers(Product.values.toSet());
    open.value = offers.value.isNotEmpty;
  }

  /// Reads what the account owns, after signing in or out.
  Future<void> refresh() async {
    owned.value = _signedIn() ? await _server.owned() : const {};
  }

  Future<void> buy(Product product) async {
    final gateway = _gateway;
    if (gateway == null || busy.value) {
      return;
    }
    if (!_signedIn()) {
      message.value = _signInFirst;
      return;
    }
    busy.value = true;
    message.value = null;
    try {
      await gateway.buy(product);
    } on Object {
      busy.value = false;
      message.value = _failed;
    }
  }

  Future<void> restore() async {
    final gateway = _gateway;
    if (gateway == null || busy.value) {
      return;
    }
    if (!_signedIn()) {
      message.value = _signInFirst;
      return;
    }
    busy.value = true;
    message.value = null;
    try {
      await gateway.restore();
    } on Object {
      message.value = _failed;
    } finally {
      busy.value = false;
    }
  }

  Future<void> _handle(List<StorePurchase> purchases) async {
    final gateway = _gateway!;
    for (final purchase in purchases) {
      if (purchase.pending) {
        message.value = tr(
          'Der Kauf wartet noch auf die Freigabe.',
          'The purchase is waiting for approval.',
        );
        continue;
      }
      if (purchase.failed || purchase.canceled) {
        message.value = purchase.canceled ? null : _failed;
        await gateway.finish(purchase);
        continue;
      }
      // A guest's purchase stays open in the store and is checked once an
      // account signs in and restores.
      if (!_signedIn()) {
        message.value = _signInFirst;
        continue;
      }
      if (await _server.verify(gateway.store, purchase)) {
        owned.value = {...owned.value, purchase.product};
        message.value = purchase.restored
            ? tr('Käufe wiederhergestellt.', 'Purchases restored.')
            : tr('Danke für deine Unterstützung!', 'Thanks for your support!');
        await gateway.finish(purchase);
      } else {
        // Left open, so the store reports it again and the next try can
        // still count it.
        message.value = tr(
          'Der Kauf ließ sich nicht prüfen. Später über „Käufe '
              'wiederherstellen“ erneut versuchen.',
          'The purchase could not be checked. Try again later with '
              '"Restore purchases".',
        );
      }
    }
    busy.value = false;
  }

  void dispose() {
    unawaited(_updates?.cancel());
  }

  static String get _signInFirst => tr(
    'Käufe gibt es nur mit Konto. Melde dich zuerst an.',
    'Purchases need an account. Sign in first.',
  );

  static String get _failed =>
      tr('Der Kauf hat nicht geklappt.', 'The purchase did not go through.');
}
