# Running your own copy

This page is for anyone who wants to run Panzergefecht under their own name
and backend: on a laptop against a local Supabase stack, as a web game on
their own domain, or as apps under their own ids. It lists every place
where the build is tied to the original project, and what to put there
instead. The game has no server of its own, so a copy needs exactly two
things to run: a Supabase project and somewhere to host static files.

The code licence does not cover the name "Panzergefecht", the app icon or
the store listings (see [`NOTICE`](open-source/NOTICE)). A fork that is
published anywhere uses its own name, icon and bundle id, and its own
imprint and privacy notice.

Contents:

1. [Just run it locally](#1-just-run-it-locally)
2. [Your own Supabase project](#2-your-own-supabase-project)
3. [The web game on your own domain](#3-the-web-game-on-your-own-domain)
4. [Apps under your own ids and signing](#4-apps-under-your-own-ids-and-signing)
5. [Checklist: what to change, where](#5-checklist-what-to-change-where)

## 1. Just run it locally

You need Flutter 3.47 or newer, the
[Supabase CLI](https://supabase.com/docs/guides/local-development) 2.x and
Docker. The local stack reads [`supabase/config.toml`](../supabase/config.toml)
(API on port 54621, anonymous sign-ins and manual linking on) and applies
every migration in [`supabase/migrations/`](../supabase/migrations) on start.

```sh
flutter pub get
supabase start   # prints the API URL and the publishable key
flutter run -d chrome \
  --dart-define=SUPABASE_URL=http://127.0.0.1:54621 \
  --dart-define=SUPABASE_KEY=<publishable key from supabase start> \
  --dart-define=ROOM=dev
```

Start it twice for two players: instances with the same `ROOM` meet in the
same room. The build flags live in [`lib/src/app/env.dart`](../lib/src/app/env.dart):

| Define | Default | What it does |
| --- | --- | --- |
| `SUPABASE_URL`, `SUPABASE_KEY` | the live project | Backend the game talks to |
| `ROOM` | empty (a fresh private room) | Fixed room, so two local instances meet |
| `ACCOUNTS` | `false` | Sign-in by e-mail (and OAuth) to keep a guest account |
| `PURCHASES` | `false` | The two packs on the account page ([purchases.md](purchases.md)) |
| `MAX_PILOTS` | `4` | Pilots a room holds |
| `REALTIME_BUDGET` | `400` | Realtime messages a second the whole project may use |
| `WEB_URL` | `https://panzergefecht.de/play/` | Where room links point |

**Always pass the two Supabase defines.** Without them, or with a value that
is not a valid address or key, the build falls back to the live game's
project, and every message you send counts against the budget all players
share. With no backend at all the game still starts, and single player
works offline (see [Running without the server](netcode.md#running-without-the-server)).

The integration tests tagged `supabase` run against this local stack;
`tool/release.sh verify --quick` leaves them out. More on tests and checks
in [development.md](development.md).

Local accounts: build with `--dart-define=ACCOUNTS=true`. The local stack
sends no real mail; set `enabled = true` under `[local_smtp]` in
`supabase/config.toml` to read the sign-in mails in the web interface on
port 54624.

## 2. Your own Supabase project

1. Create a project at [supabase.com](https://supabase.com). The free plan
   works, but carries only one small room at a time: build with
   `MAX_PILOTS=2` and `REALTIME_BUDGET=80`. The numbers and why are in
   [Realtime limits](netcode.md#realtime-limits) and
   [Rooms and room sizes](netcode.md#rooms-and-room-sizes).
2. Apply the schema. This creates the tables, row level security, the
   `record_round` and `claim_load` functions and the views:

   ```sh
   supabase login
   supabase link --project-ref <your-project-ref>
   supabase db push
   ```

3. In the dashboard, under Authentication, Sign In / Providers, switch on
   anonymous sign-ins. Every player starts as an anonymous guest; without
   it the game cannot reach the server and plays offline only.
4. Point the builds at it: `SUPABASE_URL=https://<ref>.supabase.co` and
   `SUPABASE_KEY` set to the project's publishable key (Project Settings,
   API Keys). The key is meant to be public; row level security decides
   what it reaches.

You do not need to regenerate the typed models
(`lib/src/db/supabase_schema.g.dart`) unless you change the schema; then
follow [Regenerating the typed database models](development.md#regenerating-the-typed-database-models).

For accounts (`ACCOUNTS=true`) the project also needs the settings listed
under [Deploying](development.md#deploying): the game's URL as Site URL and
redirect URL, e-mail sign-in and "Allow manual linking", and an SMTP server
of your own. The mail templates in [`supabase/templates/`](../supabase/templates)
and their subjects in `supabase/config.toml` carry the Panzergefecht name;
reword them before pasting them into the dashboard. OAuth logins (GitHub,
Google) are optional, and the game only shows those the project has
switched on.

The edge function [`supabase/functions/verify-purchase`](../supabase/functions/verify-purchase)
is only needed with `PURCHASES=true`. It checks store receipts for one
bundle id, set in the file, and needs store API keys as secrets. Leave it
out unless you sell the packs yourself.

## 3. The web game on your own domain

The [`pages`](../.github/workflows/pages.yaml) workflow runs the checks,
builds the landing page (Hugo, [`site/`](../site)) into the root of the
site and the game into `play/` below it, writes the imprint, privacy and
licence pages, and deploys to GitHub Pages. It reads its settings from
repository variables, so a fork needs no code change to point the web game
at its own backend:

1. In the repository settings, set Pages to the "GitHub Actions" source.
2. Under Settings, Secrets and variables, Actions, Variables, add
   `SUPABASE_URL` and `SUPABASE_KEY`, and as needed `ACCOUNTS` (`true`),
   `MAX_PILOTS` and `REALTIME_BUDGET`.
3. Optionally set a custom domain in the Pages settings. The repository
   keeps no `CNAME` file; the workflow takes base path and address from
   `actions/configure-pages`, so the build also works at
   `<owner>.github.io/<repo>/`. `WEB_URL` is set from that address too.
4. Push to `main`.

Universal links need the domain root: Apple reads
`/.well-known/apple-app-site-association`, which `site/hugo.toml` mounts
from [`store/ios/apple-app-site-association`](../store/ios/apple-app-site-association).
On a `github.io` project page that path is not the root, so room links open
the browser game, not the app. A custom domain fixes that.

What on the site belongs to the original and must change:

| What | Where |
| --- | --- |
| Imprint (owner, address, mail), privacy notice, licence terms | [`lib/src/legal/legal_text.dart`](../lib/src/legal/legal_text.dart), written as pages by [`tool/legal_pages.dart`](../tool/legal_pages.dart) and shown in the game |
| Support mail, beta links, store links, `openSource` switch | `params` in [`site/hugo.toml`](../site/hugo.toml) |
| Base URL for `hugo server` | `baseURL` in `site/hugo.toml` (the workflow overrides it) |
| Landing page texts, sender line | [`site/content/`](../site/content), [`site/i18n/`](../site/i18n) |
| Link to the owner's other sites | [`site/layouts/baseof.html`](../site/layouts/baseof.html) |
| Store texts and screenshots the page shows | `store/ios/` (mounted by `site/hugo.toml`) |
| Page title, description, web app name and icons | [`web/index.html`](../web/index.html), [`web/manifest.json`](../web/manifest.json), [`web/icons/`](../web/icons) |

The imprint and privacy notice are the owner's legal statements under
German law. Never publish a fork with them: replace `_owner`, `_mail` and
the texts with your own.

Horizont, the design system, comes as a public git dependency pinned to a
tag: the Flutter package in [`pubspec.yaml`](../pubspec.yaml) and the Hugo
module in [`site/go.mod`](../site/go.mod). A fork can keep it; the game reads
its colours from the `panzergefecht` product slot (`lib/src/ui/theme.dart`).

`params.maintenance` in `site/hugo.toml` replaces every page, the game
included, with a maintenance page; it is meant for moves such as a domain
change.

## 4. Apps under your own ids and signing

The apps are built locally, never in CI
([development.md](development.md#release-scripts)). The release scripts
(`tool/archive_ios.sh`, `tool/archive_apple.sh`, `tool/release_android.sh`)
take `SUPABASE_URL`, `SUPABASE_KEY`, `WEB_URL`, `MAX_PILOTS`,
`REALTIME_BUDGET` and `PURCHASES` from the environment, the same names as
the repository variables of the web build
([`tool/release_env.sh`](../tool/release_env.sh)), and check that the build
carries that Supabase address:

```sh
SUPABASE_URL=https://<ref>.supabase.co SUPABASE_KEY=<publishable key> \
  tool/release.sh android phone
```

Still change the defaults in `lib/src/app/env.dart` (`defaultSupabaseUrl`,
`defaultSupabaseKey`, `WEB_URL`, `MAX_PILOTS`, `REALTIME_BUDGET`), so no
build, debug runs included, can reach the original project by accident.

The native Apple code cannot read Dart defines. The home screen widget, the
iMessage app and the shared app group take their values from
[`apple/App.xcconfig`](../apple/App.xcconfig) instead: the Supabase address
and key, the browser game's address, the room size, the URL scheme, the app
group and the domain of universal links. Its first four mirror the defaults
in `env.dart`, and
[`test/app/apple_config_test.dart`](../test/app/apple_config_test.dart)
fails when the two drift apart, so change them together.

### Name, ids and links

Pick your own reverse-domain id (`com.example.tanks` below) and replace
`de.regetskcob.wargame` everywhere:

| Platform | Where |
| --- | --- |
| iOS app, widget, iMessage extension | `PRODUCT_BUNDLE_IDENTIFIER` in `ios/Runner.xcodeproj/project.pbxproj` (`.OnlineWidget`, `.MessagesExtension`, `.RunnerTests` as suffixes), `CFBundleURLName` in `ios/Runner/Info.plist` |
| Apple TV | `tvos/Runner.xcodeproj/project.pbxproj` |
| Mac | `macos/Runner/Configs/AppInfo.xcconfig`, tests in `macos/Runner.xcodeproj/project.pbxproj` |
| Apple Watch | `watchos/Runner.xcodeproj/project.pbxproj` (`<id>.watchkitapp`; the host app, `de.regetskcob.game`, is only the container flutter-watchos builds the watch app in and never ships), `WKCompanionAppBundleIdentifier` in `watchos/Runner/Info.plist` |
| Android phone, TV and Wear OS | `namespace` and `applicationId` in `android/app/build.gradle.kts`, `namespace` in `android/wear/build.gradle.kts`, the Kotlin package in `android/app/src/main/kotlin/de/regetskcob/wargame/` |
| In-app products | `storeId` in `lib/src/store/product.dart`, `bundle` in `supabase/functions/verify-purchase/index.ts` |
| Release tools | `ios/fastlane/Appfile`, `android/fastlane/Appfile`, `bundle` in `tool/store_shots.sh` |

The iOS app and the iMessage extension share an app group for the round
result, `APP_GROUP` in `apple/App.xcconfig`; the entitlements and
`ios/Shared/ChatResult.swift` read it from there.

Universal links: `APP_LINK_DOMAIN` in `apple/App.xcconfig` is the domain the
iOS and Mac entitlements claim (`ios/Runner/Runner.entitlements`,
`macos/Runner/DebugProfile.entitlements`, `macos/Runner/Release.entitlements`);
the matching `appIDs` (team prefix and bundle id) are in
`store/ios/apple-app-site-association`. Point both at your domain. The
entitlements also list the original's old domain `www.regetskcob.de`: delete
that line. Without a domain of your own, remove the associated domains
entitlement. The iMessage extension opens the app through its URL scheme,
`APP_URL_SCHEME` (`panzergefecht://`); rename it if your app is installed
next to the original.

The display name is in `CFBundleDisplayName`/`CFBundleName` of the
`Info.plist` files (`ios/Runner`, `tvos/Runner`, `watchos/Runner`,
`watchos/HostApp`), `PRODUCT_NAME` in `macos/Runner/Configs/AppInfo.xcconfig`,
`android:label` in `android/app/src/main/AndroidManifest.xml`, and in the
game's texts (`lib/src/l10n/l10n.dart` and the widgets that name the game;
`git grep Panzergefecht lib` finds them). The icons come from Horizont;
[`tool/store/horizont_icons.py`](../tool/store/horizont_icons.py) lists every
icon folder of every platform. Replace those images with your own.

### Signing

Apple: [`apple/Signing.xcconfig`](../apple/Signing.xcconfig) sets the team
for the iOS and Mac projects. Override it in `apple/Signing.local.xcconfig`
(ignored by git) instead of editing it:

```sh
printf 'DEVELOPMENT_TEAM = <your team id>\n' > apple/Signing.local.xcconfig
# or, for an unsigned build:
printf 'DEVELOPMENT_TEAM =\nCODE_SIGN_IDENTITY = -\n' > apple/Signing.local.xcconfig
```

The release scripts and `ios/fastlane/Appfile` read the team from these two
files; the upload (werkbank `upload-apple`) takes it from the signed archive. The Apple TV and
watch projects carry `DEVELOPMENT_TEAM` in their own `project.pbxproj` files
(`tvos/`, `watchos/`) as well, because flutter-tvos reads it there; change it
in both, or `tool/archive_apple.sh` stops at a team that does not match. The
team id also prefixes the `appIDs` in `store/ios/apple-app-site-association`.

Android: release builds sign with the upload key named in
`android/key.properties`, which git ignores. Copy
[`android/key.properties.example`](../android/key.properties.example) and
follow it. Without the file Gradle signs with the debug key, which runs but
Google Play refuses.

### Store listings

`store/ios/` and `store/android/` hold the owner's store texts, screenshots,
licence text and review notes. They are not covered by the code licence;
write your own. Their READMEs describe the layout the tools expect.

## 5. Checklist: what to change, where

| What | Where | Needed for |
| --- | --- | --- |
| Supabase URL and publishable key | repository variables `SUPABASE_URL`, `SUPABASE_KEY` (web); the same names in the environment of the release scripts (apps); `defaultSupabaseUrl`, `defaultSupabaseKey` in `lib/src/app/env.dart` and `APP_SUPABASE_URL`, `APP_SUPABASE_KEY` in `apple/App.xcconfig` (defaults, widget) | every copy |
| Room size and Realtime budget | `MAX_PILOTS`, `REALTIME_BUDGET` (repository variables or defaults in `env.dart`), 2 and 80 on the free plan | free plan |
| Schema | `supabase link` + `supabase db push` | every copy |
| Anonymous sign-ins | Supabase dashboard, Sign In / Providers | every copy |
| Accounts | `ACCOUNTS=true`, Site URL, redirects, SMTP, `supabase/templates/` | optional |
| Purchases | `PURCHASES`, `lib/src/store/product.dart`, `supabase/functions/verify-purchase/` | optional |
| Game address | `WEB_URL` default in `env.dart` and `APP_WEB_URL` in `apple/App.xcconfig` (the web build sets it itself) | own domain |
| Custom domain | GitHub Pages settings | own domain |
| Imprint, privacy, licence page | `lib/src/legal/legal_text.dart` | anything published |
| Landing page | `site/hugo.toml` (`params`), `site/content/`, `site/i18n/`, `site/layouts/baseof.html` | anything published |
| Name and icon | `Info.plist` files, `AndroidManifest.xml`, `macos/Runner/Configs/AppInfo.xcconfig`, `web/`, `lib/src/l10n/l10n.dart`, icon folders from `tool/store/horizont_icons.py` | anything published |
| Bundle ids | see [Name, ids and links](#name-ids-and-links) | apps |
| App group, URL scheme, link domain | `APP_GROUP`, `APP_URL_SCHEME`, `APP_LINK_DOMAIN` in `apple/App.xcconfig`; the old domain in the `*.entitlements` (iOS, Mac); `store/ios/apple-app-site-association` | iOS, Mac |
| Apple team | `apple/Signing.local.xcconfig`; `tvos/` and `watchos/` `project.pbxproj` | Apple apps |
| Local stack name | `project_id` in `supabase/config.toml` (renaming empties the local database) | optional |
| Android upload key | `android/key.properties` | Google Play |
| Store listings | `store/ios/`, `store/android/` | store release |
| Supabase MCP server for Claude Code | `project_ref` in `.mcp.json` | optional |
