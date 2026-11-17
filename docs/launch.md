# Launch day

The steps that turn the tested apps into the public, selling release, in
order. Everything that can be prepared in the repository is prepared; what
is left waits for the VAT identification number or happens in the store
consoles. The details of purchases are in [purchases.md](purchases.md), the
release flow in [development.md](development.md).

## When the VAT id arrives

1. Put it into `vatId` in
   [`legal_text.dart`](../lib/src/legal/legal_text.dart). The Impressum
   shows the line in German and English as soon as it is not empty: in the
   apps and on `/impressum/` of the web build.
2. App Store Connect: Agreements, Tax and Banking: accept the **Paid Apps
   Agreement** and fill in the bank account and tax forms (W-8BEN with the
   German tax number). Play Console: payments profile with the same data.
3. Go on with "Store consoles, money and law" and "Server and builds" in
   [purchases.md](purchases.md#going-live). Step 5 there (the Impressum) is
   down to the VAT id from step 1.

## One change that switches the sale on

Together, in one commit, so no build or page sells without the texts:

- `PURCHASES=true` in the release scripts and the `pages` workflow, and
  `purchasesOffered = true` in `legal_text.dart`
  ([purchases.md](purchases.md#server-and-builds), step 4).
- **Store descriptions** (`store/ios/metadata/*/description.txt`,
  `store/android/metadata/*/full_description.txt`): replace the paragraph
  "privates, nicht kommerzielles Spiel" with

  > Panzergefecht ist kostenlos spielbar, ohne Werbung und ohne Tracking.
  > Zwei freiwillige Pakete tragen Server, Domain und Hosting und bringen
  > keinen Vorteil im Gefecht: das Unterstützer-Paket mit eigenen Tarnungen
  > und Feldzeichen, das Kommandeur-Paket mit Startwetter für den Raum,
  > Einsatzarchiv und Einsatzakte. Käufe brauchen ein Konto. Panzergefecht
  > steht in keiner Verbindung zu Streitkräften oder Fahrzeugherstellern.

  > Panzergefecht is free to play, with no ads and no tracking. Two optional
  > packs pay for the server, domain and hosting and bring no advantage in
  > battle: the supporter pack with its own paints and marks, the commander
  > pack with the opening weather for the room, a battle archive and a
  > service record. Purchases need an account. Panzergefecht has no
  > connection to any armed forces or vehicle manufacturer.

  The battle archive does not exist on the web and the watch; the store
  texts of the apps may leave that out, the web page must not promise it.
- **App Review notes**
  (`store/ios/metadata/review_information/notes.txt`): replace "ohne
  Werbung, ohne Käufe und ohne Tracking" by "ohne Werbung und ohne
  Tracking; zwei freiwillige Pakete als Einmalkauf unter KONTO, nur mit
  Anmeldung, Prüfkonto siehe oben", and the English line likewise. Drop
  "privat und nicht kommerziell".
- **Landing page** (`site/i18n/*.yaml`): `fair-price-text` names the
  packs ("Kostenlos. Freiwillige Pakete in den Apps, ohne Vorteil im
  Gefecht.").
- `CHANGELOG.md` and `CHANGELOG.de.md`: "In-app purchases: …".
- A review screenshot of the pack section on the account page for each
  in-app purchase in App Store Connect (screenshot build with
  `PURCHASES=true`).

## Store release instead of beta

When Apple and Google have approved the builds and the apps go public:

- `site/hugo.toml`: set `[params.stores]` `appStore` and `googlePlay` (the
  layout shows them as soon as they are set) and remove `[params.beta]`,
  which hides the TestFlight and closed test links.
- `site/i18n/*.yaml`: `platformsNote`, `hero-kennung`, `device-*-text` and
  the "bald"/"soon" labels to what really is in the stores; the
  `secondary` button of the hero points to the stores instead of `#beta`.
- Only name Apple TV, Mac, Watch and Wear OS in the store texts once each
  was played on real hardware (decided 2026-10).

## Before the rush

- Run `/release-test` on the build that goes out.
- Watch the Realtime load in the Supabase dashboard on launch day.
  `REALTIME_BUDGET` keeps rooms out before Realtime closes every channel;
  what players see when everything is taken is in
  [netcode.md](netcode.md#realtime-limits).
