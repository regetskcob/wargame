# Skeleton

The starting point for the workshop exercises. Everything that is plumbing
rather than learning is already in place, so you can spend the workshop on
Flame and Supabase Realtime instead of on `pubspec.yaml`.

## What you get

| Path | What it is |
| --- | --- |
| `pubspec.yaml` | `flame`, `supabase_flutter` 3.0.0-dev.9, `audioplayers` and `supabase_typegen`, all from pub.dev |
| `lib/main.dart` | The entry point: initializes Supabase and signs in anonymously |
| `lib/src/env.dart` | The Supabase URL, publishable key, and room, defaulted to the local stack |
| `lib/src/game_config.dart` | Every tuning constant the exercises refer to, plus the paint schemes and teams |
| `lib/src/tanks/` | The four vehicles (Leopard 2, Puma, Gepard, Boxer), drawn in code, and their stats |
| `lib/src/theme.dart` | The Bundeswehr look: colours, buttons, text fields |
| `lib/src/audio_service.dart`, `assets/audio/` | Sound effects, played through the Web Audio API on the web |
| `lib/src/app/` | A placeholder shell: shows your session, the four vehicles and buttons to hear the sounds |
| `web/` | Web scaffolding, so `flutter run -d chrome` works out of the box |

Nothing else. The game itself is what you build: movement, the netcode, rules
and rounds. The sounds come from `tool/gen_sounds.py`, run it from this
directory to regenerate them.

## Run it

From the repository root, once:

```sh
dart pub get
```

Then:

```sh
cd packages/skeleton
flutter run -d chrome
```

To run against a hosted project instead of the local stack, replace the
default values in `lib/src/env.dart` with your project URL and publishable key,
then run the same command. Change the room default to play in a separate room.

The status screen turns green once the app has a Supabase session.

## Reference

`packages/game` is the finished version. Reach for it when you fall behind,
but write the code yourself first.
