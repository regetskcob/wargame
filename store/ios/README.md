# App Store und TestFlight

Alles, was App Store Connect für Panzergefecht braucht. Die Ordner folgen dem
Aufbau von `fastlane deliver`, die Dateien lassen sich aber genauso von Hand
in App Store Connect einfügen.

| Feld in App Store Connect | Datei |
| --- | --- |
| Name (max. 30) | `metadata/de-DE/name.txt` |
| Untertitel (max. 30) | `metadata/de-DE/subtitle.txt` |
| Werbetext (max. 170) | `metadata/de-DE/promotional_text.txt` |
| Beschreibung (max. 4000) | `metadata/de-DE/description.txt` |
| Schlüsselwörter (max. 100) | `metadata/de-DE/keywords.txt` |
| Neuerungen | `metadata/de-DE/release_notes.txt` |
| Support- und Marketing-URL | `metadata/de-DE/support_url.txt`, `marketing_url.txt` |
| Datenschutz-URL | `metadata/de-DE/privacy_url.txt` |
| Copyright, Kategorien | `metadata/copyright.txt`, `metadata/primary_*.txt` |
| Hinweise für die Prüfung | `metadata/review_information/notes.txt` |
| Lizenzvereinbarung (EULA), nur falls statt Apples Standard-EULA gewünscht, von Hand | `license.txt` |
| TestFlight: Beschreibung, Testhinweise | `metadata/de-DE/testflight.txt` |
| App-Icon 1024 × 1024, ohne Alpha | `icon/AppIcon-1024.png` |
| iPhone 6,9" (1320 × 2868) | `screenshots/<sprache>/iphone-*.png` |
| iPhone 6,3" (1206 × 2622), Pflichtfeld „iPhone mit Dynamic Island“ | `screenshots/<sprache>/iphone63-*.png` |
| iPad 13" (2752 × 2064) | `screenshots/<sprache>/ipad-*.png` |
| Apple Watch Ultra 4 (422 × 514), von Hand hochladen | `watch/<sprache>/watch-*.png` |
| Mac (2880 × 1800), von Hand hochladen | `mac/<sprache>/mac-*.png` |
| Apple TV (3840 × 2160), von Hand hochladen | `tv/<sprache>/tv-*.png` |
| Kopfzeile, Tab „Kopfzeile“ (5244 × 2950 und 3840 × 1646), von Hand hochladen | `header/<sprache>/header-*.png`: iPhone vor dem iPad, Mac, Apple TV, Watch |
| Kopfzeile, Tab „Suchergebnisse“ (dieselben Größen), von Hand hochladen | `header/<sprache>/search-*.png`: iPhone, iPad und Watch nebeneinander |

`<sprache>` ist `de-DE` oder `en-US`. Watch-, Mac- und TV-Bilder und die
Kopfzeile liegen außerhalb von `screenshots/`, weil `fastlane deliver` diesen Ordner hochlädt
und nur Größen kennt, die es schon unterstützt.

App Store Connect verlangt inzwischen die 6,3"-Größe als Pflichtfeld; `compose.py`
python3 store/tool/landing.py /tmp/raw    # Geräte-Bild der Landingpage
schreibt die `iphone63-*`-Bilder mit. Für alle kleineren Geräte skaliert
Apple selbst. Ist der Name „Panzergefecht“ im App Store
schon vergeben, meldet App Store Connect das beim Anlegen, dann etwa
„Panzergefecht – Panzerduell“ nehmen. Die
Schlüsselwörter enthalten bewusst keine geschützten Namen von Streitkräften, das
verbietet Apple (Richtlinie 2.3.7). Die Fahrzeuge tragen Tiernamen (Hermelin,
Fuchs, Spitzmaus, Habicht, Keiler, Hirsch, Dachs, Wolf) statt Modell- oder
Herstellernamen.

## Icon übernehmen

Das Icon (Panzer in Seitenansicht auf dem Horizont) zeichnet das
Design-System Horizont, die App zeichnet und skaliert es nicht selbst.
`store/tool/horizont_icons.py` kopiert die fertigen Sätze aus
`icons/export/panzergefecht/` eines Horizont-Checkouts nach `icon/`, in die
Icon-Sets für iOS, Watch, macOS und Apple TV, nach Android, `web/` und in
die Play-Metadaten:

```sh
python3 store/tool/horizont_icons.py ../horizont
```

## Screenshots neu erzeugen

Zwei Befehle, ohne Hand am Simulator:

```sh
tool/store_shots.sh /tmp/raw              # alle Rohbilder, ca. 15 Minuten
python3 store/tool/compose.py /tmp/raw    # alle Store-Bilder daraus
```

`tool/store_shots.sh` baut je Plattform einen Debug-Build mit
`--dart-define=SHOTS=true` und startet ihn pro Szene und Sprache einmal,
die Szene als Startargument (`-SHOT_SCENE battle -SHOT_LANG en -SHOT_OUT
<datei>`). Die App geht selbst in die Szene (Startseite, Warteraum,
Gefecht, Verteidigung), wartet, bis sie sich eingespielt hat, und schreibt
ihr eigenes Bild, ohne Statusleiste und Simulator-Rahmen
(`lib/src/game/tank_game/shots.dart`). Das sind 24 Aufnahmen: iPhone 17 Pro
Max hochkant (4 Szenen), iPad Pro 13" quer (3), Apple TV 4K (2), Mac im
Fenster mit 1440 × 900 Punkten (3), je Deutsch und Englisch. Nur einzelne
Geräte: `tool/store_shots.sh /tmp/raw ios ipad tv mac` mit einer Auswahl.
Für Einzelbilder nimmt ein Screenshot-Build außerdem `-SHOT_MAP <n>`
(Gelände, Index in `MapTheme.all`, 4 = Bergwald, 5 = Inseln),
`-SHOT_TANK <n>` (Fahrzeug, Index in `TankType`, 8 = Igel, auch gesperrt)
und `-SHOT_LAYOUT <n>` (Verteidigungskarte, 4 = Flussufer, 5 = Haarnadel).
Die Simulatoren („Store iPhone 6.9“, „Store iPad 13“, „Store Apple TV“)
legt das Skript bei Bedarf selbst an; flutter-tvos erwartet es unter
`~/flutter/flutter-tvos`. Die Watch-App nimmt sich nicht selbst auf, ihr
Bild für die Kopfzeile kommt aus `watch/`.

Die Watch-Bilder (`watch/<sprache>/watch-0*.png`, 422 × 514) entstehen im
Simulator „Apple Watch Ultra 4 (49mm)“ aus einem Build mit
`flutter-watchos build watchos --simulator --dart-define=SHOTS=true`, mit
denselben Szenen wie oben (`menu`, `lobby`, `battle`, `defense`).
Startargumente nimmt die Watch nicht (die Engine bricht daran ab), und ihr
Einstellungsspeicher ist ein JSON unter
`flutterwatch.shared_preferences.store`: Szene und Sprache kommen dort
hinein, und zwar mit `xcrun simctl spawn <uhr> defaults write
<container>/Library/Preferences/de.regetskcob.wargame.watchkitapp …`, weil
cfprefsd eine direkt bearbeitete Plist überschreibt. Die Uhr muss dabei
wach sein (zuerst über das Simulator-Panel starten), sonst startet die App
im Hintergrund, zeichnet nichts und das Bild zeigt die Startseite; dann
`xcrun simctl launch`, die Szene abwarten und
`xcrun simctl io <uhr> screenshot` (mit der Uhrzeit oben). Danach
`compose.py` und `landing.py` erneut laufen lassen, sie setzen die Watch in
Kopfzeilen und Landingpage.

Mit `SHOTS=true` nimmt der eigene Panzer keinen Schaden, es bleibt Tag ohne
Nebel, die Schwierigkeit steht auf leicht (Munition ohne Ende), alle fahren
den olivgrünen Hermelin, und eine Verteidigungsrunde beginnt bei Welle
`SHOT_WAVE` (Standard 3) mit ausgebautem Stützpunkt, 2000 Kasse und offener
Geschützliste. Im Gefecht stehen beide Touch-Sticks gedrückt.
`tool/check_dart_defines.sh` lässt den Modus in keinen Release-Build.

`compose.py` setzt jede Aufnahme in ein gezeichnetes Gerät (iPhone, iPad,
MacBook, Fernseher) unter Überschrift und Unterzeile, alle auf demselben
olivfarbenen Tarnhintergrund, und schreibt beide Sprachsätze für App Store,
Mac App Store, Apple TV und Google Play, dazu die Kopfzeilen (die auch die
Landingpage zeigt) und die Play-Grafik. Braucht Pillow
(`pip3 install --user pillow`).

## Angaben in App Store Connect

**Datenschutz (App Privacy):** Kein Tracking. Erhoben und mit der Person
verknüpft, nur für die App-Funktion:

- Kontaktinformationen → E-Mail-Adresse (nur wer sein Konto sichert)
- Kennungen → Benutzer-ID (anonyme Kennung des Gastkontos)
- Nutzerinhalte → Gameplay-Inhalte (Rufname, Fahrzeug, Spielstände)
- Nutzungsdaten → Produktinteraktion (Statistiken, Runden, Wertung)

**Altersfreigabe:** Comic- oder Fantasy-Gewalt „häufig/intensiv“ (Panzer
werden zerstört, Infanterie wird überrollt), sonst überall „keine“. Ergibt
voraussichtlich 12+.

**Exportkontrolle:** In der `Info.plist` steht bereits
`ITSAppUsesNonExemptEncryption = false`, die Frage entfällt.

**Kategorie:** Spiele, Unterkategorien Action und Strategie.

## TestFlight vom Mac

Gebaut und hochgeladen wird nur lokal, nie in der CI (eine macOS-Minute zählt
im privaten Repo zehn Linux-Minuten, siehe `docs/development.md` „CI
minutes“). Alle drei Plattformen teilen sich Bundle-ID, Team
(`apple/Signing.xcconfig`) und den App-Store-Eintrag; die Build-Nummer ist
die aus `pubspec.yaml`.

| Was | Befehl |
| --- | --- |
| iOS samt Watch-App | `tool/archive_ios.sh --upload` |
| Apple TV / Mac | `tool/archive_apple.sh tvos --upload` bzw. `macos --upload` |
| Texte und Screenshots | in `ios/`: `bundle exec fastlane ios metadata` |

Ohne `--upload` landet das geprüfte Archiv nur im Organizer. Signiert wird
mit dem in Xcode angemeldeten Apple-Account.

### Einmalig einrichten

1. **App anlegen:** App Store Connect > Apps > Neue App, Plattform iOS,
   Name „Panzergefecht“, Sprache Deutsch, Bundle-ID `de.regetskcob.wargame`,
   SKU zum Beispiel `panzergefecht`.
2. **API-Schlüssel:** App Store Connect > Benutzer und Zugriff >
   Integrationen > App Store Connect API > Schlüssel erzeugen, Rolle
   **Admin** (nur damit darf Xcode Zertifikat und Profil selbst holen). Die
   `.p8`-Datei lässt sich nur einmal laden.
3. **Schlüssel lokal** (nur für `fastlane ios metadata`, nie ins Repo):
   die `.p8` etwa nach `~/.appstoreconnect/private_keys/`, dann
   `ASC_KEY_ID` (Schlüssel-ID), `ASC_ISSUER_ID` (Issuer-ID über der
   Schlüsselliste) und `ASC_KEY_PATH` (Pfad zur `.p8`) setzen.
4. **Distributionszertifikat** im Schlüsselbund des Macs: für **tvOS immer
   nötig**, flutter-tvos signiert damit die Engine, ohne Signatur lehnt
   Apple den Build ab (ITMS-91065). Xcode legt es unter Settings > Accounts
   > Manage Certificates an.
5. **tvOS und Mac in App Store Connect:** Im bestehenden App-Eintrag
   Panzergefecht unter „Plattform hinzufügen“ tvOS und macOS ergänzen, sonst
   lehnt TestFlight die Uploads ab.

Danach erscheint jeder Upload nach der Verarbeitung durch Apple (meist 10 bis
30 Minuten) unter TestFlight. Für externe Tester prüft Apple den ersten Build
einmal, die Texte dafür stehen in `metadata/de-DE/testflight.txt`.

## Vor der Einreichung offen

1. **Einrichten wie oben**, dann in `ios/` `bundle exec fastlane ios metadata`.
2. **In App Store Connect von Hand:** App Privacy (siehe oben),
   Altersfreigabe, Preis (kostenlos), danach zur Prüfung einreichen.
3. **Den TestFlight-Build auf einem echten iPhone spielen:** Der Simulator
   kann nur Debug-Builds. Auf Android stürzte der Release-Build an einer
   Stelle ab, an der Debug lief (siehe `TankGame._renderWeather`). Das ist
   behoben, auf iOS aber noch nicht im Release ausprobiert.

## Universal Links

Room links (`https://panzergefecht.de/play/?room=CODE`) open the app when
it is installed, also from the iPhone camera. The app asks for
`applinks:panzergefecht.de` (`ios/Runner/Runner.entitlements`, team
86HB5U6788). Apple only reads the association file at the root of the
domain; the site is that root, and `site/hugo.toml` mounts
`apple-app-site-association` from this folder into `.well-known/`, so every
deploy of the pages workflow carries it. Check after the deploy:

```sh
curl -s https://panzergefecht.de/.well-known/apple-app-site-association
curl -s https://app-site-association.cdn-apple.com/a/v1/panzergefecht.de
```

Links shared before the move to panzergefecht.de point to
`https://www.regetskcob.de/wargame/…`. The app still asks for
`applinks:www.regetskcob.de` so they keep opening it; their association
file (paths `/wargame/*`) stays in the website repository
`regetskcob.github.io` at `static/.well-known/apple-app-site-association`.

Apple's CDN can take a day to pick up a change. iOS fetches the file when the
app is installed or updated.
