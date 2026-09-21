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
dart run build_runner build      # regenerates *.g.dart / *.freezed.dart
flutter test
flutter analyze --fatal-infos
dart format .
```

### Firebase configuration (Phase 1)

The app holds only Firebase's *public* client config (§24) and takes it at
build time via `--dart-define`, so nothing project-specific lives in source and
one codebase serves dev/staging/prod. Read the values from the Firebase console
under **Project settings → Your apps → Android app**:

```bash
flutter run \
  --dart-define=FIREBASE_API_KEY=AIza... \
  --dart-define=FIREBASE_APP_ID=1:1234567890:android:abc123 \
  --dart-define=FIREBASE_MESSAGING_SENDER_ID=1234567890 \
  --dart-define=FIREBASE_PROJECT_ID=fitos-dev-3208b \
  --dart-define=GOOGLE_WEB_CLIENT_ID=1234567890-abc.apps.googleusercontent.com \
  --dart-define=API_BASE_URL=http://10.0.2.2:8080
```

Without these the app boots to the splash with a plain message saying so —
never a native crash.

**Google Sign-In needs two things in the Firebase console first:** an Android
app registered with package name `com.example.fitos` and the **SHA-1** of your
debug keystore (`cd android && ./gradlew signingReport`), and Google enabled
under **Authentication → Sign-in method**. `GOOGLE_WEB_CLIENT_ID` is the
*Web client* OAuth id that enabling Google creates — not the Android one.

`API_BASE_URL` defaults to `http://10.0.2.2:8080`, the Android emulator's
alias for the host machine. On a physical device use the host's LAN IP.

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

## Running the drift tests on Windows (Phase 5)

The workout logger's tests open a real SQLite database in memory
(`AppDatabase.inMemory()` → `NativeDatabase.memory()`), so `flutter test`
needs a native SQLite on the machine running it. **CI (Ubuntu) has one and
is authoritative** (owner decision 8.7).

- Windows 10/11 ships `winsqlite3.dll` in `C:\Windows\System32`; the
  `sqlite3` Dart package falls back to it, so on a stock Windows install
  the tests run without any setup.
- If they fail with `Could not load sqlite3` / `Failed to load dynamic
  library`, download the **sqlite-dll-win-x64** zip from
  https://www.sqlite.org/download.html, put `sqlite3.dll` in a folder on
  your `PATH` (or next to `flutter_tester.exe` in
  `<flutter>\bin\cache\artifacts\engine\windows-x64\`), open a new shell
  and rerun. Verify with `where sqlite3.dll`.
- Nothing is skipped silently: a missing library fails the drift tests
  loudly with that message.

Separately, **Windows Smart App Control** (when it is in *Enforce* mode)
can block `flutter_tester.exe` — an unsigned binary — with
`An Application Control policy has blocked this file`. That is a Windows
policy, not a test failure; there is no per-file allow-list. Run the
Flutter suite on CI (push to `main` or a `phase-*` branch) or on a machine
where Smart App Control is off.
