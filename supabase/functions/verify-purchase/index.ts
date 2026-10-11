// verify-purchase: enters an in-app purchase for the signed in account once
// Apple or Google confirmed it (docs/purchases.md). Prepared, not deployed:
// purchases are off in every build until the products, the paid apps
// agreement and the secrets below exist.
//
// Clients cannot write `entitlements` (migration 0021); this function
// writes with the service role, and only after the store's own server said
// the purchase is real. Purchases need an account: guests are turned away,
// so nothing bought is lost with a device.
//
// Secrets (supabase secrets set …):
//   APPLE_ISSUER_ID, APPLE_KEY_ID, APPLE_PRIVATE_KEY  App Store Server API key
//   GOOGLE_SERVICE_ACCOUNT                            JSON key with Play access
// SUPABASE_URL, SUPABASE_ANON_KEY and SUPABASE_SERVICE_ROLE_KEY are set by
// Supabase itself.

import { createClient } from 'npm:@supabase/supabase-js@2';
import { decodeJwt, importPKCS8, SignJWT } from 'npm:jose@5';

const bundle = 'de.regetskcob.wargame';

/// Products the function grants, by the key the game and the table use.
const products = new Set(['supporter']);

type Store = 'app_store' | 'play';

Deno.serve(async (req) => {
  if (req.method !== 'POST') {
    return reply({ granted: false, reason: 'method' }, 405);
  }
  const user = await signedInUser(req);
  if (!user) {
    return reply({ granted: false, reason: 'account' }, 401);
  }
  let body: { store?: string; product?: string; proof?: string };
  try {
    body = await req.json();
  } catch {
    return reply({ granted: false, reason: 'body' }, 400);
  }
  const { store, product, proof } = body;
  if (
    (store !== 'app_store' && store !== 'play') ||
    !product || !products.has(product) ||
    !proof || proof.length > 20000
  ) {
    return reply({ granted: false, reason: 'request' }, 400);
  }
  let transaction: string | null;
  try {
    transaction = store === 'app_store'
      ? await checkApple(proof, product)
      : await checkPlay(proof, product);
  } catch (error) {
    console.error('store check failed', error);
    return reply({ granted: false, reason: 'store' }, 502);
  }
  if (!transaction) {
    return reply({ granted: false, reason: 'invalid' }, 400);
  }
  await grant(user, product, store, transaction);
  return reply({ granted: true });
});

function reply(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

/// The account behind the caller's token, or null for a guest or nobody.
async function signedInUser(req: Request): Promise<string | null> {
  const auth = req.headers.get('Authorization');
  if (!auth) {
    return null;
  }
  const client = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_ANON_KEY')!,
    { global: { headers: { Authorization: auth } } },
  );
  const { data } = await client.auth.getUser();
  const user = data.user;
  if (!user || user.is_anonymous) {
    return null;
  }
  return user.id;
}

/// Enters the product for [user]. A restore under another account moves
/// it: the store account paid, so whoever shows its proof owns it.
async function grant(
  user: string,
  product: string,
  store: Store,
  transaction: string,
): Promise<void> {
  const admin = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  );
  await admin.from('entitlements').delete()
    .eq('store', store).eq('transaction_id', transaction)
    .neq('player_id', user);
  const { error } = await admin.from('entitlements').upsert({
    player_id: user,
    product,
    store,
    transaction_id: transaction,
  });
  if (error) {
    throw error;
  }
}

/// Asks the App Store Server API about the transaction in the signed
/// transaction StoreKit 2 gave the app. The JWS is only read to find the
/// transaction id; what counts is Apple's answer. Returns the original
/// transaction id, or null when Apple does not confirm the product.
async function checkApple(jws: string, product: string): Promise<string | null> {
  const claimed = decodeJwt(jws) as { transactionId?: string };
  if (!claimed.transactionId || !/^\d{1,32}$/.test(claimed.transactionId)) {
    return null;
  }
  const token = await appleToken();
  // TestFlight and Xcode builds buy in the sandbox.
  for (const host of [
    'api.storekit.itunes.apple.com',
    'api.storekit-sandbox.itunes.apple.com',
  ]) {
    const response = await fetch(
      `https://${host}/inApps/v1/transactions/${claimed.transactionId}`,
      { headers: { Authorization: `Bearer ${token}` } },
    );
    if (response.status === 404) {
      continue;
    }
    if (!response.ok) {
      throw new Error(`App Store ${response.status}`);
    }
    const { signedTransactionInfo } = await response.json();
    const info = decodeJwt(signedTransactionInfo) as {
      bundleId?: string;
      productId?: string;
      originalTransactionId?: string;
      revocationDate?: number;
    };
    if (
      info.bundleId !== bundle ||
      info.productId !== `${bundle}.${product}` ||
      info.revocationDate ||
      !info.originalTransactionId
    ) {
      return null;
    }
    return info.originalTransactionId;
  }
  return null;
}

async function appleToken(): Promise<string> {
  const key = await importPKCS8(
    Deno.env.get('APPLE_PRIVATE_KEY')!.replaceAll('\\n', '\n'),
    'ES256',
  );
  return await new SignJWT({ bid: bundle })
    .setProtectedHeader({
      alg: 'ES256',
      kid: Deno.env.get('APPLE_KEY_ID')!,
      typ: 'JWT',
    })
    .setIssuer(Deno.env.get('APPLE_ISSUER_ID')!)
    .setAudience('appstoreconnect-v1')
    .setIssuedAt()
    .setExpirationTime('10m')
    .sign(key);
}

/// Asks the Play Developer API about the purchase token. Returns the
/// order id of a completed purchase, or null.
async function checkPlay(token: string, product: string): Promise<string | null> {
  if (!/^[A-Za-z0-9._-]{10,4096}$/.test(token)) {
    return null;
  }
  const access = await googleToken();
  const response = await fetch(
    `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${bundle}/purchases/products/${bundle}.${product}/tokens/${token}`,
    { headers: { Authorization: `Bearer ${access}` } },
  );
  if (response.status === 404 || response.status === 400) {
    return null;
  }
  if (!response.ok) {
    throw new Error(`Play ${response.status}`);
  }
  const purchase = await response.json() as {
    purchaseState?: number;
    orderId?: string;
  };
  // 0 purchased, 1 canceled, 2 pending.
  if (purchase.purchaseState !== 0 || !purchase.orderId) {
    return null;
  }
  return purchase.orderId;
}

async function googleToken(): Promise<string> {
  const account = JSON.parse(Deno.env.get('GOOGLE_SERVICE_ACCOUNT')!) as {
    client_email: string;
    private_key: string;
  };
  const key = await importPKCS8(account.private_key, 'RS256');
  const assertion = await new SignJWT({
    scope: 'https://www.googleapis.com/auth/androidpublisher',
  })
    .setProtectedHeader({ alg: 'RS256', typ: 'JWT' })
    .setIssuer(account.client_email)
    .setAudience('https://oauth2.googleapis.com/token')
    .setIssuedAt()
    .setExpirationTime('10m')
    .sign(key);
  const response = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion,
    }),
  });
  if (!response.ok) {
    throw new Error(`Google token ${response.status}`);
  }
  return (await response.json()).access_token;
}
