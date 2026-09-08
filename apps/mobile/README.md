# apps/mobile — FitOS Flutter client

Part of the FitOS monorepo. See the root [README](../../README.md) and the
authoritative [spec](../../docs/MASTER-SPEC.md).

This directory is **not** a pnpm workspace member — Flutter has its own
resolver.

## The rule that governs this package

> No fitness business logic in Dart (§7.3, §30).

`domain/` holds entities and repository interfaces only. Permitted client-side
computation is exhaustively: unit and format display, in-progress session set
counts *for display only*, sorting/filtering already-fetched lists, and form
validation that mirrors server-side validation.

If you are about to write a calorie or progression formula here, add an API
endpoint instead.

## Running

```bash
flutter pub get
flutter test
flutter analyze --fatal-infos
dart format .
flutter run
```

`flutter run` needs a target. This repo ships `android/` and `ios/` only —
there is deliberately no `web/` or desktop target, because §35 puts a web app
out of scope. To get a local run target on a machine with no Android SDK:

```bash
flutter create --project-name fitos --platforms=web .   # temporary
flutter run -d chrome
rm -rf web build                                        # then remove it again
```

## Known environment traps

- **Do not install the Flutter SDK to a path containing a space.** A path like
  `D:\New folder\flutter` breaks the native-assets hook runner: it shells out
  unquoted and fails with `'D:\New' is not recognized`. This blocks
  `flutter test`, `flutter run` and `build_runner`. `objective_c` (pulled in
  transitively by `path_provider_foundation`) requires the native-assets
  feature, so it cannot be disabled as a workaround.
- `custom_lint` and `riverpod_lint` are deliberately absent. See the TODO in
  `pubspec.yaml`; they return in Phase 1.
