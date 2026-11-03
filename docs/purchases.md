# In-app purchases

**Prepared, not live.** Every build has purchases off; nothing is on sale and
no store product exists yet. This page is for developers and maintainers: it
says what is built, how a purchase travels from the store to the game, and
what going live takes. It is also a worked example of in-app purchases in
Flutter with the official plugin and a verifying Supabase edge function, no
third-party purchase service.

Contents:

- [What is sold, and what never is](#what-is-sold-and-what-never-is)
- [How it works](#how-it-works)
- [Tests](#tests)
- [Going live](#going-live)

## What is sold, and what never is

Two packs, each a one-time (non-consumable) purchase, bought apart or
together. Neither contains the other, so no buyer pays twice for the same
thing. They exist to pay the running costs (Supabase Pro, domain, hosting),
and their store texts say so.

| Pack | Store id | Price | Idea |
| --- | --- | --- | --- |
| Supporter | `de.regetskcob.wargame.supporter` | 2.99 € | the look: who you are |
| Commander | `de.regetskcob.wargame.commander` | 7.99 € | the battle: set it and keep it |

The packs, their texts and perks are the `Product` enum in
[`product.dart`](../lib/src/store/product.dart).

### Supporter

- **Four exclusive paints** (`GameConfig.supporterColors`) in the camouflage
  row. They stay outside `tankColors`: the style on the wire is vehicle
  times paints plus paint, and paints only show in rounds alone. So they are
  local to the device (`TankGame.supporterPaint`) and need no message.
- **A mark on the hull** (`TankBase.emblem`), the only part of the look that
  reaches other players in every mode, because it leaves the team and seat
  colours alone.
- **A mark in the room list and ★ on the pilot card.** Both travel as `star`
  in the presence. That is the client's own word: faking it only fakes a
  picture.

### Commander

- **Opening sky:** the host picks weather and day or night in the settings
  (`SkyWish` in [`weather.dart`](../lib/src/game/weather.dart)). The seed
  already carries both, so the host searches for a fitting seed. Nothing new
  travels, and **one buys, all play**, older clients included. The weather
  may still turn later, as in any round; a wish outranks the gentle first
  round.
- **Battle archive:** the last 10 rounds of at least 15 seconds as gzipped
  JSON in the app's support folder (`FileReplayStore` in
  [`replay_store.dart`](../lib/src/net/replay_store.dart)), behind ARCHIVE in
  the waiting room. Local like every replay, so no server cost. Not on the
  web and the watch, which have no such folder; the store texts must say so.
- **Service record:** score per vehicle on the opened pilot card, from the
  view `tank_scores` the server keeps anyway. ◆ on the pilot card.

### Rules every product follows

- **Nothing that decides a fight.** Vehicles stay tied to the rank;
  experience and rating cannot be bought, so the Elo rating and the
  leaderboard stay honest. Since CPU tanks mirror the players' vehicles
  (issue #24), a stronger tank would not even help against them, only
  against people.
- **No ads, no subscription, no loot boxes.** The store text says "No ads,
  no tracking" and stays true.
- **Purchases need an account.** Guests see the offer and that they have to
  sign in; the server turns guest sessions away. A purchase is never lost
  with a device and counts wherever the account signs in.

### Weighed and not built (yet)

| Idea | Verdict |
| --- | --- |
| Stronger tanks | No: pay-to-win against people, breaks the rating. A *sidegrade* vehicle (other role and look, the strength of an existing rank) would be fair. |
| Phone controller, split screen, base duel | Possible as a "living room pack": one phone stays free so the TV and the web play without a remote; the second phone, split screen and duel are premium. Each phone lane costs Realtime budget, which makes a price defensible. The TV has no store in the plugin, so it is bought on the phone and unlocked through the account. Weakens the TV app as a showcase. |
| Map packs | Possible as "one buys, all play": a host who owns a pack picks its maps, guests play them for free, so the player base does not split. The content level gate (`roomContent`, see [netcode.md](netcode.md#content-level)) already keeps newer maps out of rooms that lack them and could check the host's ownership the same way. |
| Paid map choice | No: every host picks the map for free already. The commander's sky choice takes its place. |
| Paints seen by others | Rounds with others paint hulls by team and seat so players tell each other apart; the supporter's mark shows there instead. |

New products need no migration: the table takes any product key, the edge
function holds the list it grants, and the game the `Product` enum.

## How it works

```text
account page --buy--> App Store / Google Play --purchase--> Shop
                                                              |
             signed transaction (Apple) or purchase token (Google)
                                                              v
                          edge function verify-purchase (accounts only,
                          asks Apple or Google, writes with service role)
                                                              |
                                                              v
                          table entitlements (migration 0021)
                                                              |
                                          client reads own rows
                                                              v
                          Shop.owned -> TankGame.owns(product) gates each perk
```

- **The switch:** `Env.purchases` (`--dart-define=PURCHASES=true`,
  [`env.dart`](../lib/src/app/env.dart)). Without it `TankGame.shop` is null,
  the account page shows nothing and the plugin is never called. Every perk
  asks `TankGame.owns`, which is false while `shop` is null, so a build
  without `PURCHASES` shows none of them, not even as locked.
- **Where one can buy:** iPhone, iPad and Mac (StoreKit 2) and Android (Play
  Billing), through the official `in_app_purchase` plugin. The web, the
  watch and the TV get a closed shop (`Shop.closed`) that still knows what
  the account owns; the plugin has no implementation there and is never
  touched ([`open_shop.dart`](../lib/src/store/open_shop.dart)).
- **`Shop`** ([`shop.dart`](../lib/src/store/shop.dart)) keeps offers, owned
  products, busy state and a message line. It talks to the store through
  the `StoreGateway` interface (`PluginStoreGateway` in
  [`store_gateway.dart`](../lib/src/store/store_gateway.dart)), so tests run
  without a store. A purchase only counts once the server confirmed it;
  until then it stays open in the store, which reports it again on the next
  start or restore. A cancel says nothing; a pending purchase waits.
- **`PurchaseService`**
  ([`purchase_service.dart`](../lib/src/db/purchase_service.dart)) calls the
  edge function and reads `entitlements`. Both fail quietly, so a project
  without the table or the function simply owns nothing.
- **Edge function `verify-purchase`**
  ([`index.ts`](../supabase/functions/verify-purchase/index.ts)) turns away
  guests. For Apple it reads the transaction id from StoreKit's signed
  transaction and asks the App Store Server API about it (production, then
  sandbox); for Google it asks the Play Developer API about the token. Only
  a confirmed, unrevoked purchase of the right bundle and product is
  entered, with the original transaction or order id. A restore under
  another account moves the product to that account, because the store
  account paid.
- **Table `entitlements`**
  ([`0021_entitlements.sql`](../supabase/migrations/0021_entitlements.sql)):
  one row per pilot and product. Row level security lets clients read their
  own rows and nothing else; only the edge function writes. Deleting the
  account deletes the rows.

A fork that wants to sell under its own name changes the bundle id in
`Product.storeId` and in the edge function (`bundle`), creates its own
products in the store consoles and deploys the function to its own Supabase
project.

## Tests

- [`test/store/shop_test.dart`](../test/store/shop_test.dart): the shop
  with a fake store and server, and the section on the account page.
- [`test/store/packs_test.dart`](../test/store/packs_test.dart): products,
  sky wish and archive.
- [`test/game/packs_in_game_test.dart`](../test/game/packs_in_game_test.dart):
  the perks in a running game.

The edge function cannot run without the store keys, but it is
type-checked:

```sh
npx deno@2 check supabase/functions/verify-purchase/index.ts
```

## Going live

These are maintainer steps for the hosted game.

### Store consoles, money and law

1. App Store Connect: accept the **Paid Apps Agreement**, add bank account
   and tax forms.
2. Create both in-app purchases, `de.regetskcob.wargame.supporter` (2.99 €)
   and `de.regetskcob.wargame.commander` (7.99 €), non-consumable, with
   German and English name and description and a review screenshot of the
   account page section.
3. App Store Connect → Users and Access → Integrations → **In-App Purchase
   key**: download the `.p8`, note key id and issuer id.
4. Play Console: the same two products, and a service account with "View
   financial data" for the Play Developer API.
5. Decide who sells (a private person or a business) and put that name, the
   legal form and a VAT id if there is one into the Impressum
   ([`legal_text.dart`](../lib/src/legal/legal_text.dart), `_owner`). The
   purchase texts are written and wait behind `purchasesOffered` there: the
   privacy notice (paragraph "Käufe in den Apps"), the licence terms
   ("Käufe") and the Impressum without "nicht kommerziell".
6. App privacy in App Store Connect: "Purchases" linked to the account.

### Server and builds

1. Set the store keys as function secrets, never in the repository:

   ```sh
   supabase secrets set APPLE_ISSUER_ID=… APPLE_KEY_ID=… APPLE_PRIVATE_KEY="$(cat key.p8)"
   supabase secrets set GOOGLE_SERVICE_ACCOUNT="$(cat service-account.json)"
   ```

2. Deploy the function: `supabase functions deploy verify-purchase`.
3. Make a TestFlight build with `PURCHASES=true`, buy with a sandbox tester,
   check the row in `entitlements`, restore on a second device with the same
   account, delete the account and see the row go.
4. In one change, switch `PURCHASES` on in `tool/archive_ios.sh`,
   `tool/archive_apple.sh`, `tool/release_android.sh` and the web build in
   the `pages` workflow (or web owners get no perks), and set
   `purchasesOffered` in `legal_text.dart`. That way the web pages and the
   apps carry the purchase texts from the first build that sells. Add
   "In-app purchases" to the store texts and the changelog.

### Open before going live

- A refund or revocation does not take a pack back yet. Connect App Store
  Server Notifications and Play's real-time developer notifications to a
  function that deletes the row.
- The App Review notes
  (`store/ios/metadata/review_information/notes.txt`) still say the game has
  no purchases.
