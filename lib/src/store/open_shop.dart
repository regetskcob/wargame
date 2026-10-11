import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../app/env.dart';
import '../db/account_service.dart';
import '../db/purchase_service.dart';
import '../tv/tv_input.dart';
import '../watch/watch_support.dart';
import 'shop.dart';
import 'store_gateway.dart';

/// The shop for this build and device, or null while purchases are off
/// (`PURCHASES`, see docs/purchases.md). Only phones, tablets and Macs get
/// a store to buy in; the web, the watch and the TV have no store in the
/// plugin, and what an account bought elsewhere does not show there yet.
Shop? openShop(AccountService accounts) {
  if (!Env.purchases) {
    return null;
  }
  final storeHere =
      !kIsWeb &&
      !onWatch &&
      !onTv &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.android);
  bool signedIn() => !accounts.isGuest;
  final server = PurchaseService(Supabase.instance.client);
  if (!storeHere) {
    return Shop.closed(server: server, signedIn: signedIn);
  }
  return Shop(
    gateway: PluginStoreGateway(
      account: () => signedIn() ? accounts.user.value?.id : null,
    ),
    server: server,
    signedIn: signedIn,
  );
}
