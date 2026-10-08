# Google Play

Alles, was die Play Console für Wargame braucht. Die Ordner folgen dem
Aufbau von `fastlane supply`, die Dateien lassen sich aber genauso von Hand
in der Play Console einfügen (Store-Präsenz > Haupteintrag im Play Store).

| Feld in der Play Console | Datei |
| --- | --- |
| App-Name (max. 30) | `metadata/android/de-DE/title.txt` |
| Kurzbeschreibung (max. 80) | `metadata/android/de-DE/short_description.txt` |
| Vollständige Beschreibung (max. 4000) | `metadata/android/de-DE/full_description.txt` |
| Versionshinweise (max. 500) | `metadata/android/de-DE/changelogs/1.txt` (Name = versionCode) |
| App-Symbol 512 × 512 | `metadata/android/de-DE/images/icon.png` |
| Vorstellungsgrafik 1024 × 500 | `metadata/android/de-DE/images/featureGraphic.png` |
| Smartphone-Screenshots (1080 × 1920) | `metadata/android/de-DE/images/phoneScreenshots/*.png` |
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

App-ID `de.regetskcob.wargame` wie auf iOS, Name Wargame. Die App-ID lässt sich
nach dem ersten Upload nie mehr ändern.

1. Upload-Schlüssel einmalig anlegen und `android/key.properties` nach
   `android/key.properties.example` ausfüllen (beides ignoriert git).
2. `flutter build appbundle --release --dart-define=SUPABASE_URL=...
   --dart-define=SUPABASE_KEY=...` (oder `melos run build:game:appbundle`),
   Ergebnis: `build/app/outputs/bundle/release/app-release.aab`.
3. In der Play Console **Play App Signing** aktiv lassen: Google hält den
   App-Signaturschlüssel, wir nur den Upload-Schlüssel.
4. Für jede neue Version `version:` in `pubspec.yaml` hochzählen, die Zahl
   hinter dem `+` ist der versionCode und muss steigen.

Ohne `key.properties` signiert Gradle mit dem Debug-Schlüssel. So baut CI,
Play nimmt ein solches Bundle aber nicht an.

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

## Vor der Veröffentlichung offen

1. **Geschlossener Test:** Neue private Entwicklerkonten müssen vor der
   Produktion mindestens 12 Tester 14 Tage lang im geschlossenen Test haben.
   Tester-Liste per E-Mail anlegen, `testflight.txt` aus dem iOS-Ordner taugt
   als Testhinweis.
2. **Datenschutz-URL:** Wie bei iOS Pflicht, die Erklärung steht bisher nur im
   Spiel (`lib/src/ui/widgets/legal.dart`) und beschreibt nur den Browser.
3. **Konto löschen:** Play verlangt das Löschen in der App **und** eine
   Web-Adresse, unter der man die Löschung ohne die App beantragen kann
   (Datensicherheit > Kontolöschung). Beides fehlt noch.
4. **Raumcodes:** Wie auf iOS trifft sich Mehrspieler in der App immer im Raum
   `main`, die Startkarte verspricht trotzdem „Lade per Link oder Code ein“
   (zu sehen auf `phoneScreenshots/06-modi.png`).
