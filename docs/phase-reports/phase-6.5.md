## PHASE 6.5 — Health Connect + Home/TODAY redesign — IMPLEMENTED, AWAITING MANUAL ACCEPTANCE

**Status: NOT complete.** Implementation is present, automated tests pass, the APK builds with the Health Connect channel compiled, but the 27-point manual acceptance (Part K) has **not** been performed — it needs a device with Health Connect and a data source, signed in with the owner's Firebase build. See "Manual acceptance" below for exactly what to do.

**Date** 2026-09-22 · **Branch** `phase-6.5` (not merged) · **Commits** `c1d69c2` foundation · `c2873d7` permissions / models / Health Data screen · `8e84fa8` engine · `3688ac6` Home redesign · `a74117a` floating bar · `55ef78d` `3916799` `1e49c28` `e8d1c20` fixes found by CI (one real: a circular invalidate) · plus this report
**CI on `e8d1c20`:** ci-core ✓ (456 + 33) · ci-api ✓ (165) · ci-mobile ✓ (**238 tests**, analyze `--fatal-infos`, custom_lint, format, APK)
**Decisions** D1–D6 (owner, 2026-09-22) — [ADR-008](../decisions/ADR-008-health-connect-provider.md) (Health Connect), [ADR-009](../decisions/ADR-009-home-context-engine.md) (device-side engine + Home). **Spec** updated: §7 row, §18, §30 footnote, §31 Phase 6.5, §34, §38.
**Boundaries held (Part M):** no automatic workout / deload / nutrition changes; no medical advice; no readiness score; no LLM; no background reads; no Google Fit, Samsung SDK or wearable code; no Health Connect writes; no backend persistence of health data; Phase 13 untouched.

IMPLEMENTED
  - **Health Connect foundation (Part A)** — `androidx.health.connect:connect-client:1.1.0`
    (stable, developer.android.com 8 Oct 2025); manifest: the ten `READ_*` permissions
    (steps, distance, active + total calories, exercise, sleep, resting HR, weight, body fat,
    BMR), `<queries>` for `com.google.android.apps.healthdata`, `HealthPermissionsRationaleActivity`
    (+ Android 14 `VIEW_PERMISSION_USAGE` alias) explaining why FITOS reads and that it never
    writes / uploads. `HealthConnectChannel.kt` on `fitos/health_connect`: `sdkStatus`
    (`getSdkStatus` → available / updateRequired / unavailable), `grantedPermissions` (re-read
    every call), `requestPermissions` (the `PermissionController` contract via
    `startActivityForResult`, answer = what is granted afterwards), `aggregate` (`COUNT_TOTAL`,
    `DISTANCE_TOTAL`, `ACTIVE_CALORIES_TOTAL`, `ENERGY_TOTAL`, `SLEEP_DURATION_TOTAL`, `BPM_AVG`
    over explicit instants; data origins returned), `latest` (newest record of weight / body
    fat / BMR / resting HR in a range, with time and source), `exerciseSessions`, `openSettings`
    (`ACTION_HEALTH_CONNECT_SETTINGS`). `SecurityException` → `permissionDenied`; nothing logged.
    `minSdk` 24 → 26 (the client's floor).
  - **Provider abstraction + models** — `HealthDataProvider` (connection, requestPermissions,
    snapshot, openSettings); `HealthConnectProvider` (Android) and `UnsupportedHealthProvider`;
    `HealthMetric {kind, availability, value, unit, start, end, sources, updatedAt}`,
    `HealthSnapshot` (date, timezone, nine metrics, exercise sessions + their availability,
    week steps / sleep per local day, fetchedAt, fromCache), `HealthConnectionState {sdk,
    granted}` with `categoryGrant`. Availability: `available · not_connected ·
    permission_denied · no_data · temporarily_unavailable · unsupported` — never a fake 0.
  - **Queries (Part "data query rules")** — cumulative metrics via `aggregate()` only, so Health
    Connect de-duplicates across sources; ranges built with `package:timezone` in
    `users.timezone`: local day `[00:00, 24:00)`, last night `[D−1 18:00, D 12:00)`, Monday-first
    local week (seven single-day aggregates for steps and sleep); point metrics = latest record in
    30 days with the record's own time. Resting HR: today's average, else the latest reading.
  - **Permissions + connection (Part G)** — `/profile/health` Health Data screen: why FITOS reads,
    Connected / Not connected with "Last read n min ago" (or the cached-reading line), Activity /
    Recovery / Body with Allowed / Partly allowed / Not allowed and a per-category **Allow**,
    **Connect** (all three), **Manage permissions** (Health Connect settings), **Refresh**;
    honest `unavailable` and `updateRequired` states; the daily step goal (D4). Reached from
    Profile and from Home's "Connect Health data" lines / suggestion.
  - **Refresh / cache** — `healthConnectionProvider` + `healthSnapshotProvider`
    (`AsyncNotifier`s); `refreshAll()` re-reads grants then the snapshot on: first Home show, app
    resume (`HealthRefreshCoordinator`, no polling), after a permission request, pull-to-refresh,
    the Refresh button. Last valued snapshot for today cached in drift `cached_json`
    (`health:<date>`), read back **only** on `temporarily_unavailable` and marked `fromCache` (UI
    says so); "not connected / denied / unsupported" are shown as such.
  - **Home context + engine (Part D)** — `HomeContext` (date, local hour, today, active session,
    completed session with records, targets, nutrition = `notLogged` until Phase 8, health
    snapshot, connection, step goal, volume, week counts); `HomeSuggestionEngine` — twelve rules,
    §16.1 bands, stable ties, every suggestion `{id, type, priority, title, subtitle, reason,
    action, surface, metadata}`, no score shown: deload 95 · resume 92 · start 90 · protein 88 ·
    calories 75 · done 70 · neglect 68 · recover (sleep < 6 h, D5) 65 · rest day 60 · PR 50 ·
    volume at MRV 45 · move (< ½ goal after 15:00 or < goal after 19:00, D4) 40 · connect 35.
    Carousel = first four primary; More for you = the rest.
  - **Home (Part B/C/E)** — header (greeting by local hour, "Tuesday · 22 September", profile),
    "Your next move" carousel (eyebrow TRAIN / MOVE / EAT / RECOVER / …, title, one line, one
    action, dots), Today grid (Steps "6,842 · 86% of 8,000" / Active calories / Food "Not logged
    yet · Target …" / Workout Ready · In progress · Completed · Rest), Recovery (Sleep "6h 12m" ·
    Resting HR with "Today / Yesterday / Last recorded 18 Sep"), Body (Weight · Body fat · BMR,
    only when granted), This week (Training n / planned, Movement n / 7, Sleep n / 7, dots),
    "Training volume →", More for you rows, freshness footer; pull-to-refresh. Editorial
    hairline layout; sign-out moved to Profile.
  - **Floating bottom bar (Part F)** — paper at 88 % over a 12 px blur, hairline, restrained
    shadow, medium radius, 60 px content, 12 / 10 px insets, `extendBody`; same five
    destinations, same `goBranch` and back behaviour; full-height touch targets.
  - **Privacy (Part I)** — no contract, table or route changed; nothing health-related goes to
    the API or Gemini; no analytics events exist for it; the channel logs no values; sign-out
    wipes the local DB including the health cache.

FILES
  - created: `apps/mobile/android/app/src/main/kotlin/com/example/fitos/{HealthConnectChannel,HealthPermissionsRationaleActivity}.kt`;
    `apps/mobile/lib/features/health/{domain/entities/health.dart (+gen),domain/health_data_provider.dart,data/{health_connect_channel,health_connect_provider}.dart,presentation/controllers/health_providers.dart,presentation/screens/health_data_screen.dart}`;
    `apps/mobile/lib/features/home/{domain/{home_context,home_suggestion_engine}.dart,presentation/controllers/home_providers.dart,presentation/screens/home_screen.dart,presentation/widgets/{home_sections,suggestion_carousel}.dart}`;
    `apps/mobile/test/support/{fake_health_channel,fake_health_provider}.dart`,
    `apps/mobile/test/features/health/health_connect_provider_test.dart`,
    `apps/mobile/test/features/home/{home_suggestion_engine,home_screen}_test.dart`;
    `docs/decisions/ADR-008-health-connect-provider.md`, `docs/decisions/ADR-009-home-context-engine.md`
  - modified: `apps/mobile/android/app/{build.gradle.kts,src/main/AndroidManifest.xml,src/main/kotlin/com/example/fitos/MainActivity.kt}`;
    `apps/mobile/lib/{app.dart,core/routing/{router,app_shell}.dart,features/profile/presentation/screens/profile_screen.dart}`;
    `apps/mobile/test/{widget_test.dart,core/routing/app_shell_test.dart}`; `docs/MASTER-SPEC.md`
  - deleted: `apps/mobile/lib/features/today/presentation/screens/today_placeholder_screen.dart`

DATABASE
  - none. Health data is device-only (drift `cached_json`, existing table).

APIS
  - none.

TESTS
  - executed: `pnpm --filter @fitos/core test` — **456 passed**; `@fitos/contracts` — **33 passed**;
    `@fitos/api` (PG 18) — **165 passed**; typecheck / lint clean; Docker `api` boots (`/health` 200,
    `/v1/training/today` 401).
  - executed (CI ubuntu; local `flutter test` still blocked by Smart App Control): `flutter test` —
    **238 passed** (+45: provider ×18 — every metric's unit and range, Kolkata + Los Angeles day
    boundaries, night window, week Monday-first, unsupported / not connected / partial / no data /
    revoked / temporarily unavailable, **aggregate never summed across sources**, cache round trip;
    engine ×15 — every rule, protein XOR calories, deload suppresses rest day, movement 15:00 /
    19:00 thresholds, recovery 5h59 vs 6h00, connect only when present-but-unconnected,
    deterministic order + surfaces, no suggestions; Home ×10 — no Health Connect, not connected →
    Health Data + grant per category, steps only, all permissions with freshness + week rows, food
    not logged, sleep no data, start → in progress, completed → done → summary, dots + greeting +
    profile, **revoked outside FITOS → Refresh → old value gone**; shell ×2 — floating bar geometry /
    translucency / `extendBody`, tab switching keeps state). All Phase 0–6 tests unchanged in
    substance (four assertions that identified Home by the placeholder text now identify it by
    type; sign-out moves to Profile).
  - executed: `dart analyze --fatal-infos`, `custom_lint`, `dart format --set-exit-if-changed` — clean.
  - executed: `flutter build apk --debug` — built; **`HealthConnectChannel.kt` compiles** against
    `connect-client:1.1.0` (the manifest merger forced `minSdk` 26).
  - executed (emulator `sdk gphone16k`, API 37, Health Connect platform module present): APK
    installs and launches; without the owner's Firebase `--dart-define`s the build stops at the
    "Firebase is not configured" screen, so no signed-in Home / Health Connect flow was exercised
    by the author. **Manual acceptance: not performed.**
  - coverage: not measured — §18 gate.

KNOWN ISSUES
  - **Manual acceptance (Part K, 27 points): not executed.** Blocks completion.
  - No name in the profile → the greeting is "Good morning" without a name (nothing invented).
  - Nutrition is `notLogged` until Phase 8: the Food block shows the target only; the EAT card and
    protein / calorie rules cannot fire; "Log food" opens the Nutrition placeholder.
  - The Body section is hidden until a body permission is granted (the one "Connect Health data"
    line lives in Recovery, to avoid three CTAs).
  - Resting HR has no baseline: shown, never judged. Sleep < 6 h is an advisory line (D5), not a score.
  - Health Connect serves 30 days before the grant; "Last recorded" for a scale reading older than
    that reads "No data yet" until a new reading lands.
  - `latest()` for BMR: most devices never write `BasalMetabolicRateRecord`; the block will read
    "No data yet" for most users. The profile's own BMR stays in Profile → targets.
  - Emulator API 37 has no data source; the author could not seed Health Connect data.
  - `applicationId` is still `com.example.fitos`; Play Console health declaration + privacy policy
    URL are documented (ADR-008), not done.

DEVIATIONS FROM SPEC
  - §7: `health` package → in-app platform channel over the Health Connect client (D1, ADR-008).
  - §18: Health Connect pulled from V2 into Phase 6.5 as read-only context (no HRV, no score).
  - §30: device-side suggestion **ordering** in `lib/features/home/domain` over server-computed
    numbers and device-only health data (D3, ADR-009). Fitness arithmetic still server-side.
  - §31: Phase 6.5 inserted between 6 and 7 (owner).
  - `minSdk` 24 → 26.

NEXT PHASE
  - Owner runs manual acceptance below; fixes if any; then Phase 6.5 can be marked complete and
    merged. Phase 7 not started.

---

### Manual acceptance (Part K) — what you need to do

**Build & install** (your defines; the Kotlin channel is already in the APK):
```
cd apps/mobile
flutter build apk --debug \
  --dart-define=FIREBASE_API_KEY=… --dart-define=FIREBASE_APP_ID=… \
  --dart-define=FIREBASE_MESSAGING_SENDER_ID=… --dart-define=FIREBASE_PROJECT_ID=… \
  --dart-define=GOOGLE_WEB_CLIENT_ID=… --dart-define=API_BASE_URL=http://10.0.2.2:8080
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```
Device needs: Android 14+ (Health Connect built in) or Android 9–13 with the Health Connect app;
a step source (the phone's own step counter through Samsung Health / Google Fit / Health Connect
Toolbox) and, for 5–6, a sleep and a weight source. `docker compose up --build api` running.

| # | Do | Expect |
|---|---|---|
| 1 | Open FITOS signed in, Health Connect untouched | Home loads: greeting + date, "Your next move" (your session), Today grid with Steps "Connect Health data", Food "Not logged yet · Target …", Recovery "Connect Health data to see recovery metrics." |
| 2 | Home → More for you → "Connect Health data" (or tap Steps) | Health Data screen: Not connected, three categories "Not allowed", Connect / Manage / Refresh |
| 3 | Connect → in the Health Connect sheet allow **Steps only** | Screen: Connected, Activity "Partly allowed"; back on Home: Steps shows a number and "n% of 8,000"; Active calories "Not allowed"; recovery still asks |
| 4 | Allow activity (Health Data → "Allow activity") | Steps / Active calories (+ "n kcal in total") / distance populate where the source has them; "No data yet" where it does not |
| 5 | Allow recovery | Recovery grid: Sleep "6h 12m" (last night), Resting HR "62 bpm · Today/Yesterday/Last recorded …" |
| 6 | Allow body | Body section appears: Weight "60.5 kg · Last recorded 18 Sep", Body fat, BMR (or "No data yet") |
| 7 | In Health Connect settings revoke Steps → return to FITOS | Home refreshes on resume: Steps "Not allowed", the old number is gone; Health Data shows Activity "Partly allowed" |
| 8 | A category allowed, no data in the source | "No data yet", never 0 |
| 9 | Two step sources (phone + watch / two apps) | Steps equals Health Connect's own total, not the sum |
| 10 | Change a permission in Health Connect, come back | Data changes without restarting (resume refresh) |
| 11 | Start a workout from the carousel | Card becomes "Legs is in progress · n sets logged" with Resume; Workout block "In progress" |
| 12 | Complete it | "Legs done · n sets · kg moved" card → See the summary; Workout "Completed"; PR card if a record |
| 13–14 | Food | "Not logged yet" with the target (Phase 8 not built) — never "0 kcal" |
| 15 | Steps well below goal after 15:00 / 19:00 | MOVE card "You're n steps from your goal · An easy m-minute walk gets you there" |
| 16 | Protein remaining | Cannot appear until Phase 8 (documented) |
| 17 | Sleep < 6 h last night | RECOVER card "Sleep was 5h 45m · Keep today's session controlled" |
| 18 | Deload offered (see Phase 6 checklist step 8) | DELOAD card first; "Open your plan"; nothing applied until Accept on the plan |
| 19 | "Training volume →" | Opens the Phase 6 volume screen |
| 20 | Body freshness | "Today" / "Yesterday" / "Last recorded d Mon" matches the reading's date |
| 21 | Kill and reopen | Health values return at once (cache), then refresh; footer "Health data read just now" |
| 22 | Airplane mode | Home renders from cached today; health blocks unaffected or "Unavailable right now"; no crash |
| 23 | Bottom bar | Floats, translucent over content on all five tabs; each tab switches; content not hidden behind it |
| 24 | Back | Deeper screen pops; non-home tab root → Home; Home root → leaves |
| 25 | ~360 px device | No overflow (carousel titles ellipsise at two lines) |
| 26 | Wide phone | Spacing intact |
| 27 | Accessibility | Every block has a label + text; status never colour-only; targets ≥ 48 px |
