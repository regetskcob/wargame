# Standard für App-Repos

Gilt für alle Flutter-App-Repos (KNX Monitor, Panzergefecht, Jagdaufseher, Kalkar
informiert und alle neuen). Ziel: Jedes Projekt läuft gleich ab und legt gleich ab. Was ein
Projekt anders macht, steht in seiner `CLAUDE.md` und in `tool/werkbank.conf`.

## Ordnerstruktur

Jede Datei hat genau einen Ort. `werkbank layout` (Teil von `werkbank verify` und der CI)
lehnt unbekannte Einträge auf oberster Ebene und Medien außerhalb ihrer Ordner ab.

| Ordner | Inhalt |
|---|---|
| `lib/` | App-Quellcode |
| `test/` | Unit-, Widget- und Golden-Tests; Goldens in einem Unterordner `goldens/` |
| `integration_test/`, `test_driver/` | Tests auf Gerät oder Simulator, Store-Aufnahmen, Driver-Einstiege |
| `assets/` | Dateien, die in die App gebündelt werden – nur die |
| `android/`, `ios/`, `macos/`, `linux/`, `windows/`, `web/` | Plattformprojekte (Flutter-Standard) |
| `docs/` | Doku als Markdown; Bilder in `docs/images/<thema>/`, gedruckte Dokumente in `docs/pdf/` (Quellen und `build.sh` in `docs/pdf/<dokument>/`) |
| `tool/` | Skripte des Projekts; ein Werkzeug mit mehreren Dateien bekommt einen eigenen Ordner. `tool/werkbank/` ist die Kopie der werkbank, `tool/werkbank.conf` ihre Einstellung |
| `store/` | Alles für die Stores (Aufbau unten). Eingecheckt, außer das Projekt hält es privat – dann in `.gitignore`, und die `CLAUDE.md` sagt es |
| `site/` | Landingpage (Hugo); was sie ausliefert, liegt in `site/static/` oder `site/assets/` |
| `supabase/` | Backend (Migrationen, Funktionen, Vorlagen) |
| `build/` | Alles Erzeugte, ignoriert. `flutter clean` löscht es – was bleiben soll, gehört nicht hierhin |

Wurzeldateien: `README.md`, `CLAUDE.md`, `LICENSE`, `CHANGELOG.md` (ggf. `CHANGELOG.de.md`),
`pubspec.*`, `analysis_options.yaml`, `l10n.yaml`, `dart_test.yaml`, `build.yaml`.
Weitere Wurzelordner nur für eigenständige Produkte neben der App (z. B. `ha-addon/`,
`box/` bei KNX Monitor), eingetragen in `WB_TOP_EXTRA`.

### `store/`

```
store/
  ios/metadata/<de-DE|en-US>/      Texte im fastlane-deliver-Format (name.txt, description.txt, …)
  ios/screenshots/<de-DE|en-US>/   fertige Screenshots, Präfix nach Gerät: iphone69_01_<name>.png, ipad13_…
  ios/review/                      Hinweise und Bilder für die App-Prüfung
  android/metadata/<de-DE|en-US>/  Texte und images/ im fastlane-supply-Format
                                   (images/phoneScreenshots/, sevenInchScreenshots/, tenInchScreenshots/,
                                   featureGraphic.png, icon.png)
  macos/screenshots/<de-DE|en-US>/
  raw/<gerät>/<de|en>/             Rohaufnahmen vor dem Rahmen (gerät: iphone, ipad, android-phone,
                                   android-tablet, mac, …); Querformat als <de|en>-land
  graphics/                        Banner, OG-Bilder und andere Store-Grafiken
  release/<version>/               Archiv hochgeladener Builds (immer ignoriert)
  archiv/                          alte Läufe, Sicherungen, Logs (immer ignoriert)
```

Sprachen: Store-Ordner heißen wie die Stores (`de-DE`, `en-US`), Rohaufnahmen wie die
App-Sprache (`de`, `en`).

## Ablauf

Jedes Projekt hat **einen** Einstieg `tool/release.sh <befehl>`. Die gemeinsamen Schritte
ruft es über `tool/werkbank/bin/werkbank` auf; was nur das Projekt hat (Add-on, Box,
Watch-App, Seiten-Deploy), steht als eigener Befehl daneben.

| Befehl | Was | Quelle |
|---|---|---|
| `verify` | vor jedem Push: Layout, Übersetzungen, Format, Analyse, Tests, dann `verify_extra` | `werkbank verify` |
| `android` | signiertes AAB nach `build/release/<app>-<version>.aab`, Prüfung gegen den Debug-Schlüssel, Symbole wegsichern | `werkbank android` |
| `ios` | IPA nach `build/release/<app>-<version>.ipa`, mit `--upload` zu App Store Connect | `werkbank ios` |
| `shots` | Rohaufnahmen nach `store/raw/` | Projekt (Simulator über `werkbank sim`) |
| `graphics` | aus `store/raw/` die fertigen Bilder in `store/<plattform>/…` | Projekt |

- **Version** nur in `pubspec.yaml` (`x.y.z+build`); Skripte lesen sie mit `werkbank version`.
- **CI** läuft auf Pull Requests (Linux) mit denselben Schritten wie `verify --quick`; teure
  Builds (macOS, Windows) nur auf Tag oder von Hand. Release-Builds entstehen lokal.
- **Ausgaben:** Erzeugtes nach `build/`, Release-Dateien nach `build/release/`, Symbole von
  `--split-debug-info` nach `~/keys/symbols/<app>/<version>/<plattform>/`.

## Schlüssel und Geheimnisse

Nie im Repo. Gleiche Namen in allen Projekten:

| Was | Wo |
|---|---|
| Android-Upload-Schlüssel | `~/keys/<name>-upload.jks`, verwiesen aus `android/key.properties` (ignoriert) |
| App Store Connect | `ASC_KEY_ID`, `ASC_ISSUER_ID`, Datei `ASC_KEY_PATH` (Standard `~/.appstoreconnect/private_keys/AuthKey_<id>.p8`) |
| Google Play (Upload per fastlane) | `PLAY_JSON_KEY` (Pfad zur Dienstkonto-JSON) |
| Build-Werte der App (Supabase, RevenueCat, …) | `~/.config/<app>/<name>.env`, im Projekt mit `wb_env_file` geladen |

## werkbank.conf

`tool/werkbank.conf` ist eine Bash-Datei, die `werkbank` vor jedem Befehl lädt. Alles ist
optional; Vorlage: `werkbank.conf.example` im werkbank-Repo.

| Name | Standard | Wofür |
|---|---|---|
| `WB_APP` | `name` aus `pubspec.yaml` | Dateinamen der Release-Dateien, Symbolordner |
| `WB_TOP_EXTRA` | – | weitere Wurzeleinträge (Regex-Alternativen) |
| `WB_MEDIA_EXTRA` | – | weitere Medienordner (Regex, mit `/` am Ende) |
| `WB_FORMAT_PATHS` | `lib test` | Pfade für `dart format` |
| `WB_ANALYZE_ARGS`, `WB_TEST_ARGS` | – | zusätzliche Argumente |
| `WB_SYMBOLS_DIR` | `~/keys/symbols/<app>` | Ziel für Debug-Symbole |
| `android_args`, `ios_args` | – | Funktionen, die Build-Argumente ausgeben |
| `verify_extra` | – | Funktion mit weiteren Prüfungen (Web-Build, Server, Hugo) |

## werkbank aktualisieren

Die werkbank liegt als Kopie in `tool/werkbank/`, damit Projekt und CI ohne Zugang zum
privaten werkbank-Repo laufen. Änderungen entstehen im werkbank-Repo, dann je Projekt:

```bash
~/dev/werkbank/install.sh ~/dev/<projekt>
```

und ein PR im Projekt. `tool/werkbank/VERSION` zeigt, welcher Stand drin ist.
