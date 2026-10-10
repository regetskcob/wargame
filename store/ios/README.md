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
schreibt die `iphone63-*`-Bilder mit. Für alle kleineren Geräte skaliert
Apple selbst. Ist der Name „Panzergefecht“ im App Store
schon vergeben, meldet App Store Connect das beim Anlegen, dann etwa
„Panzergefecht – Panzerduell“ nehmen. Die
Schlüsselwörter enthalten bewusst keine geschützten Namen von Streitkräften, das
verbietet Apple (Richtlinie 2.3.7). Die Fahrzeuge tragen Tiernamen (Hermelin,
Fuchs, Spitzmaus, Habicht, Keiler, Hirsch, Dachs, Wolf) statt Modell- oder
Herstellernamen.

## Icon neu erzeugen

`store/tool/app_icon.py` zeichnet das Icon (Panzer auf dem Gelände der
Karte) und schreibt es nach `icon/`, in die Icon-Sets für iOS und macOS und
nach `web/`.
Danach `store/tool/android_icons.py` für Android und Google Play:

```sh
python3 store/tool/app_icon.py
python3 store/tool/android_icons.py
```

## Screenshots neu erzeugen

Zwei Befehle, ohne Hand am Simulator:

```sh
tool/store_shots.sh /tmp/raw              # alle Rohbilder, ca. 15 Minuten
python3 store/tool/compose.py /tmp/raw    # alle Store-Bilder daraus
python3 store/tool/landing.py /tmp/raw    # Geräte-Bild der Landingpage
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
Die Simulatoren („Store iPhone 6.9“, „Store iPad 13“, „Store Apple TV“)
legt das Skript bei Bedarf selbst an; flutter-tvos erwartet es unter
`~/development/flutter-tvos`. Die Watch-App nimmt sich nicht selbst auf, ihr
Bild für die Kopfzeile kommt aus `watch/`.

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

## TestFlight per GitHub

Der Workflow **testflight** (Actions > testflight > Run workflow) baut die
signierte App, lädt sie zu TestFlight hoch und auf Wunsch die Texte und
Screenshots zu App Store Connect. Die Build-Nummer zählt mit jedem Lauf hoch.
Lokal geht dasselbe aus `ios/` mit `bundle exec fastlane beta`
oder `bundle exec fastlane metadata`.

### Einmalig einrichten

1. **App anlegen:** App Store Connect > Apps > Neue App, Plattform iOS,
   Name „Panzergefecht“, Sprache Deutsch, Bundle-ID `de.regetskcob.wargame`,
   SKU zum Beispiel `panzergefecht`.
2. **API-Schlüssel:** App Store Connect > Benutzer und Zugriff >
   Integrationen > App Store Connect API > Schlüssel erzeugen, Rolle
   **Admin** (nur damit darf Xcode Zertifikat und Profil selbst holen). Die
   `.p8`-Datei lässt sich nur einmal laden.
3. **Secrets im Repository** (Settings > Secrets and variables > Actions):

   | Secret | Inhalt |
   | --- | --- |
   | `ASC_KEY_ID` | Schlüssel-ID, steht neben dem Schlüssel |
   | `ASC_ISSUER_ID` | Issuer-ID, steht über der Schlüsselliste |
   | `ASC_KEY_P8_BASE64` | `base64 -i AuthKey_XXXX.p8 \| pbcopy` |

   Die Variablen `SUPABASE_URL`, `SUPABASE_KEY` und `ACCOUNTS` teilt sich der
   Workflow mit dem Web-Deploy.
4. **Nur falls das Signieren in der CI scheitert** (Fehler zu Zertifikat oder
   Profil): das Apple-Distribution-Zertifikat aus der Schlüsselbundverwaltung
   als `.p12` exportieren und als `IOS_DIST_P12_BASE64` samt Passwort in
   `IOS_DIST_P12_PASSWORD` hinterlegen. Fastlane importiert es dann vorher.

Danach erscheint jeder Lauf nach der Verarbeitung durch Apple (meist 10 bis
30 Minuten) unter TestFlight. Für externe Tester prüft Apple den ersten Build
einmal, die Texte dafür stehen in `metadata/de-DE/testflight.txt`.

## Vor der Einreichung offen

1. **Einrichten wie oben**, dann den Workflow mit „Upload the store texts
   and screenshots“ laufen lassen.
2. **In App Store Connect von Hand:** App Privacy (siehe oben),
   Altersfreigabe, Preis (kostenlos), danach zur Prüfung einreichen.
3. **Den TestFlight-Build auf einem echten iPhone spielen:** Der Simulator
   kann nur Debug-Builds. Auf Android stürzte der Release-Build an einer
   Stelle ab, an der Debug lief (siehe `TankGame._renderWeather`). Das ist
   behoben, auf iOS aber noch nicht im Release ausprobiert.

## Universal Links

Room links (`https://www.regetskcob.de/wargame/play/?room=CODE`) open the app when
it is installed, also from the iPhone camera. The app asks for
`applinks:www.regetskcob.de` (`ios/Runner/Runner.entitlements`, team
86HB5U6788). Apple only reads the association file at the root of the
domain, so `apple-app-site-association` from this folder belongs into the
website repository `regetskcob.github.io` at
`static/.well-known/apple-app-site-association`. Check after the deploy:

```sh
curl -s https://www.regetskcob.de/.well-known/apple-app-site-association
curl -s https://app-site-association.cdn-apple.com/a/v1/www.regetskcob.de
```

Apple's CDN can take a day to pick up a change. iOS fetches the file when the
app is installed or updated.
