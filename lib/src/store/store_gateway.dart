import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'product.dart';
import 'shop.dart';

/// [StoreGateway] over the `in_app_purchase` plugin: StoreKit 2 on iOS,
/// iPadOS and macOS, Play Billing on Android. Only built where those
/// exist; the watch, the TV and the web never touch the plugin, which has
/// no implementation there.
class PluginStoreGateway implements StoreGateway {
  PluginStoreGateway({required this._account});

  final InAppPurchase _plugin = InAppPurchase.instance;

  /// The signed in account's id, sent along with a purchase (StoreKit's
  /// app account token, Play's obfuscated account id), so the store ties
  /// it to the account that paid.
  final String? Function() _account;
  final _details = <String, ProductDetails>{};

  @override
  String get store =>
      defaultTargetPlatform == TargetPlatform.android ? 'play' : 'app_store';

  @override
  Future<bool> available() => _plugin.isAvailable();

  @override
  Future<List<Offer>> offers(Set<Product> products) async {
    final response = await _plugin.queryProductDetails({
      for (final product in products) product.storeId,
    });
    final offers = <Offer>[];
    for (final details in response.productDetails) {
      final product = Product.byStoreId(details.id);
      if (product == null) {
        continue;
      }
      _details[details.id] = details;
      offers.add(Offer(product: product, price: details.price));
    }
    return offers;
  }

  @override
  Future<void> buy(Product product) async {
    final details = _details[product.storeId];
    if (details == null) {
      throw StateError('${product.storeId} is not on offer');
    }
    await _plugin.buyNonConsumable(
      purchaseParam: PurchaseParam(
        productDetails: details,
        applicationUserName: _account(),
      ),
    );
  }

  @override
  Future<void> restore() =>
      _plugin.restorePurchases(applicationUserName: _account());

  @override
  Stream<List<StorePurchase>> get purchases => _plugin.purchaseStream.map(
    (list) => [
      for (final details in list)
        if (Product.byStoreId(details.productID) case final product?)
          StorePurchase(
            product: product,
            transactionId: details.purchaseID ?? '',
            proof: details.verificationData.serverVerificationData,
            restored: details.status == PurchaseStatus.restored,
            pending: details.status == PurchaseStatus.pending,
            failed: details.status == PurchaseStatus.error,
            canceled: details.status == PurchaseStatus.canceled,
            handle: details,
          ),
    ],
  );

  @override
  Future<void> finish(StorePurchase purchase) async {
    final details = purchase.handle;
    if (details is PurchaseDetails && details.pendingCompletePurchase) {
      await _plugin.completePurchase(details);
    }
  }
}
