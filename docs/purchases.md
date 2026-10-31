# In-app purchases

**Prepared, not live.** Every build has purchases off; nothing is on sale
and no store product exists yet. This page says what is built, how it
works and what going live takes.

## What is sold, and what never is

Two packs, each a one-time purchase, bought apart or together. Neither
contains the other, so no buyer ever pays twice for the same thing. They exist
to pay the running costs (Supabase Pro, domain, hosting), and their texts say
so.

| Pack | Store id | Kind | Price | Idea |
| --- | --- | --- | --- | --- |
| Supporter | `de.regetskcob.wargame.supporter` | non-consumable | 2.99 € | the look: who you are |
| Commander | `de.regetskcob.wargame.commander` | non-consumable | 7.99 € | the battle: set it and keep it |

**Supporter**

- Four exclusive paints (`GameConfig.supporterColors`) in the camouflage
  row. They stay outside `tankColors`: the style on the wire is vehicle times
  paints plus paint, and paints only show in rounds alone, so they are local
  to the device (`TankGame.supporterPaint`) and need no message.
- A mark on the hull (`TankBase.emblem`), the only look that reaches other
  players in every mode, because it leaves the colours of team and seat alone.
- A mark in the room list and ★ on the pilot card. Both marks travel as
  `star` in the presence: the client's own word, faking it fakes a picture.

**Commander**

- *Opening sky:* the host picks weather and day or night in the settings
  (`SkyWish`). The seed already carries both, so the host searches for a
  fitting seed: nothing new travels and **one buys, all play**, older clients
  included. The weather may still turn later, as in any round; a wish outranks
  the gentle first round.
- *Battle archive:* the last 10 rounds of at least 15 seconds as gzipped JSON
  in the app's support folder (`FileReplayStore`), behind ARCHIVE in the
  waiting room. Local like every replay, so no server cost. Not on the web
  and the watch, which have no such folder; the store texts must say so.
- *Service record:* score per vehicle on the opened pilot card, from the view
  `tank_scores` the server keeps anyway. ◆ on the pilot card.

Rules every product follows:

- **Nothing that decides a fight.** Vehicles stay with the rank,
  experience and rating cannot be bought, so the Elo rating and the
  leaderboard stay honest. Since CPU tanks mirror the players' vehicles
  (#24), a stronger tank would not even help against them, only against
  people.
- **No ads, no subscription, no loot boxes.** The store text says "No ads,
  no tracking" and stays true.
- **Purchases need an account.** Guests see the offer and that they have to
  sign in; the server turns guest sessions away. A purchase is never lost
  with a device and counts wherever the account signs in.

### Weighed and not built (yet)

| Idea | Verdict |
| --- | --- |
| Stronger tanks | No: pay-to-win against people, breaks the rating. A *sidegrade* vehicle (other role and look, the strength of an existing rank) would be fair. |
| Phone controller, split screen, base duel | Possible as a "living room pack": one phone stays free so the TV and the web play without a remote, the second phone, split screen and duel are premium. Each phone lane costs Realtime budget, which makes a price defensible. The TV has no store in the plugin, so it is bought on the phone and unlocked through the account. Weakens the TV app as a showcase. |
| Map packs | Possible as "one buys, all play": a host who owns a pack can pick its maps, guests play them for free, so the player base does not split. The content level gate (`roomContent`, docs/netcode.md) already keeps newer maps out of rooms that lack them and could check the host's ownership the same way. |
| Paid map choice | No: every host picks the map for free already. The commander's sky choice takes its place. |
| Paints seen by others | Rounds with others paint hulls by team and seat so players tell each other apart; the supporter's mark is what shows there instead. |

New products need no migration: the table takes any product key, the edge
function holds the list it grants, and the game the `Product` enum.

## How it works

```
Account page ── buy ──▶ App Store / Play ── purchase ──▶ Shop (lib/src/store/shop.dart)
                                                          │ signed transaction (Apple)
                                                          │ purchase token (Google)
                                                          ▼
                                       edge function verify-purchase
                                       (account only, asks Apple/Google)
                                                          │ service role
                                                          ▼
                                         table entitlements (0021)
                                                          │ read own rows
                                                          ▼
                                          Shop.owned → TankGame.owns(product) gates each perk
```

- **`Env.purchases`** (`--dart-define=PURCHASES=true`) switches it on.
  Without it `TankGame.shop` is null, the account page shows nothing and the
  plugin is never called.
- **Where it counts:** everywhere the account signs in. All perks ask
  `TankGame.owns`, which is false while `shop` is null, so a build without
  `PURCHASES` shows none of them, not even as locked.
- **Where one can buy:** iPhone, iPad and Mac (StoreKit 2) and Android (Play
  Billing), through the official `in_app_purchase` plugin. The web, the
  watch and the TV get a closed shop (`Shop.closed`); the plugin has no
  implementation there and is never touched (`open_shop.dart`).
- **`Shop`** (`lib/src/store/shop.dart`) keeps offers, owned products, busy
  state and a message line. A purchase only counts once the server
  confirmed it; until then it stays open in the store, which reports it
  again on the next start or restore. Cancelled says nothing, pending
  waits.
- **`PurchaseService`** (`lib/src/db/purchase_service.dart`) calls the edge
  function and reads `entitlements`; both fail quietly.
- **Edge function `verify-purchase`** (`supabase/functions/verify-purchase`):
  turns away guests, reads the transaction id from StoreKit's signed
  transaction and asks the App Store Server API about it (production, then
  sandbox), or asks the Play Developer API about the token. Only a
  confirmed, unrevoked purchase of the right bundle and product is entered,
  with the original transaction or order id. A restore under another
  account moves the product to that account: the store account paid.
- **Table `entitlements`** (migration 0021, live): one row per pilot and
  product, clients read their own rows and cannot write; deleting the
  account deletes them.

Tests: `test/store/shop_test.dart` (shop with a fake store and server, the
section on the account page), `test/store/packs_test.dart` (products, sky wish,
archive) and `test/game/packs_in_game_test.dart` (perks in a running game). The edge function is type-checked with
`deno check` (`npx deno@2 check supabase/functions/verify-purchase/index.ts`);
it cannot run without the store keys.

## Going live

Owner (consoles, money, law):

1. App Store Connect: accept the **Paid Apps Agreement**, add bank account
   and tax forms.
2. Create both in-app purchases, `de.regetskcob.wargame.supporter` (2.99 €)
   and `de.regetskcob.wargame.commander` (7.99 €), non-consumable, with German
   and English name and description and a review screenshot of the account
   page section.
3. App Store Connect → Users and Access → Integrations → **In-App Purchase
   key**: download the `.p8`, note key id and issuer id.
4. Play Console: the same two products, and a service
   account with "View financial data" for the Play Developer API.
5. Decide who sells: as a private person or as the business (Kalkar IT
   Solutions), and put that name, the legal form and a VAT id if there is
   one into the Impressum (`lib/src/legal/legal_text.dart`, `_owner`). The
   texts on purchases are written and wait behind `purchasesOffered` there:
   the privacy notice (paragraph "Käufe in den Apps"), the licence terms
   ("Käufe") and the Impressum without "nicht kommerziell".
6. App privacy in App Store Connect: "Purchases" linked to the account.

Then Claude:

1. `supabase secrets set APPLE_ISSUER_ID=… APPLE_KEY_ID=… APPLE_PRIVATE_KEY="$(cat key.p8)"`
   (and `GOOGLE_SERVICE_ACCOUNT` for Play), never in the repository.
2. `supabase functions deploy verify-purchase`.
3. A TestFlight build with `PURCHASES=true`, buy with a sandbox tester,
   check the row in `entitlements`, restore on a second device with the same
   account, delete the account and see the row go.
4. Switch `PURCHASES` on in `tool/archive_ios.sh`, `tool/archive_apple.sh`,
   `tool/release_android.sh`, the web build in the `pages` workflow (or web
   owners get no perks) and `purchasesOffered` in
   `lib/src/legal/legal_text.dart` in the same change, so the web pages and
   the apps carry the purchase texts from the first build that sells; add
   "In-app purchases" to the store texts and the changelog.

Open before going live: a refund or revocation does not take a pack back yet.
Now that the packs unlock features, connect App Store Server Notifications and
Play's real-time notifications to a function that deletes the row. And
`store/ios/metadata/review_information/notes.txt` still says "no purchases".
