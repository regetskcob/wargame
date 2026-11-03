# What this game shows about Flutter

One Dart code base, one game, every screen. This page is for Flutter
developers who want to see a technique working in a real app: each row
points at where to read it. Start with the netcode if you only read one
thing.

| Possibility | Here | Where |
| --- | --- | --- |
| One code base on many platforms | Web, iOS, iPadOS, Android, macOS, tvOS, Android TV and Fire TV, watchOS, Wear OS | `lib/src/`, [platforms.md](platforms.md), [tv.md](tv.md) |
| Real-time 2D with Flame | World, tanks, weather and day and night at the frame rate of a game | `lib/src/game/` |
| Flutter widgets above a game | Menus, HUD and shop as overlays on the game canvas | `lib/src/ui/`, `app/overlay_ids.dart` |
| Deterministic multiplayer | One seed makes the same world on all clients, only events travel | [netcode.md](netcode.md) |
| A backend without a server | Supabase Realtime, Postgres with row level security, typed tables, edge functions | `lib/src/net/`, `lib/src/db/`, `supabase/` |
| Platform channels | Watch crown, TV remote as a gamepad, iMessage extension | `tvos/Runner/GamepadPlugin.swift`, `android/app/src/main/kotlin/de/regetskcob/wargame/` (`WearPlugin.kt`, `GamepadPlugin.kt`), `ios/MessagesExtension` |
| Adaptive layout | Watch face, round watch, phone, tablet, desktop, television, split screen | `lib/src/watch/`, `lib/src/tv/`, `test/ui/overlays_smoke_test.dart` |
| A design system as a package | Horizont: tokens, fonts and widgets, shared with the website | `lib/src/ui/theme.dart`, `site/go.mod` |
| Testing a game | Whole rounds headless, every overlay on every screen, goldens, a message budget | `test/` |
| In-app purchases without a third party | The official plugin and an own verifying function | [purchases.md](purchases.md) |
