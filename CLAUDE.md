# Panzergefecht – Leitfaden für Claude

Bundeswehr-Panzerspiel (Flutter 3.47 + Flame 2.0, Supabase als einziges
Backend, kein eigener Server). Live unter <https://www.regetskcob.de/wargame/>,
dazu iOS/Android-Apps (`de.regetskcob.wargame`) und eine Apple-Watch-App.
Die README ist das Schaufenster für Besucher (Screenshots, Modi, Highlights,
Schnellstart), die ausführliche Referenz liegt in `docs/` (`gameplay.md`,
`platforms.md`, `netcode.md`, `development.md`); diese Datei ist der
Schnelleinstieg.

Beim Sitzungsstart zeigt der Hook `tool/session_context.sh` Branch, Abstand zu
`origin/main`, letzte Commits und die neueste Migration. Erst lesen, dann
vorschlagen: Vieles, was nach "neuer Idee" klingt, existiert schon
(README → Highlights, `docs/gameplay.md`, `git log`).

## Spielmodi in einem Satz

- `GameMode.solo` – allein gegen CPU-Panzer (Bot-Stufen leicht/mittel/schwer
  steuern Mechanik: Hügel, Treibstoff, Munition, Gems).
- `GameMode.multi` – Last Tank Standing gegen Menschen (+ Bots zum Auffüllen,
  Teams möglich).
- `GameMode.defense` – Tower Defense im Trupp gegen Wellen (Host ist
  Autorität), Stützpunkt wächst, nach Welle 8 Verlängerung.

## Architektur in 7 Punkten

1. **Eine Runde = `{seed, startedAt}`.** Welt, Wetter, Tag/Nacht, Fallschirm-
   wellen folgen deterministisch aus dem Seed. Nur Ereignisse gehen übers Netz.
2. **Peer-autoritativ:** Jeder simuliert seinen Panzer und seine Geschosse,
   das Opfer wendet Schaden selbst an. Im Verteidigungsmodus ist der Host
   Autorität über Wellen, Stützpunkt und Geschütz-HP.
3. **Ein Realtime-Kanal pro Raum** (`game-arena-<room>`), Events in
   `lib/src/net/net_events.dart`, Payloads in `lib/src/net/payloads/`.
   Presence für Lobby, Host-Rolle, Raumliste (`game-rooms`), Handy-Controller
   (`pad-<CODE>`).
4. **`plausibility.dart`** prüft fremde Nachrichten (kein Anti-Cheat).
5. **Wertung nur über RPC `record_round`** (Elo, EP, Abzeichen); Gäste ohne
   Wertung. RLS ist gehärtet (Migration 0011/0012).
6. **Replays** = aufgezeichnete Nachrichten + Seed, rein lokal.
7. **Realtime-Budget:** Jede Nachricht zählt einmal gesendet und einmal pro
   Empfänger, projektweit 100/s und 2 Mio./Monat im Free-Plan. Darum
   `state` mit 10/s, CPU-Panzer gebündelt in `states`, allein im Raum wird
   nichts gesendet, Presence gedrosselt. Raumgröße `MAX_PILOTS` (Standard
   4) und ein Last-Budget `REALTIME_BUDGET` (Standard 400/s, Pro-Plan;
   im Free-Plan 2 und 80) folgen dem
   Supabase-Plan: Räume ab zwei Piloten und Handy-Controller belegen ihre
   Last über `claim_load` (Migrationen 0015/0016, `RoomSlots`), mit Handy
   im Raum keine CPU-Auffüllung, jedes Handy auf eigener Spur
   `pad-<CODE>-<Handy>`. Ohne
   Server startet das Spiel trotzdem (`ServerStatus`). Zahlen und Tests:
   `docs/netcode.md` „Realtime limits“.

## Wo finde ich was

| Thema | Ort |
| --- | --- |
| Herzstück `TankGame` | `lib/src/game/tank_game.dart` hält nur Felder, Konstruktor und die Flame-Overrides (`onLoad`, `update`, `render`, `onKeyEvent`, `onGameResize`). Die Methoden stehen nach Thema in `lib/src/game/tank_game/` als `extension TankGameXyz on TankGame` (`part`-Dateien, private Namen bleiben sichtbar): `lobby` (Warteraum, Pilot, Host, Raum schließen), `round` (Rundenstart bis Rundenende, Tode, Zuschauen), `replay`, `defense` (Wellen, Stützpunkt, Geschütze), `air`, `infantry`, `items` (Kisten, Gems, Inventar, Upgrades, Minen, Artillerie), `combat` (Schüsse, Treffer, Explosionen), `targeting` (nächster Gegner, Sicht), `view` (Kamera, Shake, Hinweise) |
| Balancing-Zahlen | `lib/src/game/game_config.dart`, `tank_stats.dart`, `upgrades.dart`, `bot_level.dart` |
| Bots | `bot_brain.dart`, `bot_items.dart`, `defense/defense_brain.dart`, `defense/ally_brain.dart` |
| Verteidigung | `lib/src/game/defense/` (`defense_director.dart` = Wellen, `tower.dart`, `aircraft.dart`, `defense_map.dart`) |
| Flame-Komponenten | `lib/src/game/components/` (`player_tank.dart`, `tank_painter.dart`, `soldier.dart`, …) |
| Netz | `lib/src/net/net_service.dart` (Kanal, `_listen`), `room_web.dart`/`room_stub.dart`, `pad_link.dart` |
| UI / Overlays | `lib/src/ui/` (`hud_overlay.dart`, `lobby_overlay.dart`, `launch_view.dart`, `welcome_view.dart`), Overlay-IDs in `app/overlay_ids.dart` |
| Watch | `lib/src/watch/`, verzweigen nur mit `FlutterWatchosPlatform.isWatch` |
| Apple TV | `tvos/` (flutter-tvos), `lib/src/tv/` (Steuerung, Fokusrahmen, zweiter Spieler mit eigener Spielinstanz im selben Raum + Split-Screen; Stützpunkt-Duell = Verteidigung mit `lanes`, Teams über `RoundState.teamOf`), verzweigen nur mit `onTv`, nie `Platform.isIOS` allein; Native-Seite `tvos/Runner/GamepadPlugin.swift` |
| Texte DE/EN | `lib/src/l10n/l10n.dart` – jeder sichtbare Text in beiden Sprachen |
| DB | `supabase/migrations/NNNN_*.sql`, Dienste in `lib/src/db/`, generiert: `supabase_schema.g.dart` |
| Build-Flags | `lib/src/app/env.dart` (`SUPABASE_URL`, `SUPABASE_KEY`, `ROOM`, `ACCOUNTS`, `WEB_URL`) |
| Store/Release | `store/ios`, `store/android` (je README), Workflows `testflight`, `play` (manuell) |
| Tests | `test/` spiegelt `lib/src`, Fakes in `test/helpers/fakes.dart` |

## Befehle

```sh
flutter pub get
tool/verify.sh --quick        # format, analyze, test (ohne supabase-Tag)
tool/verify.sh                # + web, iOS (no-codesign), Android appbundle
flutter run -d chrome --dart-define=ROOM=dev   # zweimal starten = 2 Spieler
```

Tests mit Tag `supabase` brauchen `supabase start` (lokaler Stack, Port 54621).

## Arbeitsweise (vom Nutzer festgelegt)

- **Direkt auf `main`**, keine PRs: Branch mit `origin/main` mergen, prüfen,
  pushen. Push auf `main` deployt sofort per GitHub Pages.
- **Vor jedem Push grün, im Umfang passend zur Änderung**, im Abschluss
  nennen, was lief. Skill `/ship`. Kleine Änderungen nur an Dart-Code oder
  Doku: `tool/verify.sh --quick` reicht (den Web-Build macht `pages`).
  Voller Lauf (`tool/verify.sh`: Web, iOS, Android) bei `pubspec.*`,
  `ios/`, `android/`, `tvos/`, Watch, Assets, Plugins, Versionsnummer,
  größeren Umbauten und vor Store-Releases.
- Code, Kommentare, Commit-Messages, README und `docs/` auf **Englisch**; Commits als
  ganzer Satz im Imperativ ohne Präfix ("Put leave on the left …").
  Mit dem Nutzer auf Deutsch sprechen.
- Kommentare erklären das *Warum*; `docs/` (Gameplay, Plattformen, Netcode)
  und README (Highlights, Roadmap) mitpflegen, wenn sich Verhalten ändert.
  Die README bleibt kurz: Details und Tabellen gehören nach `docs/`.
- `dart format` ist in CI Pflicht.
- Neue Netz-Events: Skill `/net-event`. Neue Migration: Skill `/db-migration`.
- `TankGame` wächst nicht wieder zu: neue Felder in `tank_game.dart`, neue
  Methoden in die passende Datei unter `tank_game/` (oder eine neue
  `part`-Datei mit eigener Extension). Statische Member dort mit
  `TankGame.` ansprechen. Dateien, die Methoden von `TankGame` aufrufen,
  müssen `tank_game.dart` selbst importieren, sonst sieht Dart die
  Extensions nicht.

## Stolperfallen

- `supabase db push` aus einem Worktree: vorher
  `/Users/regetskcob/wargame/supabase/.temp` in den Worktree kopieren.
- Nach `supabase_typegen` die Default-Fallbacks für nachträglich ergänzte
  Spalten in `supabase_schema.g.dart` wiederherstellen (siehe `docs/development.md`).
- SQL ohne Docker prüfen: PGlite (npm) im Scratchpad mit auth-Stub.
- Live-Auth-Einstellungen (SMTP, Redirects, OAuth) setzt der Nutzer im
  Supabase-Dashboard, nicht Claude.
- Die Repo ist **öffentlich**: keine Secrets, keine `key.properties`.
- Plugins ohne `*_watchos`-Paket (`app_links`, `share_plus`,
  `mobile_scanner`) werfen auf der Uhr `MissingPluginException`.
