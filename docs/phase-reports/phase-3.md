# PHASE 3 COMPLETE — Exercise database

**Date** 2026-09-21 · **Commits** `298d98c` (everything), plus this report's commit
**Head** pushed to `origin/main` · **CI on `298d98c`:** `ci-core` success · `ci-api` success (113/113, 0 skipped on the PG 18 service; image booted) · `ci-mobile` success (98 tests, conformance, APK)

---

## IMPLEMENTED

Everything below was verified by executing it. Backend tests run against a
real Postgres 18 with the real seed; the Docker image was rebuilt and
serves the new routes.

**Contracts** (`packages/contracts/src/exercise.ts`)
- `MUSCLE_GROUPS` — exactly the ten rows of the §12.3 volume-landmark
  table, so every muscle the generator can count has a landmark.
- `MOVEMENT_PATTERNS` — seven compound (squat, hinge, lunge, four
  push/pull) and eight isolation/other patterns; `COMPOUND_PATTERNS` for
  §12.2 compound-first ordering.
- Difficulty, muscle role (primary = 1, secondary = 0.5 per §12.3),
  alternative reason (equipment / injury / preference).
- `exerciseSummarySchema`, `exerciseDetailSchema` (muscles, alternatives
  with their own id + equipment, contraindications), `exerciseListQuerySchema`
  (`?q&equipment=a,b&muscle&pattern&limit&offset`, strict),
  `exerciseListResponseSchema` (`items,total,limit,offset`),
  `exerciseSeedSchema` / `exerciseSeedFileSchema` (≥120 entries).

**Database** — migration `0002_exercise_library`
- `exercises` (slug unique; equipment[] and instructions[] CHECKed
  non-empty; increment CHECKed positive; trigram index on name for `?q`,
  GIN on equipment[] for `<@`), `exercise_muscles` (PK per exercise+muscle),
  `exercise_alternatives` (PK exercise+alternative+reason; CHECK not self),
  `exercise_contraindications` (PK exercise+body_part). All cascade.
- Five enum types from the contract arrays.
- Hand-written down; migration suite walks 0002 → 0001 → 0000 → nothing →
  all three, and proves the CHECKs and the cascade.

**Seed** — `database/seeds/exercises.json`, applied by `apps/api/src/db/seed.ts`
- **151 exercises** across all 15 patterns and all 8 equipment types;
  every one with ordered instructions (2–4 steps), ≥1 primary muscle,
  secondary muscles, contraindicated body parts, and ≥1 alternative.
- **460 alternative links.** Equipment and preference links symmetric;
  injury links one-way toward the gentler exercise; every link shares the
  movement pattern and a primary muscle (§12.6).
- Runner: validates the file against the contract, one transaction,
  idempotent by slug, join rows replaced wholesale, `updated_at` moves only
  on a real change, rows not in the file left alone (admin, Phase 16).
- 13 integrity tests on the file alone (no DB).

**API**
- `GET /v1/exercises` — `equipment` is what the user **has**; an exercise
  is returned only when all its required equipment is in that set, with
  `bodyweight` always available. `q` is a case-insensitive trigram-indexed
  substring match on name (and hyphenated slug). `muscle` matches primary
  only. Stable order by name; `total` for "12 of 151".
- `GET /v1/exercises/{id}` — detail; 404 unknown, 422 non-uuid.
- Both under default-deny; the sweep now covers 15 routes.

**Flutter**
- Exercise browser: debounced search, three filter rails ("I have" /
  muscle / pattern) as hairline-underlined toggles — no chips, no pills,
  colour reserved for meaning (§6). Count row, name + muscles · pattern ·
  kit rows, empty state with "Clear filters", failure with "Try again".
  Every change is a request; nothing is filtered locally (§30).
- Detail: eyebrow (pattern · difficulty · unilateral), works / also / needs
  / load step, "Skip if …" in amber, numbered verbatim instructions,
  alternatives with reason and equipment, each navigable.
- Routes `/exercises`, `/exercises/:id`; TODAY placeholder links to the
  library. `BodyPart` added to the vocabulary.
- DTOs hand-written per ADR-004 (now **ACCEPTED**); the conformance test
  checks the six exercise enums, three response shapes and the exact query
  parameter set against `openapi.json`.

## FILES

**created** — `packages/contracts/src/{exercise,exercise.test}.ts`;
`database/migrations/{0002_exercise_library.sql,down/0002_exercise_library.down.sql,meta/0002_snapshot.json}`;
`database/seeds/exercises.json`;
`apps/api/src/db/{schema/exercise.ts,seed.ts,seed.test.ts}`;
`apps/api/src/modules/exercise/{repository,service,routes,exercise.integration.test}.ts`;
`apps/mobile/lib/features/exercise/**` (entities + 2 generated, repository interface + Dio impl, providers, filter rail, browser, detail);
`apps/mobile/test/{support/fake_exercise_repository.dart,features/exercise/{exercise_providers,exercise_screens}_test.dart}`;
`docs/phase-reports/phase-3.md`

**modified** — `packages/contracts/{openapi.json,src/index.ts}`;
`apps/api/{package.json (db:seed),src/app.ts,src/db/{schema.ts,schema/enums.ts,migrate.integration.test.ts}}`;
`database/migrations/meta/_journal.json`; `database/README.md`; `scripts/README.md`;
`apps/mobile/lib/{core/routing/router.dart,features/auth/presentation/widgets/auth_form_field.dart (onChanged),features/profile/domain/entities/vocabulary.dart (BodyPart),features/today/**}`;
`apps/mobile/test/{widget_test.dart,contracts/contract_conformance_test.dart}`;
`docs/decisions/ADR-004-dart-client-generation.md` (ACCEPTED)

**removed** — nothing

## DATABASE

- migrations: `0002_exercise_library` (up via drizzle-kit; down hand-written; both verified on PG 18)
- enum types (+5): muscle_group, movement_pattern, difficulty, muscle_role, alternative_reason
- tables:
  - `exercises` — id, slug UNIQUE, name, movement_pattern, equipment[], difficulty, is_unilateral, default_increment_kg numeric(5,2), instructions text[], video_url, created_at, updated_at; CHECKs: equipment non-empty, instructions non-empty, increment > 0; indexes: name gin_trgm_ops, movement_pattern, equipment GIN
  - `exercise_muscles` — (exercise_id, muscle_group) PK, role, contribution numeric(3,2) CHECK (0,1]
  - `exercise_alternatives` — (exercise_id, alternative_id, reason) PK, CHECK exercise_id <> alternative_id
  - `exercise_contraindications` — (exercise_id, body_part) PK
- seed: 151 exercises · 340 muscle rows · 460 alternatives · 170 contraindications; `pnpm --filter @fitos/api db:seed`

## APIS

- `GET /v1/exercises?q&equipment&muscle&pattern&limit&offset` — `{ items[], total, limit, offset }`; `equipment` comma-separated = what the user has; 422 on any unknown value or param
- `GET /v1/exercises/{id}` — summary + defaultIncrementKg, instructions[], videoUrl, muscles[{muscleGroup, role, contribution}], alternatives[{id, slug, name, reason, equipment}], contraindications[]
- Both: Bearer required (default-deny), §10 envelope

## TESTS

```
executed   pnpm -r test (packages)
           packages/core        105 passed   (unchanged)
           packages/contracts    19 passed   (+6: muscle groups = §12.3, csv equipment, bounds, seed entry)
executed   DATABASE_URL=… pnpm --filter @fitos/api test      (local PG 18)
           apps/api             113 passed, 0 skipped   (13 files; +25)
             seed.test             13   ≥120, unique slugs, ≥1 primary + ≥1 equipment, no dual-role muscle,
                                        refs exist, pattern+primary shared, symmetry (equip/pref) / one-way (injury),
                                        equipment alternatives differ, every exercise has an alternative,
                                        ≥3 per muscle and per pattern, reachability per kit, increments, unilateral text
             exercise.integration  11   seed applied (151), pagination, EQUIPMENT PERFORMABILITY (acceptance,
                                        exact set vs seed; two-item requirement), bodyweight always, muscle+pattern,
                                        search, 422s, detail, 404, seed idempotent (ids + updated_at), wholesale replace
             migrate.integration   12   (+1: 0002 CHECKs/PK/cascade; walks three migrations both ways)
executed   flutter test           98 passed   (+17)
             providers              6   query shape, csv sorted equipment, exclusive muscle/pattern, no local filtering,
                                        error not retry loop, detail cached per id
             screens                8   list+count, equipment toggle → request, exclusive muscle, debounce,
                                        empty → clear, failure → retry, detail contents (amber skip-if), alternative nav
             contract conformance  18   (+3: six exercise enums, three shapes, query param set)
executed   dart run custom_lint   No issues found
executed   flutter analyze --fatal-infos  clean;  dart format  0 changed;  build_runner  fresh
executed   pnpm typecheck / lint  clean
executed   docker compose up --build api → GET /v1/exercises → 401 (route present, protected)
executed   pnpm --filter @fitos/api db:seed (local) → seeded 151 exercises, 340 muscle rows, 460 alternatives, 170 contraindications
coverage   not measured — §18 gate
```

Spec §31 Phase 3 test requirements, each satisfied:

| Requirement | Where |
|---|---|
| seed integrity: every exercise has ≥1 primary muscle and ≥1 equipment | `seed.test.ts` (file); `migrate.integration.test.ts` (DB CHECK rejects empty equipment) |
| search filters | `exercise.integration.test.ts` (q, equipment, muscle, pattern, combined, 422s) |
| alternatives are symmetric where appropriate | `seed.test.ts` — equipment/preference symmetric, injury one-way, both asserted |

Acceptance: **151 ≥ 120 seeded** (asserted in file and through the API) ·
**filter by equipment returns only performable exercises** — asserted as
the exact set of seed entries whose required equipment ⊆ {given ∪ bodyweight},
plus the two-item case (band-assisted pull-up needs bar AND band).

**CI on `298d98c`:** `ci-core` success · `ci-api` success · `ci-mobile` success.

## KNOWN ISSUES

1. **Manual acceptance (§31 "browse and filter on device") not yet executed.**
   The local DB is seeded and the container rebuilt; the app needs a
   rebuild (new screens). Open TODAY → "Exercise library".
2. **Bodyweight alone cannot train biceps as a primary mover** (a chin-up
   needs a bar). Stated by a seed test rather than hidden; the Phase 4
   generator must handle a user with no equipment by treating biceps as
   covered by pulling secondaries or by saying so.
3. `videoUrl` is `null` for every seeded exercise. The column and contract
   exist; no videos are hosted. The detail screen shows nothing for it.
4. The library is fetched on every browser open (no client cache). §33 does
   not require it offline; Phase 5's active-session screen will need the
   exercises of the day cached, which is that phase's work.
5. `GET /exercises/{id}/history` (§10.1) is Phase 5 — it needs set logs.

## DEVIATIONS FROM SPEC

All deliberate; each with the reason.

- **The seed runner lives at `apps/api/src/db/seed.ts`, not `scripts/seed.ts`
  (§29).** It needs the API's Drizzle schema and client; `scripts/` is not
  a workspace member. Documented in `scripts/README.md`; moves when
  `rebuild-derived.ts` (Phase 12) forces `scripts/` to become a package.
- **Equipment filter semantics are "what I have", not "tagged with".**
  §10.1 says only `?equipment`; the acceptance rule ("returns only
  performable exercises") makes subset-of-available the only reading that
  satisfies it. Bodyweight is always in the available set.
- **Muscle groups are the ten §12.3 rows, no forearms/traps/etc.** A muscle
  without a landmark cannot be programmed to a volume; rows/deadlifts credit
  `back`. Extending the list later is one `ALTER TYPE ADD VALUE`.
- **Fifteen movement patterns rather than an open string.** §9.2 lists the
  column, not the values; the generator needs a closed set to select by.
- **`exercise_alternatives` PK includes `reason`** so the same pair can be
  both an equipment and a preference alternative.
- **Some "equipment" is an interpretation of the eight-item onboarding
  list:** inverted row and landmine press are `barbell` (a bar in a rack /
  corner), back extension and preacher curl are `machine` (they need the
  apparatus), dips are only the bench dip (`bodyweight`). Adding `bench` or
  `dip-station` to the enum would change onboarding and is left for a
  phase that needs it.
- **Instructions are `text[]`, not a single text.** They render numbered;
  the seed schema requires ≥2 steps.
- **List responses are offset-paginated with `total`.** §10 sets no
  pagination convention; 151 rows fit one page (`limit` max 200), and the
  client asks for 200 and shows "n of total" when the server sends fewer.

## NEXT PHASE

- **Phase 4: Program generation** — `programs`, `program_days`,
  `planned_exercises`; the generator per §12.2 (split by days×experience,
  equipment filter, contraindication exclusion, MEV by pattern,
  compound-first, fit to session minutes); tests over every
  (days × experience × goal) combination. Not started.

**Blockers:**

1. **Manual acceptance on the emulator** — owner: browse and filter on
   device (rebuild the app first).
2. Phase 4 needs a decision on the bodyweight-only biceps gap (known issue 2):
   accept "covered by pull secondaries" or require a bar/band for a full
   programme. I will propose the former in Phase 4 unless told otherwise.
3. Neon dev still has no migrations or seed applied. Not blocking.
