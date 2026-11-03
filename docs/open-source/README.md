# Going open source

**Prepared, not active.** Until the steps below are done the repository stays
"all rights reserved" (`/LICENSE`), and neither the game nor the landing page
calls it open source. The files here are drafts that move to the root on the
day: moving them is the act of granting the licence, and it cannot be taken
back for what was published under it.

## The idea

Panzergefecht becomes a public showcase of what Flutter can do
([docs/flutter-showcase.md](../flutter-showcase.md)). The game stays free. The
two packs (docs/purchases.md) pay for Supabase Pro, the domain and hosting.

## Blockers

| What | State |
| --- | --- |
| Henrik Stamm's code (fork history) | Rights assigned, says the owner. Keep the written assignment. |
| Lukas Klingsbo's code, about 1,400 lines still in the tree. All 21 of his commits are in the upstream repository. | Done: MIT since [spydon/supabase_flame_workshop#1](https://github.com/spydon/supabase_flame_workshop/pull/1), merged by him on 2026-11-03 after his consent by mail the same day. Keep the mail. |
| Licence | Confirmed by the owner (2026-11-03): MIT for code, name and icon kept (`NOTICE`). |
| `tool/werkbank/`, a copy of the maintainer's werkbank repository | MIT since werkbank v0.1.3, whose copy brings its `LICENSE`; this repository still holds v0.1.2. Install v0.1.3 (`~/dev/werkbank/install.sh`) before the switch. |
| Horizont (git dependency) | Done: the pinned tag v0.9.1 carries a plain MIT `LICENSE`. |

## The switch, in one change

1. `git mv docs/open-source/{LICENSE,NOTICE,CONTRIBUTING.md,SECURITY.md} .`,
   with Henrik Stamm's date in `NOTICE` filled in. `NOTICE` is what keeps
   name and icon out.
2. `lib/src/legal/legal_text.dart`: `openSourced = true` (licence page in the
   game and at /lizenzen/).
3. `site/hugo.toml`: `openSource = true` (the landing page section).
4. `README.md`: replace the section "License", add the showcase link.
   `docs/forking.md`: point its `open-source/NOTICE` links at `../NOTICE`.
5. `store/ios/license.txt`, `store/ios/metadata/*/description.txt`,
   `store/ios/metadata/review_information/notes.txt`,
   `store/android/metadata/*/full_description.txt`: drop "all rights reserved"
   and "not open source". Once purchases are on, also "non-commercial".
6. GitHub: description and homepage (`gh repo edit`), topics `flutter`,
   `flame`, `supabase`.

Do not rewrite history: the search for secrets in the tree and the history
(private keys, service role keys, tokens) came back empty, and the publishable
Supabase key and project ref in the repository are meant to be public, guarded
by row level security. gitleaks 8.30 ran on 2026-11-03 over all branches and
the working tree: its only hits are that publishable key (then in
`ios/OnlineWidget/OnlineWidget.swift`, now in `apple/App.xcconfig`) and the
ignored, never committed
`android/key.properties`. No keystore, `.p8`, `.p12` or `.env` file was ever
committed. Run it again right before the switch:
`gitleaks git . --log-opts=--all --redact` and `gitleaks dir . --redact`.
