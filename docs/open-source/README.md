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
| Lukas Klingsbo's code, about 1,400 lines still in the tree. The upstream repository has no licence, so nothing here may be relicensed without him. | Mail sent, **no consent on record yet**. |
| Licence | Proposed: MIT for code, name and icon kept (`NOTICE`). The owner's call. |
| `tool/werkbank/`, a copy of a private repository | The owner decides: covered by MIT as well, or excluded in `NOTICE`. |
| Horizont (git dependency) | Public, but GitHub detects its licence as "other"; check that it carries a plain MIT file, or forks cannot rely on it. |

## The switch, in one change

1. `git mv docs/open-source/{LICENSE,NOTICE,CONTRIBUTING.md,SECURITY.md} .`,
   with the dates in `NOTICE` filled in. `NOTICE` is what keeps name and icon out.
2. `lib/src/legal/legal_text.dart`: `openSourced = true` (licence page in the
   game and at /lizenzen/).
3. `site/hugo.toml`: `openSource = true` (the landing page section).
4. `README.md`: replace the section "License", add the showcase link.
5. `store/ios/license.txt`, `store/ios/metadata/*/description.txt`,
   `store/ios/metadata/review_information/notes.txt`,
   `store/android/metadata/*/full_description.txt`: drop "all rights reserved"
   and "not open source". Once purchases are on, also "non-commercial".
6. `CLAUDE.md` and `.claude/skills/db-migration`: replace the absolute
   `/Users/...` paths.
7. GitHub: description and homepage (`gh repo edit`), topics `flutter`,
   `flame`, `supabase`.

Do not rewrite history: the search for secrets in the tree and the history
(private keys, service role keys, tokens) came back empty, and the publishable
Supabase key and project ref in the repository are meant to be public, guarded
by row level security. A dedicated scanner such as gitleaks has not run yet;
run one before the switch.
