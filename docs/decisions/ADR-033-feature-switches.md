# ADR-033 — App features switched from the admin panel

**Status** Accepted by the owner on 2026-10-23 (beta 3.3 plan, part X) · **Date** 2026-10-24

## Context

Phase 16 built `feature_flags`, the admin **Flags** page and the public `GET /meta/config`. Phase 19 added the app's `flagOn()`. No feature used them, so turning something off still needed a new APK (backlog E18 / F4). The owner wants to switch features from the admin panel.

## Decisions

| # | Decision |
|---|---|
| D1 | **One list of switches,** `APP_FEATURES` in `packages/contracts`. The app keeps the same list (`lib/core/config/app_features.dart`); a test reads the contracts file and compares. The list: `share-programme`, `mess-ratings`, `streaks`, `community-foods`, `food-requests`, `weekly-report`. |
| D2 | **On unless stored off.** A switch with no `feature_flags` row is on. A new switch therefore needs no migration and starts on. `/meta/config` lists every switch, plus any other stored flag. |
| D3 | **The server refuses what is off** with 403 `feature-off`, so an old APK cannot use it either: <br>• `food-requests`: `POST /nutrition/foods/requests`; <br>• `community-foods`: sharing a new food and reporting one, and other people's shared foods are left out of search; your own foods and foods already logged are untouched; <br>• `weekly-report`: `GET /progress/weekly`, checked before premium. <br>The 3.3 features check their own switches. |
| D4 | **Reads are cached for 10 seconds** (`FeatureSwitches`, decorated on the app). The admin route clears the cache on a change, so the instance that served it is current at once. A second instance (blue/green) catches up within 10 seconds. |
| D5 | **The app hides what is off:** the entry points disappear and nothing shows an error. Missing-food counting stops quietly. A food is never sent as shared while community foods are off. Unknown (offline, still loading) counts as **on**, as `flagOn()` did. |
| D6 | **Phones notice within minutes:** `/meta/config` is read at start and again when the app comes back to the foreground, at most every 5 minutes. |
| D7 | **The admin page** ("App features") shows each switch's plain name, what it does, on or off, and when it last changed ("never changed" while it has no row). Other flags stay below. Every change is audited (`flag.set`), as before. |

## Consequences

**Good:** the owner can stop a misbehaving feature in seconds without an APK, and old APKs are covered by the server.

**Accepted:** a phone that stays in the foreground keeps its old switches until it next comes back or restarts. The server still refuses what is off.

## Amendment — beta 3.6

A new switch, **`food-guide`** (the AI food guide, ADR-020 amendment): on by default. When off, the Eat entry is hidden and `POST /nutrition/guide` answers 403 `feature-off`.
