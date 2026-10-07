# Workshop slides

The deck for "Building a Real-Time Multiplayer Tank Game with Flame and
Supabase", built with [flutter_deck](https://pub.dev/packages/flutter_deck).

```sh
flutter run -d chrome
flutter run -d macos
```

The presenter view and the deck's shared navigation state only work on the web
target, which is the one to use when presenting. The macOS target runs the same
deck as a standalone window.

Arrow keys navigate, the period key toggles the navigation drawer, and the
presenter view (with speaker notes) opens from the deck controls.

## Keeping code snippets in sync

Slide code snippets are string constants inside each slide file. Every
`CodePane` labels its snippet with the true source path in the game package
(for example `packages/game/lib/src/game/components/remote_ship.dart`). When
game code changes, search the slides for that path and update the snippet to
match the source.

## Fonts

Space Grotesk, Inter, and JetBrains Mono are bundled in `assets/google_fonts/`
instead of being downloaded on first paint, so the deck renders correctly with
no network. `GoogleFonts.config.allowRuntimeFetching` is off, which means a
missing or misnamed file fails loudly rather than silently falling back.

Using a new family or weight anywhere in `lib/` means adding the matching file.
The name must be `<Family>-<Variant>.ttf`, for example `Inter-SemiBold.ttf`, and
the bytes must come from the same Google Fonts release the `google_fonts`
package pins. `test/font_bundling_test.dart` scans `lib/` for every
`GoogleFonts` call and fails when a variant is missing, so run `flutter test`
after touching type.
