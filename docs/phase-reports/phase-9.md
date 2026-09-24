## PHASE 9 — VIT Mess — ACCEPTED

**Date** 2026-09-24 · **Branch** `phase-9` from the accepted Phase 8 (`6097727`) · not merged (owner instruction)
**Commits**
- `00b0602` — fresh read-only MessIT capture (verbatim) and drift report
- `f12e66e` — core mess mirror logic and contracts
- `08aa255` — migration 0011, the mirror job and the `/v1/mess` API
- `726b0c2` — mobile: MESS screen, EAT strip, Mess log source, mess setting, offline menus
- `9c8ce8e` — ADR-014 and the MASTER-SPEC amendments
- `c912c52` — fix: the development server's boot order (see *Found and fixed*), test typing, suite timeout
- `9418ad2` — this report
- plus the acceptance record (this update)

**Decision record:**
- The owner approved the Phase 9 audit with D1–D23 and clarifications on D1, D2, D10, D11 and D17, a structural confidence cap, and a fresh capture first.
- [ADR-014](../decisions/ADR-014-vit-mess-mirror.md).

**Status:** **accepted** by the owner on 2026-09-24 after the 16-step S24 manual acceptance passed **16/16** (below). Every automated check passes and CI was green on `c912c52` and `9418ad2`. The §38 Phase 9 boxes are ticked. `phase-9` is **not merged** into `main` (owner instruction).

### Before any code: the fresh capture

All six endpoints were fetched read-only on 2026-09-24 and saved verbatim in `packages/core/test/fixtures/messit-2026-09-24/`, with a manifest. The 2026-09-07 fixtures are unchanged. [Drift report](phase-9-messit-capture-2026-09-24.md).

**Format:** unchanged. **Content:**
- every endpoint now publishes all of September;
- published past days are **edited after publication** (re-spellings, appended tea/bread lines, one snack replaced);
- upstream fixed most of the nine §14.2 defects in its current data;
- the men's special mess has no diet labels.

None of this changed the approved design, so implementation went ahead. Two details were shaped by it:
- snapshot selection is latest-first (ADR-014 §3);
- one extra D9 spelling variant, "Chaat", because upstream re-spelt "Chat".

### What was built

**Core** (`packages/core/src/mess`)
- **`isMessItResponse`** now checks every entry: a yyyy-mm-dd date, an integer `type`, a string `menu`. One bad entry rejects the whole payload (D23).
- **`snapshots.ts`:** `resolveDayFromSnapshots`, `mergeSnapshots` and `latestPublishedDate`. The order is: the newest snapshot that publishes the date is exact; else the cycle from the latest snapshot; else the cycle over the union; else unavailable (D5).
- **`freshness.ts`:** `isMirrorStale`, meaning no successful fetch in 24 h (D19).
- **`nutrition.ts`:**
  - **`capMessConfidence`** (never `high`);
  - the D9 additions, appended after the base table so they can never capture a Phase 7 seed term: the spelling variants Subzi, Jamoon, Mysorepaku, Rasagulla, Badusha, Chaat, Mint Lemon, Pudding and Salna, plus Idiyappam and Stew;
  - Urapadai stays unestimated: nothing in the table describes it.
- **`messCode`**, and the `mess` entry method.

**Contracts**
- `mess.ts`:
  - providers, messes and freshness;
  - the menu, its resolution union, meals and dishes;
  - the dish estimate (medium or low only, `source: estimated`);
  - the correction request and response.
- The `mess` log variant: mess code, menu date and dishes, **no numbers**.
- `messDishSlug` on logged items, and `messCode` on logs.
- The saved-meal item kind `mess`.
- Profile PATCH `isVitStudent` and `mess`; `isVitStudent` on the profile.

**Database: migration `0011_mess`** (plus a hand-written down script)
- `mess_providers`.
- `messes`: six rows, each with its own mirror status.
- `mess_menu_snapshots`: `UNIQUE (mess_id, payload_hash)`, a GIN index on `dates`, first-seen and last-seen times.
- `mess_dish_nutrition`: CHECK `confidence <> 'high'` and `source = 'estimated'`.
- `mess_dish_corrections`: pending, retry-safe per user, with the value checked against the field.
- `food_logs.mess_id`: FK, `SET NULL`, only on `mess` logs.
- `food_log_items.mess_dish_slug`: provenance, never together with `food_id`.
- The enum value `mess`.
- **No `mess_days`, `mess_meals` or `mess_dishes`** (D2).
- The down script removes mess logs and meals that hold mess items, rebuilds `daily_nutrition`, and rebuilds the enum.

**API**
- **The mirror job** (`pnpm mess:mirror`; `node dist/jobs/mirror-mess.js`):
  - a plain GET with a fixed User-Agent and no user data;
  - validated, and checked to be that endpoint's own payload;
  - deduplicated by hash;
  - status recorded per endpoint;
  - estimates written for new slugs only;
  - advisory-locked.
- **Triggers:** a development-only 12 h in-process timer runs it locally. **Cloud Scheduler is not set up** (GCP paused); it is a deferred deployment dependency (D1).
- **Routes:**
  - `GET /v1/mess/providers`;
  - `GET /v1/mess/providers/{slug}/messes`;
  - `GET /v1/mess/menu?date&mess` (defaults to today and to your mess);
  - `POST /v1/mess/dishes/{slug}/correction` (pending, 20 per hour).
- **Logging** (`entryMethod: 'mess'`):
  - the server checks that the dish is on that day's menu;
  - its stored estimate is the row, snapshotted through Phase 8's core path (D10);
  - saved meals keep mess items as mess items and re-snapshot them when logged (D11).
- **Profile PATCH and onboarding** refuse any mess the server does not list (D13).
- The OpenAPI document is regenerated. The CI smoke check also asserts 401 on `/v1/mess/menu`.

**Mobile**
- **MESS screen** (`/nutrition/mess`):
  - ‹ date › from 30 days back to 14 ahead;
  - four meals with a diet mark (veg, egg, non-veg, or hollow for unknown), the estimate and serving, and a ✓ when logged;
  - ambient items (tea, bread, jam) after the meal's own dishes;
  - "As published" shows the mess's own text (D20);
  - "Show another mess" browses without changing the setting (D14).
- **Qualifiers, always shown:**
  - an inferred banner with the source date;
  - an unavailable banner with the latest published date;
  - a stale-mirror notice;
  - a notice when showing the phone's saved copy.
- **Tapping a dish:**
  - opens the Phase 8 portion step, with "Mess estimate · medium confidence · fibre not known" and "Report wrong nutrition";
  - grams only when the serving has a weight;
  - the log goes through the Phase 8 queue with no numbers.
  - A dish with no estimate, or a future day, opens a view-only sheet that says why.
- **Report wrong nutrition:**
  - a macro range, a diet class, or a note;
  - stored as pending, and shown as "report pending" to its author (D17).
- **EAT:** a "Today's mess" strip showing the meal of the hour and any qualifier. It is hidden without a mess.
- **Log food:** a **Mess** source, first when a mess is configured, showing the chosen meal's dishes.
- **Profile:** the mess by name, with a Change action (the server list, or "I do not eat at a VIT mess"). **Onboarding screen 6** reads the server list.
- **Offline:**
  - menus are kept in `cached_json`;
  - tomorrow's own menu is fetched ahead when today's arrives;
  - both show offline, marked as the saved copy (D18).
- **No new sync engine:** the workout SyncEngine and the NutritionSyncEngine are untouched.

### TESTS

| Suite | Result | New in Phase 9 |
|---|---|---|
| core | **542 passed** | 42: every-entry shape check, fresh capture (six endpoints, 14-day cycle, verbatim text, unlabelled non-veg), D9 additions and no shadowing, cap, snapshot resolution (exact / older / cycle / union fallback / latest-first / unavailable), freshness, codes |
| contracts | **61 passed** | 12: ids, cap, resolution, mess log (no numbers), saved mess item, corrections, profile PATCH |
| API | **373 passed** (26 files) | 26: migration 0011 up/down with data (1); 22 mess integration tests; 3 boot-order tests |
| Flutter | **497 passed** | 43: MESS screen 18, layout 8 (S24 and 360×640, 100 % and 200 % text, keyboard), config, cache and onboarding 10, conformance 7 |

**API mess integration tests** (real Postgres; scripted MessIT, no network):
- all six endpoints, and deduplication by hash;
- malformed payloads (bad entry, HTML, wrong mess) rejected, with the copy kept;
- an outage still serves the mirror, with honest freshness;
- runs never overlap (the lock);
- all six render; an inferred date carries its source; unavailable carries the latest date; stale after 24 h;
- the medium cap, and unknown fibre;
- a dish tap logs estimate × portion rounded outward, and is retry-safe;
- refused: a dish off the menu, an unknown mess, a dish with no estimate, grams without a weight, numbers in the body;
- **a logged dish never changes when its estimate changes**, and a new log takes the new estimate;
- **saved meals keep the range**, and quick adds are unchanged;
- corrections: pending, estimate unchanged, visible only to the author, retry-safe, validated;
- profile PATCH and onboarding validation;
- p95 of `GET /mess/menu` under 200 ms.

**Regression:**
- every Phase 8 test still passes. Two test harnesses gained a no-mess fake, and one test narrows the new saved-item union;
- the Phase 7 seed test passes, so the D9 additions change no Phase 7 food;
- a known pre-existing flake (`automatic_sync_test.dart`, a teardown race since Phase 6.6) failed once locally and once in CI on `9c8ce8e`, and passed on rerun. It is unrelated to Phase 9.

**Checks:**
- ci-core ✓, ci-api ✓ (typecheck, lint, tests, build, image migrates, seeds and boots, smoke) and ci-mobile ✓ (analyze `--fatal-infos`, custom_lint, format, tests, APK) on `c912c52`;
- the new Flutter tests also pass in the Linux container.

### DATABASE AND MIRROR, RUN FOR REAL (dev database)

- `pnpm db:migrate`: 0011 applied.
- `pnpm db:seed`: 1 provider and 6 messes.
- `pnpm mess:mirror`: all six **new**, 30 days each, 293 dish estimates, none `high`.
- The LAN container (`docker compose up --build -d api`, development) ran its timer's first mirror 5 s after boot: all six **unchanged**, so deduplication works against live data.

### Found and fixed

The first Phase 9 container **crash-looped**. server.ts registered the timer's `onClose` hook after `listen()`, which Fastify refuses. CI could not see it: its smoke boots in production, where the timer is off. `serve()` now registers the hook first, and `serve.test.ts` boots the app in development and in production. The same round fixed a test-typing error that failed ci-api's typecheck on `9c8ce8e`, and gave the mirror suite a 30 s timeout (5 s was exceeded under load).

### BUILDS

- LAN APK: `apps/mobile/build/app/outputs/flutter-apk/app-debug.apk`, targeting `http://10.52.198.11:8080`, the PC's address at build time (`.\tool\alpha.ps1`; `/health` returned 200). Built from `phase-9` at `c912c52`; the later commits change documentation only. This is the build the owner accepted on the S24. If the PC's address changes, rebuild with `.\tool\alpha.ps1`.
- The LAN API container runs Phase 9, with the mirror timer on.

### S24 MANUAL ACCEPTANCE — PASSED 16/16 (owner, 2026-09-24)

**What was tested:**
- **Device:** the owner's Samsung Galaxy S24.
- **App:** the LAN alpha debug APK above (Phase 9 code at `c912c52`, built with `.\tool\alpha.ps1`).
- **API:** the local Docker container `fitos-api` (`docker compose up --build -d api`), rebuilt from `c912c52`. It runs with `NODE_ENV=development` and the 12 h mirror timer on, at `http://10.52.198.11:8080` on the PC's Wi-Fi LAN.
- **Database:** the local dev database (`fitos-postgres`, Postgres 18), migrated to `0011_mess` and seeded (1 provider, 6 messes).
- **Mess data:** mirrored live from MessIT on 2026-09-24. `pnpm mess:mirror` stored all six endpoints (30 days each, 293 dish estimates, none `high`), and the container's first timer run found all six unchanged.
- **Not used:** Cloud Scheduler, GCP and Cloud Run (all deferred).

| Step | Result |
|---|---|
| 1 | PASS |
| 2 | PASS |
| 3 | PASS |
| 4 | PASS |
| 5 | PASS |
| 6 | PASS |
| 7 | PASS |
| 8 | PASS |
| 9 | PASS |
| 10 | PASS |
| 11 | PASS |
| 12 | PASS |
| 13 | PASS |
| 14 | PASS |
| 15 | PASS |
| 16 | PASS |

The steps:


1. **Mess setting.** Profile shows the mess by name. Change it to each of the six in turn and back. "I do not eat at a VIT mess" clears it, and EAT then hides the mess strip.
2. **All six messes render.** On MESS, use "Show another mess" for each. Each shows four meals, or an honest banner. Compare one day per mess against the live endpoint (open the URL in a browser).
3. **As published.** For today's lunch, "As published" matches the endpoint's text exactly.
4. **Dish detail.** The kcal range and serving; "Mess estimate · medium/low confidence · fibre not known"; never "high".
5. **Log a dish** at 1.5 servings. The logged numbers equal the preview, and EAT's totals rise by that range.
6. **Retry safety.** Kill the app mid-log and reopen: one entry.
7. **Deliberate duplicate.** Log the same dish twice: two entries.
8. **Offline.** In airplane mode:
   - today's and tomorrow's menus show as the saved copy;
   - a dish logged offline shows "Not synced yet";
   - back online, it is on the server once.
9. **Inferred menu.** Step ‹ › past 30 Sep. The inferred banner names the source date, and the menu is never shown as published.
10. **Outage.** Stop the PC's internet, or block `messit.vinnovateit.com`, and run `pnpm mess:mirror` (it reports `unreachable`). MESS still shows the menu. After 24 h without success the stale notice appears.
11. **No estimate.** Tap Urapadai (women's messes, 11 or 25 Sep dinner): it cannot be logged, and the sheet says why.
12. **History is frozen.** On the dev database, change a dish's estimate (`update mess_dish_nutrition set kcal_low = …, kcal_high = … where dish_slug = 'phulka'`). Yesterday's logged item does not change; a new log takes the new values.
13. **Saved meal.** "Save as meal" on a slot that includes a mess dish. Logging it next day shows the dish as a range, not a single number.
14. **Report wrong nutrition.** Send a report. It says pending, the dish shows "report pending", and the estimate is unchanged.
15. **Home agrees with EAT** after mess logs.
16. **Layout.** No overflow stripe on MESS, the strip, the Mess pane or the sheets, at normal and large text, keyboard open and closed.

### MASTER-SPEC AMENDMENTS (D22: minimum for consistency; reasons in ADR-014)

- **§5:** the estimate-table row. Phase 9 adds only observed dishes; IFCT waits on licensing.
- **§8:** the job file name (`jobs/mirror-mess.ts`).
- **§9.2:**
  - `food_logs.mess_id`;
  - `food_log_items.mess_dish_slug` replaces `mess_dish_id` (no FK);
  - per-mess mirror status;
  - snapshot columns;
  - `mess_days`/`meals`/`dishes` struck, with the reason;
  - the estimate table's CHECKs;
  - corrections pending.
- **§9.3:** a GIN index on snapshot `dates` replaces the `mess_days` index.
- **§9.4:** mess menus removed from the derived-cache list; they are parsed on read.
- **§10.1:** `/mess/menu?mess&date`; the correction is pending; profile PATCH takes `isVitStudent` and `mess`.
- **§14.6:**
  - the mirror is a job, and Cloud Scheduler is deferred;
  - a development-only timer;
  - **no client 6 h TTL:** the app asks the server on every view and keeps a saved copy for offline (see *For the owner*);
  - `isMessItResponse` checks every entry.
- **§31 Phase 9:** the job is built and its trigger deferred; the DB note. **Tasks, tests and acceptance are unchanged.**
- **§33:** the mess menu cache.
- **The mess data-flow diagram.**
- **Not changed:** acceptance criteria, the Phase 7 gap (305 foods, 195 short of ~500; IFCT/INDB pending), and every Phase 8 requirement.

### ACCEPTANCE AND CLOSEOUT (2026-09-24)

- **S24 manual acceptance:** 16/16 PASS (owner).
- **The §31 acceptance criteria are met:**
  - all six messes render;
  - a stale endpoint shows a clearly qualified inferred menu;
  - an upstream outage still serves the mirror;
  - a dish tap logs the correct estimated macros.
- **§38 Phase 9:** all ten boxes are ticked. Each is backed by the tests above and the S24 run:
  - mess tables (0011);
  - provider wired (the VIT config seeds the messes; core's parser serves every menu);
  - **mirroring job**: the job is built and verified by hand and on the development timer. The box is annotated that its Cloud Scheduler trigger is deferred while GCP is paused (ADR-014). Nothing claims Cloud Scheduler is set up;
  - enrichment by slug;
  - mess picker (onboarding and Profile);
  - MESS screen;
  - **resolution banner**;
  - correction submission (pending);
  - all 6 endpoints tested (both captures, and the API suite);
  - 9 defects tested. Unsorted dates are covered through the real unsorted captures in the resolution tests; the other eight each have their own test.
- **No change in the closeout:** no code, schema, API or contract change; Phase 8 untouched; no Phase 10 work.

### FOR THE OWNER

- **The client cache.** §14.6's "client cache: 6 h TTL" belonged to the direct-fetch design. Now the server is the cache, and the menu carries per-user marks (logged, report pending) that a TTL would freeze. The app asks the server on every view and uses its saved copy only offline. Recorded as an amendment; confirm or overrule.
- **"Chaat".** One D9 variant beyond the audit's list: MessIT re-spelt "Chat" as "Chaat" in September, which had dropped those snacks to the generic fallback.
- **Diet marks** use the national convention (a dot in a square) in the existing palette: pine = veg, amber = egg, oxide = non-veg, hollow grey = unknown. Each has its label for screen readers. No new colour.

### INTENTIONALLY NOT DONE

- **Out of scope (owner):**
  - plate recommendations and `/mess/menu/recommend` (Phase 10), and the TODAY engine (11);
  - correction review and the provider health dashboard (16);
  - AI, barcode, natural-language and photo logging;
  - IFCT/INDB;
  - other universities.
- **Deferred deployment dependency:** Cloud Scheduler for the mirror (GCP paused). The job is ready for it.
- **Known and accepted:**
  - a past day shows its menu as currently published (MessIT edits past days); logged items are unaffected;
  - the ✓ on a past day matches by slug, so a log made before an upstream re-spelling is not ticked against the re-spelt dish;
  - 13 of the 294 dishes seen use a generic role estimate (servings only, low confidence);
  - Urapadai has no estimate.
- **Open, not blocking:** redistribution of MessIT data (§36 Q6, before Phase 19).
