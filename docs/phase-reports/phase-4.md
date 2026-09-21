# PHASE 4 COMPLETE — Program generation

**Date** 2026-09-21 · **Commits** `be20203` (everything), `c72cdbf` (test typecheck fix), plus this report's commit
**Head** pushed to `origin/main` · **CI on `c72cdbf`:** `ci-core` success (253) · `ci-api` success (124/124, 0 skipped on the PG 18 service; image booted) · `ci-mobile` success (117 tests, conformance, APK)

---

## IMPLEMENTED

Everything below was verified by executing it. The generator's tests run on
the real exercise seed; the API's on real Postgres 18 through real onboarded
profiles; the Docker image was rebuilt and serves the new routes.

**`packages/core/src/training/generator.ts` — the missing engine (§5)**
- Pure, deterministic, catalogue passed in. Same input → same programme,
  regardless of catalogue order. Every exercise carries a reason; every
  muscle the plan cannot serve carries a shortfall with its reason.
- Split selection is the §12.2 table cell by cell (2–6 days × experience);
  training weekdays spread across the week; rest days emitted so a week is
  always seven rows.
- Filters: performable (all required equipment in the user's set, bodyweight
  always available), not contraindicated by any active limitation, not above
  the lifter's level (beginners may use intermediate lifts, never advanced).
- Volume: §12.3 landmarks; weekly targets by goal bias (§12.1) — MEV ramping
  ~10 %/week toward MAV-high for muscle-gain/recomposition, held at MEV for
  fat-loss/general, MV–MEV for maintenance, lower for strength. Never above
  MRV; a hard weekly cap at MAV-high over every touched muscle including
  secondaries. Secondary involvement counts 0.5 sets (§12.3).
- Selection: compound-first pattern order; each session template has
  required patterns (a push day always has an overhead press, a lower day a
  squat and a hinge) and excluded ones (no presses on pull day). Within a
  slot the pattern's canonical lift wins (bench over close-grip bench, RDL
  over back extension), then loadable over bodyweight-only when the lifter
  has equipment (progression needs load, §12.4), bilateral compounds, level
  fit, not-used-this-week (PPL×2 varies), slug last. Secondaries only break
  ties in selection — counting them fully made a jump squat beat a goblet
  squat for "also hitting calves".
- Time fitting at 3.5 min per working set (§12.2): trim to ≤ +15 %; on
  progressing goals fill spare time toward MAV-low; goals held at MEV are
  not padded and the rationale says so. Three-exercise session floor.
- Shortfall reasons: `no-performable-exercise` (bodyweight-only biceps, per
  the owner's decision), `limitation` (an ankle limitation removes every
  calf raise), `session-time`.

**Backend**
- Contracts `training.ts`: programme / day / planned-exercise shapes,
  generate overrides (days, minutes only — everything else is the profile),
  custom PUT (2–6 distinct days, each with ≥1 exercise, ordered rep range),
  day PATCH (name and/or exercises; must change something).
- Migration `0003_programs`: `programs` (soft-delete; `one_active_program`
  partial unique index verbatim from §9.3; days 2–6 and week ≥1 CHECKs),
  `program_days` (unique per weekday), `planned_exercises` (unique order per
  day; CHECKs on sets, ordered reps, RIR, increment; exercise FK `restrict`
  so a planned exercise can never dangle). Hand-written down; the migration
  suite walks all four migrations both ways and proves the index and CHECKs.
- `POST /training/program/generate` — profile → generator input; missing
  facts are a 409 naming them; 1 day/week clamps to the table's 2. Replaces
  the active programme atomically; the old one stays inactive, never
  deleted. `GET /training/program`. `PUT /training/program` (custom; unknown
  exercise ids → 422 naming them). `PATCH /training/program/days/{id}`
  (ownership → 404, no existence leak). `training.service.ts` is the ONLY
  caller of `generateProgram` (§7.3, §30).
- "Remains adaptive": a custom programme is stored in the same
  `planned_exercises` rows with the same `mesocycle_week` the progression
  engine (Phase 5) reads; there is no second path.

**Flutter**
- Weekly plan: seven rows Monday-first, rest days greyed, every exercise
  with its prescription ("4 × 6–12 @ RIR 1"), shortfalls in amber verbatim,
  "Why this plan" rationale, Regenerate / Build my own; empty state offers
  both. Tap an exercise → its detail; tap a day header → the editor.
- Day editor: session name, − / value / + steppers for sets, rep range and
  RIR, remove, "+ Add exercise" (the library in picker mode), Save → PATCH.
- Custom builder: name, 2–6 weekday toggles, per-day session name and
  exercises via the picker, Save → PUT. Validation mirrors the contract.
- Exercise browser gains `pickMode`. TODAY links to the plan.
- Nothing is decided on the client; the controller is a pipe.

## FILES

**created** — `packages/core/src/training/generator.ts`, `packages/core/test/generator.test.ts`;
`packages/contracts/src/{training,training.test}.ts`;
`database/migrations/{0003_programs.sql,down/0003_programs.down.sql,meta/0003_snapshot.json}`;
`apps/api/src/db/schema/training.ts`; `apps/api/src/modules/training/{repository,service,routes,training.integration.test}.ts`;
`apps/mobile/lib/features/training/**` (entities + 2 generated, repository interface + Dio impl, controller, day-exercise list widget, weekly plan, day editor, custom builder);
`apps/mobile/test/{support/fake_training_repository.dart,features/training/{program_controller,training_screens}_test.dart}`;
`docs/phase-reports/phase-4.md`

**modified** — `database/seeds/exercises.json` (three muscle relabels); `packages/contracts/{openapi.json,src/index.ts}`;
`apps/api/src/{app.ts,db/{schema.ts,schema/enums.ts,migrate.integration.test.ts}}`; `database/migrations/meta/_journal.json`;
`apps/mobile/lib/{core/routing/router.dart,features/exercise/presentation/screens/exercise_browser_screen.dart (pickMode),features/today/**}`;
`apps/mobile/test/{widget_test.dart,contracts/contract_conformance_test.dart}`

**removed** — nothing

## DATABASE

- migrations: `0003_programs` (up via drizzle-kit; down hand-written; both verified on PG 18)
- enum types (+2): split_type (5 generated + custom), program_source
- tables:
  - `programs` — user_id, name, split_type, days_per_week (CHECK 2–6), source, mesocycle_week (CHECK ≥1), active, rationale jsonb, shortfalls jsonb, created/updated/deleted_at; **`one_active_program` UNIQUE (user_id) WHERE active AND deleted_at IS NULL**
  - `program_days` — program_id, day_of_week (CHECK 1–7), session_name, focus muscle_group[], is_rest; UNIQUE (program_id, day_of_week)
  - `planned_exercises` — program_day_id, exercise_id (FK restrict), order_index, set_count, rep_min, rep_max, target_rir, increment_kg numeric(5,2), reason; UNIQUE (day, order); CHECKs sets 1–10, 1 ≤ rep_min ≤ rep_max ≤ 50, RIR 0–5, increment > 0
- seed: three muscle-label corrections (floor press, conventional/sumo deadlift, back extension); re-applied locally

## APIS

- `POST /v1/training/program/generate` — body optional `{ daysPerWeek?, preferredSessionMinutes? }`; 409 `{ details: [goal|experienceLevel|trainingDaysPerWeek] }` before onboarding; replaces the active programme
- `GET /v1/training/program` — active programme: id, name, splitType, daysPerWeek, source, mesocycleWeek, active, createdAt, days[7]{id, dayOfWeek, sessionName, focus, isRest, estimatedMinutes, exercises[{…, reason}]}, weeklyVolume, rationale, shortfalls; 404 when none
- `PUT /v1/training/program` — `{ name, days: [{ dayOfWeek, sessionName, exercises: [{ exerciseId, setCount, repMin, repMax, targetRir, incrementKg? }] }] }`; 422 unknown exercise
- `PATCH /v1/training/program/days/{id}` — `{ sessionName?, exercises? }`; 404 not the user's active programme
- All: Bearer required (default-deny sweep now 19 routes), §10 envelope, `.strict()` bodies

## TESTS

```
executed   pnpm -r test (packages)
           packages/core        253 passed   (+148: generator)
             §12.2 table           16   every cell + out-of-range
             targets                3   ramp, holds, MV ≤ target ≤ MRV for every goal/week/muscle
             90-combination matrix 90   2–6 days × 3 levels × 6 goals: 7 rows, session count, split,
                                        ≥3 exercises, compound-first, §12.1 reps/RIR, reasons, increments,
                                        no duplicates, ≤ +15% time, ≤ MRV, recount = tally, shortfalls explained
             determinism            1   incl. reversed catalogue
             MEV–MAV                 9+3 full gym 75 min 4–6 days: every muscle in [MEV, MAV-high]; 2-day honesty; week-4 > week-1
             duration              2+2+2  ±15% at 45/60; MAV-low cap at 75/120 stated; 3.5 min/set
             equipment            6+2   six kits; bodyweight-only biceps gap; bar closes it
             limitations          8+2   every body part; knee rationale; ankle → 'limitation'
             shape                  3   PPL×2 varies; beginners ≤7 and no advanced; pattern order
           packages/contracts    23 passed   (+4: custom programme rules)
executed   DATABASE_URL=… pnpm --filter @fitos/api test      (local PG 18)
           apps/api             124 passed, 0 skipped   (14 files; +11)
             training.integration  11   core = contracts vocabularies; 404 → next step; 409 names missing;
                                        generate from profile (reasons, equipment, params); 90-combination
                                        ACCEPTANCE through the API; limitation on file; regenerate keeps old
                                        inactive; custom persists + re-reads (rows asserted); unknown id 422;
                                        PATCH rename/replace/ownership 404/422s
             migrate.integration   13   (+1: 0003 index, CHECKs, cascade; walks four migrations both ways)
executed   flutter test          117 passed   (+19)
             controller             7   pipe semantics, overrides only, failures leave state, no retry loop
             screens                9   empty → generate; week renders (amber shortfall, rationale); failed
                                        generate; exercise → detail; editor steppers/remove/rename → PATCH body;
                                        empty day blocked; picker adds; builder validation → PUT body; six-day cap
             contract conformance  21   (+3: three enums, four shapes, three request bodies)
executed   dart run custom_lint   No issues found
executed   flutter analyze --fatal-infos  clean;  dart format  0 changed;  build_runner  fresh
executed   pnpm typecheck / lint  clean (core, contracts, api)
executed   docker compose up --build api → GET /v1/training/program → 401 (route present, protected)
coverage   not measured — §18 gate
```

Spec §31 Phase 4 test requirements, each satisfied:

| Requirement | Where |
|---|---|
| every (days × experience × goal) combination produces a valid program | `generator.test.ts` (90 cases, structural checks); `training.integration.test.ts` (90 generations through the API) |
| equipment constraints respected | `generator.test.ts` six kits incl. nothing; API test asserts only the profile's equipment appears |
| limitations exclude contraindicated exercises | `generator.test.ts` all eight body parts; API test with a `user_limitations` row |
| volume lands within MEV–MAV | `generator.test.ts` — full gym, 75 min, 4–6 days, all three levels: every muscle in [MEV, MAV-high]; ≤ MRV in all 90 |
| duration within ±15 % of preference | `generator.test.ts` at 45 and 60 min for a progressing goal; where volume caps earlier (75/120) or the goal is held at MEV, the session is shorter **and the rationale says why** — see deviations |

Acceptance: **generator handles 2–6 days for all goals/experience levels**
(90/90 in core, 90/90 through the API) · **custom program persists and
remains adaptive** (PUT → rows asserted → GET equal; same tables and
mesocycle_week as generated).

**Manual ("generate for 3 different profiles; sanity-check as a lifter
would"):** done by reading the generator's output, which is how three
scoring rules and three seed relabels were found. The three profiles:

- *Hostel beginner, 3 days, muscle gain, dumbbells + bar:* full body ×3 —
  dumbbell squat / RDL / reverse lunge / DB bench / DB OHP / chest-supported
  row / chin-up, 56–60 min; calves and abs reported short (session time).
- *Intermediate, 4 days, fat loss, full gym, knee limitation:* upper/lower —
  bench / OHP / row / straight-arm pulldown / fly / curl; lower days deadlift
  + calves + abs only, 39 min; **quads 4/10 reported as `limitation`** (every
  squat/lunge/leg extension is knee-contraindicated), 32 exercises excluded.
- *Advanced, 6 days, muscle gain, full gym, 75 min:* PPL ×2 — bench / push
  press / fly / skull crusher; row / pulldown / lateral raise / curl; squat /
  deadlift / calves / abs; second push and pull days vary; every muscle at
  target; sessions 28–53 min with the MAV-low cap stated.

**CI:** `be20203` — `ci-core` ✓, `ci-mobile` ✓, `ci-api` ✗ at Typecheck (four `noUncheckedIndexedAccess` errors in the new integration test; my local typecheck had run against a stale incremental build). Fixed in `c72cdbf`, reproduced first from a clean `dist`. On `c72cdbf` all three workflows succeed.

## KNOWN ISSUES

1. **Manual acceptance on the device not yet executed.** The API container
   is rebuilt and the local DB migrated/seeded; the app needs a rebuild.
   TODAY → "Your training plan" → Generate.
2. **`mesocycle_week` never advances yet.** The column, the ramp and the
   tests exist; the weekly tick belongs with session completion (Phase 5
   `POST /training/sessions/{id}/complete`) and deload logic (§12.5).
   Every programme today is week 1.
3. **`GET /training/today` is Phase 5.** The plan screen shows the week;
   "what do I do today" with target loads needs set logs.
4. The generator's time model ignores that unilateral sets take longer.
   Estimated minutes are 3.5 × working sets exactly as §12.2 states.
5. Editing a generated day drops the generator's `reason` for the replaced
   rows (they are the user's choice now) but keeps `source = generated` and
   the programme rationale, which then describes a plan that has changed.
   Honest but slightly stale; a "modified" flag is a Phase 5 nicety.
6. The day editor cannot reorder exercises (only remove and append).
7. Programme names are `"<Split> · <n> days"` for generated ones; not
   user-editable except by building a custom one.

## DEVIATIONS FROM SPEC

All deliberate; each with the reason.

- **Duration "within ±15 %" holds where volume allows, not unconditionally.**
  Week-1 volume is MEV (§12.3 "start at MEV"), capped at MAV-low when
  filling spare time. A 75-minute preference on an upper day cannot be
  honestly filled in week 1 without exceeding MAV-low; a fat-loss plan
  "held at MEV" (§12.1) must not be padded with sets to fill a clock. In
  both cases the session is shorter and the rationale states why. Asserted
  as such.
- **Two 60-minute days cannot reach MEV for every muscle**, and the
  generator says so per muscle rather than exceeding the time ceiling.
- **Pull days own shoulders too** (rear delts), so shoulders are shared
  between push and pull in PPL; a press never lands on a pull day.
- **Required / excluded patterns per session template** are not in the
  spec's text; they encode "select by movement pattern" (§12.2) so a push
  day always has both presses and a lower day both a squat and a hinge.
- **Beginners get up to seven exercises**, intermediate/advanced eight; a
  three-exercise floor for all. Not specified; taken from what a coach
  would hand over (a six-day strength split was producing two-lift days).
- **`programs.rationale` and `programs.shortfalls` (jsonb) and
  `planned_exercises.reason` (text)** are columns beyond §9.2's list; §12.4's
  "a recommendation without a reason is a bug" applies to the plan too.
- **`planned_exercises.exercise_id` is `ON DELETE RESTRICT`**, not cascade:
  deleting a library row must not silently hollow out a user's programme.
- **Custom-day `focus` is derived on read** from the exercises' primaries,
  stored empty, so an edit can never leave it stale.
- **Seed relabels** (floor press, deadlifts, back extension) were made to
  the Phase 3 file: the generator revealed them as mislabelled for
  programming purposes. The seed integrity suite still passes.
- **`daysPerWeek` from onboarding may be 1**; the generator clamps to the
  table's minimum of 2 and the rationale shows the days used.

## NEXT PHASE

- **Phase 5: Workout logging** — `workout_sessions`, `session_exercises`,
  `set_logs`; `GET /training/today` with per-exercise target loads from
  `progression.ts`; start/log/complete endpoints with `client_*` idempotency;
  offline-first session screen (drift + sync queue, §33). Not started.

**Blockers:**

1. **Manual acceptance on the emulator** — owner: rebuild the app, generate a
   programme, read it as a lifter, try the editor and the builder.
2. Neon dev still has no migrations or seed applied. Not blocking.
