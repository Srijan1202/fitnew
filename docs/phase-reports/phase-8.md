## PHASE 8 — Nutrition logging — ACCEPTED AND FROZEN

**Date** 2026-09-24 · **Branch** `phase-8` from `phase-7` @ `389cd52` · not merged (owner instruction)
**Commits**
- `da6385e` — core logging domain and contracts
- `c802e76` — migration 0010 and the API
- `1d76d32` — mobile: EAT, log sheet, offline sync
- `9f736d3` — ADR-013 and the MASTER-SPEC amendments
- `43be39a` — UI remediation after the first S24 run
- plus the report commits

**Decision record:**
- Phase 8 proposal approved by the owner, J1–J21 plus the J22 correction.
- [ADR-013](../decisions/ADR-013-food-logging.md).

**Status:** **accepted and frozen** by the owner on 2026-09-24 after the 17-step S24 manual acceptance passed **17/17** on the remediated build (`43be39a`). The seven §38 Phase 8 boxes are ticked. No further Phase 8 code changes. `phase-8` is **not merged** into `main` (owner instruction). Phase 9 branches from the accepted commit.

### What was built

**Core** (`packages/core/src/nutrition/log.ts`, pure and deterministic)
- **Portions.** `resolvePortion`:
  - 0.1–20 servings in 0.01 steps, or up to 5000 g;
  - grams → servings exactly (per 100 g ÷ 100, a weighed serving ÷ its weight);
  - a serving with no weight refuses grams.
- **Snapshot.** `snapshotNutrition` scales the row and rounds it:
  - an exact row rounds to nearest and stays exact;
  - an estimate rounds outward and is never narrowed.
- **Day totals.** `rollupDay`, `addToDay` and `removeFromDay` give low and high sums. Unknown fibre is counted in `fibreUnknownItems` and never added as 0.
- **Remaining.** `remainingForDay` gives target − consumed as a range, never clamped. The state is `under`, `around` or `over`.
- **Dates.** `localDateOf` (the IANA zone), `addDays`, and `checkLogDate` (today and 30 days back, never a future day). `defaultMealSlot` picks the slot by hour.
- **Shared fixture.** `test/fixtures/portion-preview.json` pins the numbers both core and the app's preview must produce.

**Contracts** (`packages/contracts/src/nutrition-log.ts`; `openapi.json` regenerated)
- `createLogRequestSchema`: a discriminated union of search items, quick add, or a saved meal.
- The item snapshot, range totals, remaining ranges, and the day with its target.
- Recent foods, saved meals, and the create-from-logs request.

**Database: migration `0010_nutrition_logging`** (+ down script)
- **`food_logs`**
  - unique `(user_id, client_log_id)`;
  - `local_date` fixed at write;
  - `saved_meal_id` (set null on delete);
  - soft delete;
  - indexes `(user_id, local_date)` and §9.3's `(user_id, logged_at DESC)`, both live rows only.
- **`food_log_items`** is the full snapshot: name, source, row, servings, grams, ranges, nullable fibre and confidence.
  - Checks: range order, non-negative values, servings > 0, row both-or-neither.
  - The fibre CHECK is both-or-neither and written out explicitly (the Phase 7 NULL lesson).
  - `food_id` is `ON DELETE SET NULL`.
- **`daily_nutrition`** is a cache of range sums with `fibre_unknown_items` and `item_count`. It has no target columns.
- **`saved_meals`** has `client_meal_id` unique per user and non-empty `items`.
- `mess_dish_id` is deferred to Phase 9.

**API** (`apps/api/src/modules/nutrition/log-*.ts`)
- `GET /v1/nutrition/today` and `GET /v1/nutrition/day/{date}` (a future date is 422). Each returns:
  - the `nutrition_targets` row in effect on that date;
  - totals, remaining, and the logs.
- `POST /v1/nutrition/logs`
  - The server snapshots the visible food's named row × the portion **at log time**.
  - 201, then 200 on replay.
  - Another user's custom food is 404; a bad portion or a date out of range is 422.
  - The response carries the updated day.
- `DELETE /v1/nutrition/logs/{clientLogId}` soft-deletes the whole log, is idempotent (a repeat is 200), and returns the day. Unknown is 404.
- `GET /v1/nutrition/foods/recent`: newest first, one per food with its last portion; foods that are no longer visible are dropped.
- Saved meals:
  - `GET/POST /v1/nutrition/saved-meals` (created from the caller's logs, retry-safe by `clientMealId`);
  - `DELETE /v1/nutrition/saved-meals/{id}`;
  - logging a saved meal re-snapshots each food's **current** values.
- **Cache.** `daily_nutrition` changes in the same transaction as every insert or delete. `pnpm db:rebuild-nutrition` rebuilds it, and the image ships it as `dist/db/rebuild-nutrition.js`.
- **AI (J17).** The food log stays excluded from FITOS AI. Only the obsolete wording changed: the context flag is now `nutrition.foodLogShared: false`, and the tool and rules say the log "is not shared".

**Mobile**
- **EAT** (the Nutrition tab root)
  - The hero is remaining kcal against the target:
    - a range when estimates are logged;
    - "120 kcal over 2,400" when over;
    - "At target" when the target lies inside the range eaten.
  - Protein remaining; carbohydrate, fat and fibre lines ("Fibre 3 g + not known for 1 item / 30 g").
  - An "Includes estimates" note.
  - Meals by slot, with a delete button on each entry (confirmed) and "Save as meal" on each slot.
  - ‹ › day history: never into the future; days more than 30 back are read-only.
  - The offline, stale, unsynced and parked notices, with Retry.
- **Log sheet**
  - Four sources: Recent, Search, Saved meals, Quick add.
  - The meal slot defaults by local hour.
  - Quick add requires kcal, protein, carbohydrate and fat; fibre is optional and sent as null when empty.
- **Portion step**
  - A row picker; servings with −/+; grams for weighed servings (per-100 g rows are entered in grams).
  - Validation that mirrors core.
  - A display-only preview line: "≈ 180–278 kcal · 9–13.5 g protein · 225 g — preview only".
  - The meal slot.
- **Food detail → "Log this food".** After creating a custom food: "Saved to your foods." and **Log it now**.
- **Home** reads the same cached server day as EAT.
  - The tile reads "1,210–1,480 / 2,276 kcal".
  - The existing `eat-protein` and `eat-meal` rules use the **high** end of each range (J16).

### Sync (owner: a separate NutritionSyncEngine; the workout SyncEngine is not modified)

- **Local-first.** `local_food_logs` and `nutrition_sync_queue` form drift schema **v2**; the migration adds tables only. A log and its queue entry are written in one transaction.
- **Pending entries** are listed as "Not synced yet — not in the totals until FITOS has it", with a preview. Every total on screen is the server's cached day (J10).
- **Engine policy** (ADR-006's policy, new code):
  - FIFO; a log's delete never overtakes its create.
  - Wakes on connectivity, app resume, and its own timer.
  - Offline, "not answering" (hosted 502/503/504/429) and 401 stop the drain without spending an attempt.
  - Other failures back off (300 ms · 2ⁿ) for five attempts, then park with Retry.
  - A 422 (or a 404 on create) parks at once with the server's reason.
  - A delete the server doesn't know (404) counts as done.
- **Folding:**
  - deleting a log that was never uploaded drops its row and its queued create, and sends nothing;
  - deleting one on the server, or on the wire, queues a delete behind it.
- **Delivery.** A confirmed create writes the server's day into the cache **and** removes the local row in one transaction.
- **Fixed during the phase:**
  - the day stream first read the cache and only then subscribed to table updates, so a write in between was missed; it now subscribes before the first read and reloads in order;
  - removing items from the day cache used an upsert whose would-be INSERT row failed the CHECK; removal is now a plain UPDATE.

### TESTS (all executed locally)

| Suite | Result | New in Phase 8 |
|---|---|---|
| `pnpm --filter @fitos/core test` | **500 passed** | +18 (`log.test.ts`, including 2 against the shared fixture) |
| `pnpm --filter @fitos/contracts test` | **49 passed** | +5 |
| `pnpm --filter @fitos/api test` (Postgres 18, `fitos_test`) | **347 passed** (24 files) | +25: food logging 24, migration 0010 1 |
| `flutter test` (host, Flutter 3.47.2) | **442 passed** | +46: sync 17, EAT / log / portion widgets 18, preview fixture 4, conformance 4, Home 3 |

**Core**
- Portion conversion and its bounds.
- Snapshots: outward, nearest, deterministic.
- Range sums, and add/remove being exact inverses (cache = recompute).
- Unknown fibre.
- Remaining under, over and around.
- IST 23:59 / 00:01, a UTC evening that is the next IST day, calendar crossing, 30-day window.

**Database**
- Constraints:
  - both-or-neither fibre;
  - `row_both_or_neither` and `servings_positive`;
  - `local_date` format and the enum;
  - per-user client-id uniqueness (the same id is allowed for another user);
  - `saved_meal_method` and non-empty items;
  - `daily_nutrition` counts, and no target columns.
- Soft delete keeps the items; cascades from users.
- Up/down with 0010 removed first; migrations twice (below).

**API**
- **Writes:**
  - create 201 with the exact snapshot (dal tadka × 1.5 = 180–278 kcal);
  - exact USDA rows plus grams, and several items in one log;
  - portion rules (0.01 steps, bounds, weightless serving, missing row);
  - replay 200 with nothing counted twice;
  - 4 concurrent replays → 1 log;
  - delete lowers the totals by exactly that log; delete replay 200; unknown 404; soft delete kept;
  - the last delete leaves no cache row;
  - a replayed create after its delete does not come back;
  - another user's log can't be deleted.
- **Snapshots:**
  - a corrected food (values and name) leaves the logged day unchanged, checked at the API **and** in the database row, while a new log takes the corrected values;
  - a deleted food leaves the item whole with `food_id` null.
- **Dates and targets:**
  - IST boundary days;
  - a later timezone change doesn't move a day;
  - future and 31-days-back refused, 30 days allowed, bad date 422;
  - target history (each day shows the row in effect then; none before any) and over-target state.
- **Privacy:** another user's custom food returns 404 and never appears in recents.
- **Features:** quick add (default name, fibre unknown or stated, missing macro 422); saved meals (create, replay, preview row, re-log with current values, the old log unchanged, foreign 404, delete keeps logs); recent foods (order, last portion, deleted and quick adds excluded, limit bounds).
- **Cache:** the cache equals a recompute (the per-user rebuild and the whole-database script).
- **Performance:** measured and asserted.
- **Unchanged:** Phase 7 search ranking.

**Mobile**
- **Conformance:**
  - every Phase 8 DTO against `openapi.json`, including each union variant and `/day/{date}`;
  - the hand-written unions round-trip.
- **Sync:**
  - offline log (no attempt charged, no fake total); reconnect;
  - **kill / reopen**;
  - **duplicate replay** (reply lost → re-sent → one server log);
  - **concurrent replay** (3 drains → 1 request);
  - **delete before upload** (nothing ever sent); **delete after upload**; delete while the create is **in flight** (queued behind);
  - 404 delete done; **parked + Retry** (422); five-attempt backoff then park; **401 recovery**; hosted 503 waits;
  - delete never overtakes a create in backoff;
  - **drift v1 → v2 upgrade keeps a queued workout**;
  - sign-out clears the food tables; the workout and nutrition queues stay separate.
- **Screens:**
  - EAT empty state, no targets, estimate ranges plus unknown fibre, over target, stale-offline, day history (including 30 vs 31 days back and no future);
  - quick add → total, quick add missing macro;
  - search → portion (preview, 0.01 refusal, slot, logged dartnumbers equal the preview), per-100 g in grams;
  - recents with the last portion, saved meal preview and log, "Save as meal";
  - offline log (pending, not in totals, then synced), parked + Retry, delete (exact reduction), offline delete ("deleting" while still counted), deleting an unsynced log (no request).
- **Home:** the tile shows the server range; the J16 high-end rule fires and holds back correctly.

**Performance** (local Postgres 18; one user with **30 days × 10 logs = 300**, each POST checked for 201):

| | p50 | p95 | Budget |
|---|---:|---:|---:|
| `POST /nutrition/logs` (300 requests) | ≈ 34 ms | **≈ 44 ms** | < 200 ms |
| `GET /nutrition/today` and `/day/{date}` (60 requests) | ≈ 11 ms | **≈ 15 ms** | < 200 ms |

**Static checks**
- `pnpm typecheck` (api, core, contracts) and `eslint` (api, contracts): clean.
- `dart analyze --fatal-infos` and `dart run custom_lint`: clean.
- `dart format --set-exit-if-changed`: clean; `build_runner` output is committed and current.

### DATABASE AND SEED, RUN FOR REAL

- **Dev database:**
  - `db:migrate` run twice; the second applies nothing, and 11 migrations are recorded.
  - `food_logs`, `daily_nutrition` and `saved_meals` exist.
  - `db:seed`: 305 foods, 580 nutrition rows, 339 aliases (Phase 7, unchanged).
  - `db:rebuild-nutrition` runs.
- **Local API container** (rebuilt from this branch): the image's `dist/db/migrate.js up`, `dist/db/seed.js` and `dist/db/rebuild-nutrition.js` all run. `/v1/nutrition/today` answers 401 without a session, so the route exists.

### BUILDS

- LAN alpha debug APK at `build/app/outputs/flutter-apk/app-debug.apk`.
- API `http://10.52.198.11:8080`, `/health` 200 at build time. The first Phase 8 build targeted `172.16.205.86` (the PC was on another network at the time) and could not reach the server once the PC was back on `10.52.198.11`, so the APK was rebuilt.
- The PC's LAN address changed since Phase 7; rebuild if it changes again.

### CI

On `9f736d3`, all three jobs passed:
- **ci-core** ✓
- **ci-api** ✓ — tests on PG 18. The Docker image migrates, seeds and boots in production mode, and answers 401 on `/v1/nutrition/today` and the Phase 7 search.
- **ci-mobile** ✓ — codegen current, analyze, custom_lint, format, tests, APK.

This report commit is documentation only.

### S24 MANUAL ACCEPTANCE — PASSED 17/17 (owner, 2026-09-24)

Run by the owner on the Samsung S24 against the UI-remediated build (`43be39a`). Every step passed.

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
| 17 | PASS |

The steps:


1. **A full real day using Search.** Log breakfast, lunch, snacks and dinner from Search, with the portion step. The logged numbers must equal the preview.
2. **Recent food.** It appears with the last portion; logging it works.
3. **Quick add.** Kcal, protein, carbohydrate and fat are required; empty fibre shows as unknown.
4. **Saved meal.** "Save as meal" on a slot; next day, log it from Saved meals in one tap.
5. **Custom food.** Create one from a label and log it.
6. **Manual total verification.** Add up every item's kcal and protein by hand; they must equal "Eaten …" and the remaining numbers (ranges where estimated).
7. **Delete.** Delete one entry; the totals drop by exactly that entry.
8. **Day boundary.** Log at 23:5x and at 00:0x IST; each lands on its own day, and ‹ › shows both.
9. **Offline logging.** In airplane mode, log three items. They show "Not synced yet" and are not in the totals. Kill the app, reopen, go online: each is on the server once, and the totals include them.
10. **Mid-sync kill.** Kill the app while a log is syncing, reopen, and check there's no duplicate.
11. **Historical snapshot.** Correct a food row on the dev database (for example `update food_nutrition set kcal_low = …`). Yesterday's logged values don't change, and a new log takes the new ones.
12. **Log-to-total timing.** Online, the total updates within 5 s of tapping Log.
13. **Past-day target.** With a target changed during the week, an earlier day shows the target in effect then.
14. **Ranges and unknown fibre.** Estimate items show ranges ("Includes estimates"); unknown fibre reads "not known for n items", never 0.
15. **Home agrees with EAT.** The Home Food tile shows the same eaten range and target as EAT.
16. **Food detail → Log this food** logs to today and opens EAT.
17. **Custom food → "Log it now"** straight after saving.

### MASTER-SPEC AMENDMENTS (J22: minimum for consistency; reasons in ADR-013)

- **§9.2:**
  - `food_logs`: + `local_date`, + `saved_meal_id`; `client_log_id` unique **per user**.
  - `food_log_items`: + the snapshot fields; `mess_dish_id` noted as added in Phase 9.
  - `daily_nutrition`: range sums, fibre known + unknown count, **no target copies**.
  - `saved_meals`: + `client_meal_id`; made from logged meals only.
- **§10.1:** `DELETE /nutrition/logs/{clientLogId}`; + recent foods; + the saved-meal routes.
- **§13.4:** "recent-first" is a separate Recent list, and search ranking is unchanged.
- **§19.4:** `nutrition.loggingAvailable: false (until Phase 8)` → `nutrition.foodLogShared: false`.
- **§30:** two rows: the server owns the snapshot, day totals and remaining; the portion preview is display-only in Flutter.
- **§31 Phase 8:** notes the extra routes. Tasks, tests and acceptance are unchanged.
- **§33:** food logs have their own local table, queue and engine.
- **Not changed:**
  - Phase 7 requirements and the ~500-food target: the 305 / gap 195 stays visible, and IFCT/INDB are still pending;
  - Phase 8 acceptance criteria;
  - the §38 checkboxes (ticked only at acceptance, below).

### INTENTIONALLY NOT DONE

- **Out of scope (owner):**
  - Phase 9 mess logging (and `mess_dish_id`);
  - recommendations (Phase 10) and the TODAY ranking engine (Phase 11);
  - barcode, natural-language and photo logging;
  - AI nutrition writes, and AI reading the food log;
  - micronutrients, hydration, reminders, streaks, charts, export;
  - a recipe builder, a global food cache, and in-place log editing (delete and re-log).
- **By design:**
  - search, custom-food creation, and saving or deleting saved meals need the network;
  - recent foods and saved meals work offline once loaded;
  - a log for a past day uses the slot's representative local time (08:00 / 13:00 / 17:00 / 20:00).
- **Known and untouched:** the Phase 6.6 teardown flake in the workout sync tests; the workout `SyncEngine` is unchanged.

### UI REMEDIATION (after the first S24 run; functional behaviour unchanged)

**What the S24 showed.** "BOTTOM OVERFLOWED BY 41 PIXELS" on Log Food with the keyboard open, Search covered by the Samsung keyboard, and a flat, text-heavy screen.

**Root cause of the overflow.**
- The shared `ToggleWrap` toggle is a `Container` with `alignment: center`, which expands to the full available width.
- So the four meals and four sources rendered as eight full-width rows.
- They sat in a fixed, non-scrolling header above an `Expanded`.
- When the keyboard shrank the body, the header no longer fit.
- The shared widget is unchanged (exercise and training use it). The nutrition screens now use their own compact controls.

**What changed (UI only).** No schema, contract, calculation, sync-engine or search-ranking change.

- **Log Food**
  - ONE `CustomScrollView`:
    - a compact meal bar (icon + label, four equal segments);
    - a source bar (Recent · Search · Saved meals · Quick add, with icons);
    - then the chosen pane.
  - **Search:**
    - the field is a `PinnedHeaderSliver`, so it stays in view above the keyboard while the results scroll under it;
    - drag dismisses the keyboard, and tapping a result dismisses it and opens the portion step;
    - with no text typed, Recent shows under the field.
  - Food rows are compact: name; source badge with kcal (a range when estimated), protein and serving; an add affordance.
  - **Saved meals** have their own treatment: bookmark, items, a preview marked as a preview, Log.
  - **Quick add** is a titled form: kcal; protein and carbs side by side; fat and fibre side by side; a full-width "Add to Lunch".
  - Loading states are static skeletons.
- **EAT**
  - Header: "EAT" and Food library, then a compact ‹ Today · Thu 24 Sep › (tap the date to come back to today).
  - Hero:
    - "REMAINING" (or "OVER TARGET") with the server's range, scaled to fit the width, never wrapped;
    - a Protein / Carbs / Fat strip; eaten and fibre lines.
  - **Log food** sits above the fold.
  - All four meals always show, each with an icon and "Add". An empty meal says "Nothing yet — add food".
  - Logged foods are compact two-line rows: name over portion, kcal range over protein. A quiet × deletes.
  - "Save as meal" is a bookmark icon.
- **Portion step**
  - Content-width row chips; a Servings | Grams switch; a large [−] amount [+] stepper.
  - A PREVIEW grid: Calories, Protein, Carbs, Fat, Fibre ("Not known" when unknown).
  - "Preview only — FITOS works out what is logged when it saves."
  - The compact meal bar.
- **Text scaling:** every row holds at 200 % text (§6.8). Titles ellipsise, numbers scale down, and the "Save as meal" and "Add" actions stay on one row.

**New tests** (`test/features/nutrition/log_layout_test.dart`, 12 tests)
- **Sizes:** S24 (411×891) and a small phone (360×640), each at 100 % and 200 % text.
- **States:**
  - EAT empty, with food, and the previous day;
  - Log Food: Recent, Saved, Quick add;
  - Quick add with the keyboard open (the focused field sits above it);
  - Search with the keyboard open: the field and results are above the keyboard, the field stays pinned while the results scroll, a result can be tapped, and the portion step opens;
  - after the keyboard is dismissed.
- Any Flutter overflow fails the test.
- "Log food" is above the fold at normal text size.
- Existing assertions were updated only where the layout moved text (name and portion are now two lines; the preview is now cells).

**Results after remediation**
- Flutter **454 passed** (442 + 12).
- core 500, contracts 49, API 347, all unchanged and passing.
- analyze, custom_lint and format clean; codegen current.

**S24 re-check: not yet done by the owner.** No phone was attached to the PC, so the APK was built but not installed. It targets `http://172.16.205.86:8080`, the PC's Wi-Fi address at build time, so the phone must be on the same Wi-Fi. The 12 on-device checks:
1. EAT with the keyboard closed.
2. EAT with all meals empty.
3. EAT with logged food.
4. Search with the keyboard closed.
5. Search with the keyboard open.
6. Results while the keyboard is open.
7. Selecting a food.
8. The portion step.
9. Quick add.
10. Saved meals.
11. The previous day.
12. After the keyboard is dismissed.

Across all of them, confirm there is no overflow stripe anywhere.

**Outcome:** the owner confirmed Phase 8 works on the S24 after the remediation, and the 17-step acceptance above then passed on this build.

### ACCEPTANCE AND FREEZE (2026-09-24)

- **S24 manual acceptance:** 17/17 PASS (owner).
- **§38 Phase 8:** all seven boxes ticked — log tables · daily rollup · timezone-correct boundaries (step 8) · snapshot macros (step 11) · EAT screen · saved meals (step 4) · quick add (step 3). Each is backed by the automated suites above and the owner's S24 run.
- **Unchanged by acceptance:** the Phase 7 gap (305 foods, 195 short of ~500; IFCT/INDB pending) and the Phase 7 §38 boxes; no code change in this commit.
- **Frozen:** no further Phase 8 code changes; `phase-8` is not merged into `main`.
