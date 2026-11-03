# Contributing

Issues and pull requests are welcome. By contributing you agree that your work
is published under the MIT licence of this repository.

## Run it

```sh
flutter pub get
supabase start
flutter run -d chrome --dart-define=ROOM=dev \
  --dart-define=SUPABASE_URL=http://127.0.0.1:54621 \
  --dart-define=SUPABASE_KEY=<publishable key printed by supabase start>
```

Please develop against the local stack, or your own Supabase project. A build
without these defines talks to the live game, whose Realtime budget is paid for
by the supporter packs and shared by all players. The full handbook is
[docs/development.md](docs/development.md); running a copy under your own name
is [docs/forking.md](docs/forking.md).

## Before a pull request

```sh
tool/release.sh verify --quick
```

- Code, comments and docs in English; comments explain why.
- Every visible text in German and English (`lib/src/l10n/l10n.dart`).
- Nothing that decides a fight is ever sold (docs/purchases.md).
- `dart format` clean, `flutter analyze` without findings, tests green and
  line coverage at 75 % or more; `verify --quick` checks all of it.
- New network events and migrations: `.claude/skills/net-event/SKILL.md` and
  `.claude/skills/db-migration/SKILL.md` are the checklists.
- Behaviour changes update the docs (`docs/`, README) and both changelogs,
  `CHANGELOG.md` and `CHANGELOG.de.md`, in the same commit.
