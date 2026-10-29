# Google Play

Alles, was die Play Console für Panzergefecht braucht. Die Ordner folgen dem
Aufbau von `fastlane supply`: `tool/release.sh android` lädt Bundle, Texte
und Bilder vom Mac hoch (siehe [Deployment](#deployment)). Von Hand lassen sie sich genauso
in der Play Console einfügen (Store-Präsenz > Haupteintrag im Play Store).

| Feld in der Play Console | Datei |
| --- | --- |
| App-Name (max. 30) | `metadata/de-DE/title.txt` |
| Kurzbeschreibung (max. 80) | `metadata/de-DE/short_description.txt` |
| Vollständige Beschreibung (max. 4000) | `metadata/de-DE/full_description.txt` |
| Versionshinweise (max. 500) | `metadata/de-DE/changelogs/default.txt`, für eine bestimmte Version `<versionCode>.txt` |
| App-Symbol 512 × 512 | `metadata/de-DE/images/icon.png` |
| Vorstellungsgrafik 1024 × 500 | `metadata/de-DE/images/featureGraphic.png` |
| Smartphone-Screenshots (1080 × 1920) | `metadata/de-DE/images/phoneScreenshots/*.png` |
| Tablet-Screenshots 7" (1920 × 1200) | `metadata/de-DE/images/sevenInchScreenshots/*.png` |
| Tablet-Screenshots 10" (2560 × 1600) | `metadata/de-DE/images/tenInchScreenshots/*.png` |
| Wear-OS-Screenshots (quadratisch, mindestens 384 × 384) | `metadata/de-DE/images/wearScreenshots/*.png` |

Play erlaubt keine Seite, die mehr als doppelt so lang ist wie die andere, die
6,9"-Bilder aus dem App Store passen deshalb nicht. `tool/store/compose.py`
baut aus denselben Rohaufnahmen beide Sätze und die Vorstellungsgrafik,
`tool/store/horizont_icons.py` kopiert die Launcher-Icons (klassisch und adaptiv
mit monochromer Ebene) und das Play-Symbol aus dem Design-System Horizont:

```sh
pip3 install --user pillow
tool/release.sh graphics <ordner-mit-rohaufnahmen>
python3 tool/store/horizont_icons.py ../horizont
```

Englische Screenshots und Vorstellungsgrafik liegen genauso unter
`metadata/en-US/images/`. Die Screenshots zeigen die
iOS-Rohaufnahmen ohne Statusleiste, das Spiel
zeichnet auf Android dasselbe Bild.

## Build und Signieren

App-ID `de.regetskcob.wargame` wie auf iOS, Name Panzergefecht. Die App-ID lässt sich
nach dem ersten Upload nie mehr ändern.

1. Upload-Schlüssel einmalig anlegen und `android/key.properties` nach
   `android/key.properties.example` ausfüllen (beides ignoriert git).
2. `flutter build appbundle --release --dart-define=SUPABASE_URL=...
   --dart-define=SUPABASE_KEY=...`,
   Ergebnis: `build/app/outputs/bundle/release/app-release.aab`.
3. In der Play Console **Play App Signing** aktiv lassen: Google hält den
   App-Signaturschlüssel, wir nur den Upload-Schlüssel.
4. Der versionCode muss mit jedem Upload steigen. Er ist die Build-Nummer
   hinter dem `+` in `version:` in `pubspec.yaml`, der Teil davor der
   versionName.

Ohne `key.properties` signiert Gradle mit dem Debug-Schlüssel. So baut ein
Hand-Lauf von `ci`, Play nimmt ein solches Bundle aber nicht an.

## Deployment

Gebaut und hochgeladen wird nur lokal, nie in der CI (siehe
`docs/development.md` „CI minutes“): `tool/release.sh android` baut das
signierte Bundle mit `--dart-define=ACCOUNTS=true` (URL und Schlüssel von
Supabase sind die Vorgaben in `Env`), prüft Signatur und Supabase-URL, legt
eine Kopie in `build/release/` ab und lädt es mit `--upload` per
`fastlane supply` aus `android/fastlane` hoch:

```sh
tool/release.sh android phone                          # nur bauen und prüfen
tool/release.sh android phone --upload internal         # Entwurf im internen Test
tool/release.sh android phone --upload internal --metadata --completed
tool/release.sh android wear --upload internal          # Wear OS, eigener Track
```

| Option | Bedeutung |
| --- | --- |
| `phone` / `wear` | Handy und Tablet oder Wear-OS-Uhren, siehe [Wear OS](#wear-os) |
| `--upload <track>` | `internal` (interner Test), `alpha` (geschlossen), `beta` (offen), `production` |
| `--completed` | sofort freigeben statt als Entwurf, erst wenn Store-Eintrag und Fragebögen vollständig sind |
| `--metadata` | Texte, Icon, Vorstellungsgrafik und Screenshots mit hochladen |

### Einmalig einrichten

1. **App anlegen:** Play Console > App erstellen, Name
   „Panzergefecht“, Sprache Deutsch, Spiel, kostenlos.
2. **Erster Upload von Hand:** Die API kann erst mit einer App arbeiten, die
   schon ein Bundle hat. Lokal mit `key.properties` bauen und
   `app-release.aab` unter Testen > Interner Test hochladen. Dabei Play App
   Signing mit dem Upload-Schlüssel bestätigen.
3. **Dienstkonto:** In der Google Cloud Console (Projekt der Play Console)
   die *Google Play Android Developer API* aktivieren, ein Dienstkonto anlegen
   und einen JSON-Schlüssel erzeugen. In der Play Console unter Nutzer und
   Berechtigungen das Dienstkonto einladen, für Panzergefecht mit „Releases
   verwalten“ und „Store-Präsenz verwalten“.
4. **Prüfen:** Lokal die JSON-Datei als `android/play-service-account.json`
   ablegen (git ignoriert sie), dann in `android/`:

   ```sh
   bundle install
   bundle exec fastlane validate
   ```

### Lokal hochladen

Bundles baut `tool/release.sh android` (oben). Die übrigen Lanes laufen in
`android/` von Hand:

```sh
bundle exec fastlane metadata                      # nur Texte und Bilder
bundle exec fastlane promote from:internal to:alpha
```

Ohne `--completed` landet das Release als Entwurf und muss in
der Play Console freigegeben werden. Solange die App noch nie freigegeben
wurde, nimmt die API ohnehin nur Entwürfe an.

## Wear OS

Dieselbe App mit demselben Paketnamen läuft auf Wear-OS-Uhren (Galaxy Watch 4
und neuer, Pixel Watch), siehe `docs/platforms.md` „Wear OS“. Play führt sie
als eigenen Formfaktor mit eigenen Tracks (`wear:internal`,
`wear:production` …) und eigenem Bundle:

- `flutter build appbundle --release --android-project-arg=wear=true` hängt
  das Manifest aus `android/wear/` an (`android.hardware.type.watch`,
  standalone, Vibration), setzt minSdk 30 (Wear OS 3) und schlägt 100000 auf den
  versionCode, damit er sich nie mit dem Handy-Bundle überschneidet.
- `tool/release.sh android wear --upload internal`, genauso in `android/`
  `promote form_factor:wear from:internal to:production`.

Einmalig in der Play Console: Test und Release > Einstellungen > Formfaktoren
> Wear OS hinzufügen und den Wear-OS-Richtlinien zustimmen. Erst dann gibt es
die `wear:`-Tracks. Wear OS braucht eigene Screenshots (quadratisch, nur die
App ohne Rahmen und ohne runde Maske), die Prüfung schaut sich die App auf
einer Uhr an.

### Wear-Screenshots

Die Bilder unter `wearScreenshots/` (454 × 454, `wear-01-menu` bis
`wear-04-defense`) entstehen im runden Emulator (Gerät
`wearos_large_round`, Systemabbild `android-36;android-wear-signed`).
Startargumente erreichen die Einstellungen auf Android nicht, darum kommen
Szene und Sprache als Define in einen Debug-Build, einer je Bild:

```sh
flutter build apk --debug --android-project-arg=wear=true \
  --dart-define=SHOTS=true --dart-define=SHOT_SCENE=battle --dart-define=SHOT_LANG=de
adb install -r -d build/app/outputs/flutter-apk/app-debug.apk
adb shell am start -n de.regetskcob.wargame/.MainActivity
# rund 25 s warten, bis die Szene steht (Gefecht 18 s, sonst ist die Runde vorbei)
adb exec-out screencap -p > wear-03-battle.png
```

Szenen wie bei der Apple Watch: `menu`, `lobby`, `battle`, `defense`.
`screencap` liefert das ganze Quadrat ohne Rahmen. Die schwarzen Ecken
zeichnet das runde Layout der App selbst, wie auf jeder runden Uhr.

## Angaben in der Play Console

**Datensicherheit:** Keine Weitergabe an Dritte, kein Tracking, Übertragung
verschlüsselt (HTTPS zu Supabase). Erhoben, nur für die App-Funktion und die
Kontoverwaltung:

- Personenbezogene Daten → E-Mail-Adresse (optional, nur wer sein Konto sichert)
- Personenbezogene Daten → Nutzer-IDs (anonyme Kennung des Gastkontos)
- App-Aktivitäten → Andere nutzergenerierte Inhalte (Rufname, Fahrzeug, Spielstände)
- App-Aktivitäten → Interaktionen mit der App (Statistiken, Runden, Wertung)
- Geräte- oder andere IDs (Kennung pro Installation) und App-Info und
  Leistung → Diagnosedaten, beide für Analysen: Googles ML Kit hinter dem
  QR-Scanner (`mobile_scanner`) sendet sie an Google, nicht an Dritte,
  siehe <https://developers.google.com/ml-kit/android-data-disclosure>

**Werbe-ID:** Nein, das Bundle trägt keine `AD_ID`-Berechtigung und kein
Werbe-SDK.

**Einstufung (IARC-Fragebogen):** Kategorie Spiel. Comicartige Gewalt
gegen Fahrzeuge und winzige Soldaten in der Draufsicht; wo ein Soldat
überrollt wird, bleibt ein kleiner roter Fleck, der braun eintrocknet
(`BloodSplat` in `soldier.dart`), also „Blut: ja, gering“. Nutzer interagieren
nicht per Chat, sehen aber selbst gewählte Rufnamen in Raum und Bestenliste.
Ergibt voraussichtlich USK 12 / PEGI 12.

**Zielgruppe:** 13 Jahre und älter, so fällt die App nicht unter die
Familienrichtlinien.

**App-Zugriff:** Alle Funktionen ohne Zugangsdaten verfügbar („ALS GAST
SPIELEN“). Den Text aus `../ios/metadata/review_notes.txt` als Hinweis
übernehmen.

**Werbung:** Nein. **Kategorie:** Spiele > Action, Tags Strategie und
Mehrspieler.

**Kamera:** Die App fragt nach der Kamera nur, um den QR-Code eines
Warteraums zu lesen. Das Bild bleibt auf dem Gerät, für das Bild selbst
wird in der Datensicherheit nichts angegeben, nur die Diagnosedaten von
ML Kit (oben). Die Kamera ist als optional deklariert, Geräte
ohne Kamera bleiben im Store.

**Datenschutz-URL:** `https://panzergefecht.de/datenschutz/` (wie im
App Store).

**Kontolöschung (Datensicherheit):** In der App über Konto > „Konto löschen“.
Als Web-Adresse für Löschanfragen ohne App dieselbe Datenschutz-URL angeben,
sie nennt die Löschung per E-Mail.

## Vor der Veröffentlichung offen

1. **Geschlossener Test:** Neue private Entwicklerkonten müssen vor der
   Produktion mindestens 12 Tester 14 Tage lang im geschlossenen Test
   (`alpha`) haben. Tester-Liste per E-Mail anlegen, `testflight.txt` aus dem
   iOS-Ordner taugt als Testhinweis.
2. **Einrichtung oben:** App anlegen, erster Upload von Hand, Dienstkonto und
   Secrets.
3. **Wear OS:** Formfaktor in der Play Console hinzufügen, die
   Wear-Screenshots aus `wearScreenshots/` hochladen, die App einmal auf
   einer echten Uhr spielen.
