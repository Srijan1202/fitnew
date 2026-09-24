# ADR-013 — Food logging: snapshots, range totals, and a separate local-first queue

**Status** ACCEPTED — owner approval of the Phase 8 proposal, J1–J21 plus the J22 correction (2026-09-24)
**Date** 2026-09-24
**Phase** 8
**Affects** MASTER-SPEC §9.2 (`food_logs`, `food_log_items`, `daily_nutrition`, `saved_meals`), §10.1 (nutrition routes), §13.4, §19.4, §30, §31 Phase 8, §33. The spec is amended only where it would otherwise contradict what is built (owner J22); this record holds the reasons.

---

## Context

Phase 7 shipped a food library: every nutrition row is a range, estimates
are wide, USDA records are exact, and fibre may be unknown. Phase 8 records
what a user ate. MASTER-SPEC §9.2 sketched `daily_nutrition` with single
numbers and target copies, `saved_meals` with no API, and `food_log_items`
with a `mess_dish_id` pointing at a Phase 9 table. §6.5 forbids showing an
estimate as a bare number. §33 names one `sync_queue` for everything.

## Decisions

### 1. A log item is a complete snapshot (§31, owner J18)

The server copies the chosen food row × the portion into the item at log
time. It stores the food's name and source, the row (basis, serving label,
serving grams), the portion (servings, and grams when known), every macro
range, fibre (NULL when unknown), and the confidence. History never reads
`foods` again. `food_id` is `ON DELETE SET NULL`, so removing a food leaves
the item whole. Tests correct and delete foods after logging them and
assert that the logged day does not move.

Scaling and rounding are core's `snapshotNutrition`: an exact row rounds
to nearest and stays exact; an estimate rounds outward and is never
narrowed (owner J20). Portions (owner J19) are core's `resolvePortion`:
0.1–20 servings in 0.01 steps, or up to 5000 g where the row has a weight.
Grams are converted exactly (per 100 g ÷ 100, a weighed serving ÷ its
weight). A serving with no weight takes servings only.

`mess_dish_id` is deferred to Phase 9, which creates the table it points at.

### 2. Totals are ranges; unknown fibre is counted (owner J1, J15)

`daily_nutrition` stores low and high sums for every macro. Fibre is split
into the part that is known plus `fibre_unknown_items`. Unknown fibre is
never folded in as 0. "Remaining" is target − consumed as a range, and is
never clamped: `under`, `over`, or `around` when the target lies inside the
range eaten.

### 3. No target copies (owner J2)

A day's target is the `nutrition_targets` row in effect on that date: the
latest `effective_from ≤ date`. `daily_nutrition` has no target columns, so
a target change never has to be written into past days.

### 4. The day is fixed at write time (owner J3, J4)

`food_logs.local_date` is `logged_at` in `users.timezone`, computed when the
log is written. Changing the zone later does not move history. A log may land
on today or up to 30 days back, never on a future day.

### 5. `daily_nutrition` is a transactional cache (owner J5)

Every insert and delete adjusts the day's row in the same transaction, by
exactly the items' snapshot values. A day left with no items loses its row,
as a rebuild would. `pnpm db:rebuild-nutrition` rebuilds the cache, and a
test proves the cache equals a recompute after creates, replays and deletes.

### 6. Idempotency and deletion (owner J8, J9, J12)

- `client_log_id` is unique per user, and a replay returns the same log with
  200.
- There is no PATCH: to change a log, delete it and log again.
- `DELETE /nutrition/logs/{clientLogId}` soft-deletes the whole log. It is
  idempotent and addressed by the client id, which exists before the server
  has ever seen the log.

### 7. Saved meals, quick add, recent foods (owner J6, J7, J13)

- **Saved meals** are made only from logged meals. There is no composer, so
  no recipe builder (§35). Logging a saved meal re-snapshots each food's
  current values; quick-add items keep their own values.
- **Quick add** requires kcal, protein, carbohydrate and fat; fibre is
  optional. It is stored with `source = user`, exact values, and never
  verified.
- **"Recent-first"** is a separate `GET /nutrition/foods/recent` list. The
  Phase 7 search ranking is unchanged.

These add routes beyond §10.1: `GET /nutrition/foods/recent`,
`GET/POST /nutrition/saved-meals`, `DELETE /nutrition/saved-meals/{id}`.

### 8. Offline: a separate queue and engine (owner J10, J11; §33)

Food logs get their own drift tables, `local_food_logs` and
`nutrition_sync_queue`, and their own `NutritionSyncEngine`. It copies
ADR-006's policy but not its code, and the workout `SyncEngine` is
untouched:

- FIFO, and a log's delete never overtakes its create;
- connectivity, app-resume and self wakes;
- offline, "not answering" and 401 stop the drain without spending an attempt;
- 300 ms · 2ⁿ backoff over five attempts, then parked with Retry;
- a permanent refusal (422, or 404 on create) is parked at once with the
  server's reason.

Folding is nutrition-specific:

- deleting a log the server has never seen drops its row and its queued
  create together;
- deleting one that is on the server, or on the wire, queues a delete
  behind it.

The drift schema moved from version 1 to version 2, and the migration only
adds tables. A test upgrades a real version 1 file that still holds a queued
workout.

Offline logging works from what is on the phone: recent foods, saved meals,
results on screen, quick add. There is no global food cache. A pending entry
shows a Dart preview of its numbers, which is DISPLAY-ONLY and never part of
a total. Every total on screen is the server's cached day. The preview is
tested against the same fixture as core
(`packages/core/test/fixtures/portion-preview.json`).

### 9. AI and Home (owner J16, J17)

- **AI:** the food log stays excluded from FITOS AI. Only the obsolete
  sentence "food logging is not available" changed; the context flag is now
  `nutrition.foodLogShared: false`.
- **Home:** the Home Food tile reads the same cached server day as EAT. The
  existing suggestion rules compare one number, so they get the
  conservative high end of each range: "protein low" fires only when even
  the most the user may have eaten is under 75 %. The engine was not
  redesigned.

## Consequences

- A corrected food fixes future logs only. Past days are what was eaten at
  the time.
- Totals can be wide on estimate-heavy days, and that is by design (§6.5).
- Two queues exist on the phone. Sign-out clears both (`clearAll`).
- Phase 9 adds the `mess` entry method and `mess_dish_id` by migration.
- Phase 14 adds AI drafts, which must still go through the confirmed
  `POST /nutrition/logs`.
