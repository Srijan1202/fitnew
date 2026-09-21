# ADR-008 — Health data on Android: Health Connect behind a provider abstraction, read-only, on-device

**Status** ACCEPTED — owner decisions D1–D6 approved 2026-09-22 (Phase 6.5)
**Date** 2026-09-22
**Phase** 6.5
**Affects** MASTER-SPEC.md §7 (Flutter architecture — `health` package row), §9.2 (`health_samples` stays V2), §10.1 (`/recovery/health-sync` stays V2), §18 (Recovery — Health Connect moves from V2 to a read-only Phase 6.5 context), §23 (privacy), §31 (Phase 6.5 inserted), §34 (feature matrix)

---

## Context

Phase 6.5 makes Home context-aware: steps, calories, sleep, resting
heart rate and body metrics next to FITOS's own training, targets and
progression. On Android the platform-neutral source for that data is
Health Connect — Samsung Health, Google Fit, watches and scales all write
into it. The spec had pencilled in the `health` pub package for a V2.
Building it now, five decisions were needed.

## Decisions

### 1. Health Connect only, through a thin in-app channel (D1)

FITOS talks to Health Connect through `HealthConnectChannel.kt`, ~300
lines in `android/app` over `androidx.health.connect:connect-client:1.1.0`
(the stable release per developer.android.com, 8 Oct 2025), exposed to
Dart on the `fitos/health_connect` MethodChannel. Not the `health` pub
package: that package reads raw records for calories and distance (so we
would have to de-duplicate sources ourselves), requests permissions in
bulk, carries HealthKit and many data types we do not use, and lags the
platform API. The channel gives exactly the documented calls —
`getSdkStatus`, `getGrantedPermissions`, the `PermissionController`
request contract, `aggregate()`, `readRecords` — and nothing else.

No Samsung Health SDK, no Google Fit API, no wearable-specific code:
whatever those write into Health Connect arrives through the same door.

*Consequence:* `minSdk` 24 → 26 (the client's floor; Health Connect
itself needs Android 9+). §7's table row changes from "health package" to
"platform channel (Health Connect client)".

### 2. Provider abstraction

Dart sees `HealthDataProvider` (connection, requestPermissions, snapshot,
openSettings) and normalized models — `HealthMetric` (value, unit,
availability, start/end, sources, updatedAt), `HealthSnapshot`,
`HealthConnectionState`. `HealthConnectProvider` is the Android
implementation; `UnsupportedHealthProvider` answers honestly elsewhere.
Nothing above the channel imports a Health Connect type, so HealthKit or
another source can be added as a second provider.

### 3. Read-only

Ten `READ_*` permissions are declared and requested, grouped as Activity
(steps, distance, active and total calories, exercise sessions),
Recovery (sleep, resting heart rate) and Body (weight, body fat, BMR).
No `WRITE_*` permission exists in the manifest. Nothing is written back.
The `PERMISSION_READ_HEALTH_DATA_HISTORY` and background-read
permissions are **not** requested: reads are foreground only and Health
Connect's default 30-day window before the grant is enough for a
"latest measurement". Adding background sync later means a Play Console
declaration and a new ADR.

### 4. Availability, not nulls

Every metric carries one of `available`, `not_connected`,
`permission_denied`, `no_data`, `temporarily_unavailable`,
`unsupported`. A missing value is never rendered as 0. Grants are
re-read on every snapshot and on every foreground resume, so a
permission revoked in Health Connect shows up as `permission_denied`
on the next read; a `SecurityException` mid-read maps to the same.

### 5. Aggregate, in the user's calendar

Cumulative metrics (steps, distance, active and total calories, sleep
duration, resting HR average) are read with `aggregate()` over explicit
`TimeRangeFilter.between(start, end)` instants, so Health Connect
de-duplicates overlapping sources (phone + watch) — FITOS never sums raw
records. Ranges are computed on the Dart side with `package:timezone` in
`users.timezone`: the local day `[00:00, 24:00)`, "last night"
`[D−1 18:00, D 12:00)`, and the Monday-first local week (seven day
aggregates for steps and sleep). Point metrics (weight, body fat, BMR,
and resting HR when today has none) are the latest record in the last
30 days, with the record's own time for freshness.

### 6. Foreground refresh with an honest cache (D2)

The snapshot is fetched when Home is first shown, when the app returns to
the foreground, after a permission request, and on pull-to-refresh /
the Refresh button. No polling, no background reads. The last snapshot
that carried a value is stored in the phone's `cached_json` (drift) for
today's date; it is read back only when the provider errors
(`temporarily_unavailable`) and is marked `fromCache`, which the UI
states. "Not connected", "denied" and "unsupported" are never papered
over with a cached value.

### 7. Privacy boundary (D2)

Health data stays on the device: no contract or table changes, nothing
sent to the API, nothing to Gemini, nothing in analytics or crash logs
(the channel logs no values; the Dart side logs none). The rationale
activity Health Connect opens says exactly this. Sign-out clears the
local database, including the health cache.

## Play Console

Health Connect permissions require, before a store release: the "Health
apps" declaration with the READ data types above, a hosted privacy policy
URL, the rationale activity (present), and a real `applicationId`
(`com.example.fitos` is a placeholder). None of that blocks debug /
sideloaded builds. Recorded, not done.

## Consequences

- Home, the Health Data screen and the suggestion engine consume
  `HealthSnapshot` / `HealthConnectionState` only.
- 20 provider unit tests run against a faked channel; the real channel
  is exercised only on a device with Health Connect (manual acceptance).
- Future providers (HealthKit) implement `HealthDataProvider` and reuse
  every model, screen and rule.
