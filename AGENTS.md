# AGENTS.md

Guidance for AI coding agents (and humans) working in this repository.

Jellyflix is a cross-platform [Jellyfin](https://jellyfin.org/) client written
in Flutter/Dart. It targets iOS, Android, macOS, Windows, Linux and Web (the
web build is demo-only and has no playback).

## Project layout

```
lib/
  main.dart            App entry: initializes FlutterDownloader (mobile),
                       DatabaseService (Hive) and media_kit, then runs MyApp.
  navigation/          go_router setup (app_router.dart).
  screens/             Full-page widgets (home, library, detail, player,
                       downloads, login, profile, search, ...).
  components/          Reusable widgets used by screens.
  widgets/             Low-level widgets (input_detector.dart: touch vs.
                       keyboard/D-pad input mode).
  providers/           Riverpod providers that construct and expose services.
  services/            Business logic: Jellyfin API (api_service.dart),
                       auth, Hive database, downloads, playback helpers,
                       connectivity, secure storage, logging.
  models/              Plain data classes; user.dart is a Hive type with a
                       committed generated adapter (user.g.dart).
  l10n/                ARB translation files (app_en.arb is the template).
    generated/         Generated localizations. Git-ignored, created by
                       `flutter pub get` / `flutter gen-l10n`.
test/                  Flutter tests (currently a placeholder).
assets/                Icons and fonts.
android/ ios/ macos/ linux/ windows/ web/
                       Platform runners.
ios/fastlane/          TestFlight release lanes (maintainer CI only).
ios/scripts/           Helper scripts, e.g. personal_build.sh.
docs/                  Developer documentation.
.github/workflows/     ci.yml (PR checks) and deploy.yml (release builds).
```

Key dependencies: `tentacle` (generated Jellyfin API client),
`hooks_riverpod` + `flutter_hooks` (state), `go_router` (navigation),
`media_kit` (playback, from the jellyflix-app fork of media-kit),
`hive` (local encrypted storage), `flutter_downloader` (mobile downloads),
`flutter_secure_storage` (credentials and the Hive key).

## Build, test, analyze

Use the Flutter **stable** channel; CI uses `subosito/flutter-action` with
`channel: stable`.

```bash
flutter pub get          # also generates lib/l10n/generated
flutter analyze          # must be clean; CI runs it on every PR to main
flutter test             # CI runs flutter test --coverage
flutter run              # pick a device or simulator
```

Platform builds: `flutter build ios|apk|appbundle|macos|windows|linux|web`.
iOS and macOS builds need macOS with Xcode and CocoaPods
(`cd ios && pod install`). Linux needs the extra system packages listed in
README.md (libmpv, libsecret, libjsoncpp).

If you change a Hive model (`@HiveType`/`@HiveField`), regenerate the adapter:

```bash
dart run build_runner build --delete-conflicting-outputs
```

To build a signed iOS app for your own device under your own bundle ID, see
[docs/ios-personal-build.md](docs/ios-personal-build.md).

## Conventions

- **Lints:** `package:flutter_lints/flutter.yaml` via `analysis_options.yaml`.
  Fix analyzer findings instead of adding ignores.
- **Imports:** use package imports (`package:jellyflix/...`), not relative ones.
- **State:** Riverpod providers are written by hand
  (`final fooProvider = Provider((ref) => ...)`), not with `@riverpod` code
  generation, even though `riverpod_generator` is a dev dependency. Follow the
  existing style. Widgets that need providers extend `HookConsumerWidget`,
  `ConsumerWidget` or `ConsumerStatefulWidget`.
- **Layering:** screens and components call providers; providers construct
  services; services talk to the Jellyfin API (`tentacle`), Hive or the
  platform. Keep API calls out of widgets.
- **Strings:** every user-visible string goes through `AppLocalizations`
  (`AppLocalizations.of(context)!.someKey`). Add new keys to
  `lib/l10n/app_en.arb` only. The other `app_*.arb` files are managed by
  Weblate (translate.codeberg.org), so do not edit them by hand.
- **Platform checks:** use `universal_platform` / `universal_io` so code still
  compiles for web.
- **Commits:** use Conventional Commit prefixes (`feat:`, `fix(scope):`,
  `chore:`, `docs:`, `ci:`). GitVersion derives the release version from them
  (`feat` bumps minor, `+semver: major` bumps major), so the prefix matters.
- **Branches:** PRs target `main`. `preview` and `stable` are release branches
  that trigger `deploy.yml`; never push to them from a PR.

## Gotchas

- **Do not commit signing changes.** `ios/Runner.xcodeproj/project.pbxproj`
  and `macos/Runner.xcodeproj/project.pbxproj` contain the literal
  placeholder `SENSITIVE_REPLACE_ME` for the team ID, and
  `ios/Runner/ExportOptions.plist` contains `TEAM_ID`. CI replaces them with
  `sed`. The iOS Runner target uses manual signing with the fastlane match
  profile `match AppStore com.ambark.jellyflix`. Keep the bundle ID
  `com.ambark.jellyflix` (also the Android `applicationId`), the placeholders
  and the manual signing settings as they are.
- **Version placeholder.** `pubspec.yaml` has `version: 00.00.00+0`, which CI
  rewrites at release time. Do not bump it in PRs.
- **ENCRYPTION_KEY.** `DatabaseService` falls back to
  `String.fromEnvironment('ENCRYPTION_KEY')` when secure storage is
  unavailable. Release builds pass it with `--dart-define`. Never hard-code a
  real key.
- **Generated l10n is git-ignored.** If imports of
  `package:jellyflix/l10n/generated/app_localizations.dart` fail, run
  `flutter pub get` (or `flutter gen-l10n`).
- **Git dependencies.** `media_kit` and friends come from the
  `jellyflix-app/media-kit` fork and are also pinned in `dependency_overrides`.
  Change both places together.
- **CocoaPods needs a UTF-8 locale.** `pod install` can crash under a non-UTF-8
  shell. Run it with `LANG=en_US.UTF-8`.
- **Flutter debug builds do not launch from the iOS home screen.** Since
  iOS 14, a debug build only runs while a debugger (`flutter run` or Xcode) is
  attached. Install release or profile builds for standalone testing.
- **Tests are minimal.** `test/widget_test.dart` is a placeholder, so a passing
  `flutter test` says little. Add focused unit tests for new logic where you
  can, and run `flutter analyze` before every commit.
