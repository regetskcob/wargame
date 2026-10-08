# Google Play

Alles, was die Play Console für Panzergefecht braucht. Die Ordner folgen dem
Aufbau von `fastlane supply`: Der Workflow `play` lädt Bundle, Texte und
Bilder hoch (siehe [Deployment](#deployment)). Von Hand lassen sie sich genauso
in der Play Console einfügen (Store-Präsenz > Haupteintrag im Play Store).

| Feld in der Play Console | Datei |
| --- | --- |
| App-Name (max. 30) | `metadata/android/de-DE/title.txt` |
| Kurzbeschreibung (max. 80) | `metadata/android/de-DE/short_description.txt` |
| Vollständige Beschreibung (max. 4000) | `metadata/android/de-DE/full_description.txt` |
| Versionshinweise (max. 500) | `metadata/android/de-DE/changelogs/default.txt`, für eine bestimmte Version `<versionCode>.txt` |
| App-Symbol 512 × 512 | `metadata/android/de-DE/images/icon.png` |
| Vorstellungsgrafik 1024 × 500 | `metadata/android/de-DE/images/featureGraphic.png` |
| Smartphone-Screenshots (1080 × 1920) | `metadata/android/de-DE/images/phoneScreenshots/*.png` |
| Tablet-Screenshots 7" (1920 × 1200) | `metadata/android/de-DE/images/sevenInchScreenshots/*.png` |
| Tablet-Screenshots 10" (2560 × 1600) | `metadata/android/de-DE/images/tenInchScreenshots/*.png` |

Play erlaubt keine Seite, die mehr als doppelt so lang ist wie die andere, die
6,9"-Bilder aus dem App Store passen deshalb nicht. `../tool/compose.py`
baut aus denselben Rohaufnahmen beide Sätze und die Vorstellungsgrafik,
`../tool/android_icons.py` die Launcher-Icons (klassisch und adaptiv) und das
Play-Symbol aus dem App-Store-Icon:

```sh
pip3 install --user pillow
python3 store/tool/compose.py <ordner-mit-rohaufnahmen>
python3 store/tool/android_icons.py
```

Die Screenshots zeigen die iOS-Rohaufnahmen ohne Statusleiste, das Spiel
zeichnet auf Android dasselbe Bild.

## Build und Signieren

App-ID `de.regetskcob.wargame` wie auf iOS, Name Panzergefecht. Die App-ID lässt sich
nach dem ersten Upload nie mehr ändern.

1. Upload-Schlüssel einmalig anlegen und `android/key.properties` nach
   `android/key.properties.example` ausfüllen (beides ignoriert git).
2. `flutter build appbundle --release --dart-define=SUPABASE_URL=...
   --dart-define=SUPABASE_KEY=...` (oder `melos run build:game:appbundle`),
   Ergebnis: `build/app/outputs/bundle/release/app-release.aab`.
3. In der Play Console **Play App Signing** aktiv lassen: Google hält den
   App-Signaturschlüssel, wir nur den Upload-Schlüssel.
4. Der versionCode muss mit jedem Upload steigen. Der Workflow setzt ihn auf
   die Laufnummer plus eins, für sichtbare Versionen `version:` in
   `pubspec.yaml` hochzählen (der Teil vor dem `+` ist der versionName).

Ohne `key.properties` signiert Gradle mit dem Debug-Schlüssel. So baut CI,
Play nimmt ein solches Bundle aber nicht an.

## Deployment

Hochgeladen wird mit `fastlane supply` aus `android/fastlane`, in CI über den
Workflow **play** (Actions > play > Run workflow). Er baut das signierte
Bundle mit den Repository-Variablen `SUPABASE_URL`, `SUPABASE_KEY` und
`ACCOUNTS` wie die Webversion und lädt es in den gewählten Track:

| Eingabe | Bedeutung |
| --- | --- |
| `track` | `internal` (interner Test), `alpha` (geschlossen), `beta` (offen), `production` |
| `release_status` | `draft`, solange Store-Eintrag und Fragebögen unvollständig sind, danach `completed` |
| `metadata` | Texte, Icon, Vorstellungsgrafik und Screenshots mit hochladen |

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
4. **GitHub-Secrets** (Settings > Secrets and variables > Actions):

   | Secret | Inhalt |
   | --- | --- |
   | `ANDROID_KEYSTORE_BASE64` | `base64 -i upload-keystore.jks \| pbcopy` |
   | `ANDROID_KEYSTORE_PASSWORD` | Passwort des Keystores |
   | `ANDROID_KEY_PASSWORD` | Passwort des Schlüssels |
   | `ANDROID_KEY_ALIAS` | `upload` |
   | `PLAY_SERVICE_ACCOUNT_JSON` | Inhalt der JSON-Datei des Dienstkontos |

5. **Prüfen:** Lokal die JSON-Datei als `android/play-service-account.json`
   ablegen (git ignoriert sie), dann in `android/`:

   ```sh
   bundle install
   bundle exec fastlane validate
   ```

### Lokal hochladen

```sh
cd packages/game
flutter build appbundle --release --build-number=<versionCode> --dart-define=ACCOUNTS=true
cd android
bundle exec fastlane deploy track:internal metadata:true
bundle exec fastlane metadata                      # nur Texte und Bilder
bundle exec fastlane promote from:internal to:alpha
```

Ohne `release_status:completed` landet das Release als Entwurf und muss in
der Play Console freigegeben werden. Solange die App noch nie freigegeben
wurde, nimmt die API ohnehin nur Entwürfe an.

## Angaben in der Play Console

**Datensicherheit:** Keine Weitergabe an Dritte, kein Tracking, Übertragung
verschlüsselt (HTTPS zu Supabase). Erhoben, nur für die App-Funktion und die
Kontoverwaltung:

- Personenbezogene Daten → E-Mail-Adresse (optional, nur wer sein Konto sichert)
- Personenbezogene Daten → Nutzer-IDs (anonyme Kennung des Gastkontos)
- App-Aktivitäten → Andere nutzergenerierte Inhalte (Rufname, Fahrzeug, Spielstände)
- App-Aktivitäten → Interaktionen mit der App (Statistiken, Runden, Wertung)

**Einstufung (IARC-Fragebogen):** Kategorie Spiel. Gewalt gegen
nicht realistische Figuren bzw. Fahrzeuge, kein Blut. Nutzer interagieren
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
Warteraums zu lesen. Das Bild bleibt auf dem Gerät, in der Datensicherheit
wird dafür nichts angegeben. Die Kamera ist als optional deklariert, Geräte
ohne Kamera bleiben im Store.

**Datenschutz-URL:** `https://www.regetskcob.de/wargame/datenschutz/` (wie im
App Store, erreichbar nach dem nächsten Web-Deploy).

**Kontolöschung (Datensicherheit):** In der App über Konto > „Konto löschen“.
Als Web-Adresse für Löschanfragen ohne App dieselbe Datenschutz-URL angeben,
sie nennt die Löschung per E-Mail.

## Vor der Veröffentlichung offen

1. **Geschlossener Test:** Neue private Entwicklerkonten müssen vor der
   Produktion mindestens 12 Tester 14 Tage lang im geschlossenen Test
   (`alpha`) haben. Tester-Liste per E-Mail anlegen, `testflight.txt` aus dem
   iOS-Ordner taugt als Testhinweis.
2. **Migration 0010 einspielen:** `supabase db push` legt `delete_account` an,
   ohne sie bricht „Konto löschen“ ab. Play prüft das.
3. **Einrichtung oben:** App anlegen, erster Upload von Hand, Dienstkonto und
   Secrets.
