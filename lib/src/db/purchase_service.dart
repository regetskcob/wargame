// The typed table access API is still experimental.
// ignore_for_file: experimental_member_use

import 'package:supabase_flutter/supabase_flutter.dart';

import '../store/product.dart';
import '../store/shop.dart';
import 'supabase_schema.g.dart';

/// [PurchaseServer] on Supabase: the edge function verify-purchase checks a
/// purchase with Apple or Google and enters it (migration 0021), the table
/// `entitlements` lists what the signed in account owns. Both fail quietly,
/// so a database without the table or a project without the function owns
/// nothing and the game plays on.
class PurchaseService implements PurchaseServer {
  PurchaseService(this._client);

  final SupabaseClient _client;

  @override
  Future<bool> verify(String store, StorePurchase purchase) async {
    try {
      final response = await _client.functions.invoke(
        'verify-purchase',
        body: {
          'store': store,
          'product': purchase.product.key,
          'transaction_id': purchase.transactionId,
          'proof': purchase.proof,
        },
      );
      final data = response.data;
      return data is Map && data['granted'] == true;
    } on Object {
      return false;
    }
  }

  @override
  Future<Set<Product>> owned() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) {
      return const {};
    }
    try {
      final rows = await _client
          .table(Entitlements.table)
          .select()
          .where(Entitlements.playerId.eq(uid));
      return {for (final row in rows) ?Product.byKey(row.product)};
    } on Object {
      return const {};
    }
  }
}
