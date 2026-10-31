# Contributing

Issues and pull requests are welcome. By contributing you agree that your work
is published under the MIT licence of this repository.

## Run it

```sh
flutter pub get
supabase start
flutter run -d chrome --dart-define=ROOM=dev \
  --dart-define=SUPABASE_URL=http://127.0.0.1:54621 \
  --dart-define=SUPABASE_KEY=<anon key from supabase start>
```

Please develop against the local stack, or your own Supabase project. A build
without these defines talks to the live game, whose Realtime budget is paid for
by the supporter packs and shared by all players.

## Before a pull request

```sh
tool/release.sh verify --quick
```

- Code, comments and docs in English; comments explain why.
- Every visible text in German and English (`lib/src/l10n/l10n.dart`).
- Nothing that decides a fight is ever sold (docs/purchases.md).
- New network events and migrations: `.claude/skills/net-event` and
  `.claude/skills/db-migration` are the checklists.
