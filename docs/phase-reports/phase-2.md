# PHASE 2 COMPLETE — Profile, goals & targets

**Date** 2026-09-21 · **Commits** `025d2d2` (core goals + build), `9a8faa5` (backend), `8965619` (Flutter + contract conformance), `678e164` (ci-api fix), plus this report's commit
**Head** pushed to `origin/main` · **CI** `678e164`: `ci-core` success · `ci-api` success · `ci-mobile` in progress at time of writing (success on `8965619`, identical mobile code)

---

## IMPLEMENTED

Everything below was verified by executing it. Backend tests run against a
real Postgres 18; the Docker image was built and booted locally against it.

**`packages/core` (two approved, scoped changes only)**
- `nutrition/targets.ts`: `Goal` gains `recomposition` (−5 % offset, 2.2 g/kg
  protein) and `maintenance` (0 %, 1.6 g/kg); the nested rationale ternary
  became an exhaustive `switch`. Four tests added; 105 core tests green.
- A build step (`tsconfig.build.json`, `exports` → `dist/`). No other file
  under `src/` touched.

**Backend**
- Migration `0001_profile_goals_targets`: nine tables, fifteen enum types
  built from the same literal arrays as the Zod contract. `user_goals` has a
  partial unique index (one active goal per user — a database fact).
  `consent_records` is append-only by construction (no update method
  exists). `nutrition_targets` is a history with the engine's rationale
  stored beside the numbers it explains. `body_metrics` pulled forward from
  Phase 12 (see deviations). Hand-written down script; the migration suite
  walks 0001 → 0000 → nothing → both and proves one-active-goal, enum
  rejection and cascade delete at the DB level.
- Onboarding state machine that is *derived*, not stored: the next step is
  computed from what rows exist on every read, so "back always works" and
  "resumes after a kill" are true by construction. `/answer` stores the
  stage capped at `vit`; only `/complete` writes `complete`. `/complete`
  refuses with the missing steps named (409) until every required step is
  answered, then computes **real** targets via `computeTargets`.
- `about` step: 18+ enforced to the day in the user's time zone; both consent
  types at the current policy version required and recorded (with a salted IP
  hash) **before** any body data is written; a rejected step stores nothing.
- `/user/profile` GET/PATCH (PATCH of a formula input recomputes targets),
  `/user/goal` GET/PUT (closes the old goal, opens the new, recomputes),
  `/user/diet-preferences` GET/PUT (allergies replaced wholesale),
  `/user/preferences` GET/PATCH. Every write rejects unknown keys.
- `targets.service.ts` is the only caller of `computeTargets` (§7.3, §30).
- Session user carries `onboardingStage` so the client can route on it.
- Default-deny sweep now covers 13 protected routes with no test change.

**Flutter**
- Seven screens (§32): goal · about (sex, DOB, height, weight, consent) ·
  experience (+ activity level, see deviations) · training (location,
  equipment) · food (diet type, allergies with severity) · VIT mess (the six
  real messes from core's config; "No" skips) · plan. Frame widget carries
  "STEP n OF 7", sticky Back/Continue, inline failure in oxide. Choice lists
  are hairlines and an ink bar, no cards, no radio circles (§6).
- Screen 7 calls `/onboarding/complete` on arrival and renders the engine's
  targets and rationale verbatim. The first training week says it arrives
  with the programme builder (Phase 4) instead of faking one.
- Route guard: signed in with stage ≠ `complete` → `/onboarding` from
  anywhere; onboarded users are kept off auth/splash only so screen 7 stays
  on screen after `/complete` marks the session; "Start" leaves explicitly.
- Profile screen (facts, active goal, targets with effective date and
  reason, change goal, sign out) and goal editor (PUT, shows the recomputed
  targets before leaving). TODAY links to the profile.
- Hand-written freezed DTOs and closed vocabularies mirroring
  `@fitos/contracts` (ADR-004, proposed). `test/contracts/contract_conformance_test.dart`
  reads `packages/contracts/openapi.json` and fails `ci-mobile` if any enum,
  response property set or request property set drifts. This is what makes
  "hand-written" safe.
- Load providers opt out of Riverpod 3's silent retry-with-backoff (which
  reports `isLoading` for ~13 s) so a failed load shows its message and
  "Try again" at once (§6.6).
- `guards.dart`: the BOM and mojibake that shipped in Phase 1 are gone.

## FILES

**created** — `packages/core/tsconfig.build.json`; `packages/contracts/src/{profile,onboarding,onboarding.test}.ts`;
`database/migrations/{0001_profile_goals_targets.sql,down/0001_profile_goals_targets.down.sql,meta/0001_snapshot.json}`;
`apps/api/src/db/schema/{enums,profile,diet,records}.ts`; `apps/api/src/lib/objects.ts`;
`apps/api/src/modules/user/{repository,service,routes,targets.service,targets.service.test,user.integration.test}.ts`;
`apps/api/src/modules/onboarding/{service,service.test,routes,onboarding.integration.test}.ts`;
`apps/mobile/lib/features/onboarding/**` (domain 2 + 2 generated, data 1, presentation: controller, flow screen, 7 steps, step frame);
`apps/mobile/lib/features/profile/**` (vocabulary, profile entities + 2 generated, repository/controller, profile screen, goal editor, targets display);
`apps/mobile/test/{contracts/contract_conformance_test.dart,support/fake_onboarding_repository.dart,features/onboarding/{onboarding_controller,onboarding_flow_screen}_test.dart}`;
`docs/decisions/ADR-004-dart-client-generation.md`; `docs/phase-reports/phase-2.md`

**modified** — `packages/core/{package.json,src/nutrition/targets.ts,test/engines.test.ts}`; `packages/contracts/{package.json,openapi.json,src/{index,auth}.ts}`;
`apps/api/{package.json,drizzle.config.ts,vitest.config.ts,src/{app.ts,db/{schema,migrate,migrate.integration.test}.ts,lib/env.ts,plugins/auth.ts,scripts/export-openapi.ts,test/build-test-app.ts,modules/auth/{repository,service,service.test}.ts}}`;
`database/migrations/meta/_journal.json`;
`apps/mobile/lib/{core/routing/{guards,router}.dart,features/auth/{data/auth_repository_impl,domain/entities/user_profile(+2 generated),domain/repositories/auth_repository,presentation/controllers/auth_controller}.dart,features/today/**}`;
`apps/mobile/test/{widget_test,core/routing/guards_test,support/fake_auth_repository}.dart`; `.gitignore`

**removed** — nothing

## DATABASE

- migrations: `0001_profile_goals_targets` (up via drizzle-kit from the compiled schema; down hand-written; both verified on PG 18)
- enum types (15): goal_type, sex, experience_level, activity_level, diet_type, training_location, equipment, allergen, allergy_severity, body_part, units, budget_tier, onboarding_stage, consent_type, targets_reason
- tables:
  - `user_profiles` — 1:1 with users; sex, birth_date, height_cm, experience_level, training_days_per_week, activity_level, preferred_session_minutes, training_location, equipment[], is_vit_student, mess_provider_id/hostel_id/mess_id, onboarding_stage (default `goal`)
  - `user_goals` — goal_type, target_weight_kg, started_at, ended_at; **partial unique `one_active_goal` WHERE ended_at IS NULL**
  - `user_preferences` — units, notification_settings jsonb, feature_flags jsonb
  - `diet_preferences` — diet_type, excluded_dish_ids[], budget_tier
  - `user_allergies` — allergen, severity; unique (user_id, allergen)
  - `user_limitations` — body_part, note
  - `consent_records` — consent_type, policy_version, granted_at, ip_hash; append-only
  - `nutrition_targets` — effective_from, kcal, protein_g, carb_g, fat_g, fiber_g, bmr, tdee_estimate, rationale jsonb, reason; history
  - `body_metrics` — measured_on, weight_kg; unique (user_id, measured_on)
- all FKs `ON DELETE CASCADE` to `users`; verified by test

## APIS

- `GET /v1/onboarding/state` — derived state: stage, completed, answered[], missing[], profile, goalType, dietType, allergies, policyVersion
- `POST /v1/onboarding/answer` — discriminated on `step` (goal | about | experience | training | food | vit); returns the new state; 422 on under-18, future DOB, missing or stale consent
- `POST /v1/onboarding/complete` — 409 `{ missing }` until required steps are answered; computes and persists targets; `{ profile, goal, targets }`
- `GET|PATCH /v1/user/profile` — PATCH of heightCm / trainingDaysPerWeek / activityLevel recomputes targets if any exist
- `GET|PUT /v1/user/goal` — `{ goal, targets | null }`; PUT closes the active goal and recomputes; GET 404 before onboarding
- `GET|PUT /v1/user/diet-preferences` — allergies replaced wholesale
- `GET|PATCH /v1/user/preferences`
- All: Bearer required (default-deny), §10 envelope, `.strict()` bodies (unknown keys → 422)

## TESTS

```
executed   pnpm -r test (packages)
           packages/core        105 passed   (+4: recomposition/maintenance offsets, protein, rationale)
           packages/contracts    13 passed   (+6: onboarding discriminator, consent, stage)
executed   DATABASE_URL=… pnpm --filter @fitos/api test      (local PG 18)
           apps/api              87 passed, 0 skipped   (11 files)
             migrate.integration   11   0001 up/down/up, enum rejection, one-active-goal, cascade
             onboarding.integration 22  Persona C manual calc, resume, back, under-18, 18-today,
                                        consent rows + hash, partial/stale consent 422, complete 409,
                                        session stage not 'complete' until /complete
             user.integration      goal change recomputes; protein ≤ 2.2 g/kg for all 6 goals via PUT
             targets.service / onboarding service unit tests; default-deny sweep 13 routes
executed   flutter test           81 passed   (+39)
             contract conformance  15   every enum, response and request shape vs openapi.json
             guards                +5   onboarding redirect matrix, screen-7 stays
             onboarding controller  7   pipe semantics, complete marks session, wire shapes
             flow screen            5   rejection keeps the form, resume opens on server step, Back is local
             full app              +3   resume → STEP 4, new sign-up → STEP 1, screen 7 → Start → TODAY
executed   dart run custom_lint   No issues found
executed   flutter analyze --fatal-infos  clean;  dart format  0 changed;  build_runner  fresh
executed   pnpm typecheck / lint  clean (typecheck re-verified with packages/*/dist deleted)
executed   docker build docker/Dockerfile.api → boot against local PG:
             GET  /health              → 200
             POST /v1/auth/session     → 401
             GET  /v1/onboarding/state → 401
coverage   not measured — §18 gate
```

Spec §31 Phase 2 test requirements, each satisfied:

| Requirement | Where |
|---|---|
| target computation per goal | `packages/core/test/engines.test.ts`; `targets.service.test.ts`; `user.integration.test.ts` (all six goals through the API) |
| **protein never exceeds 2.2 g/kg** | `user.integration.test.ts` — asserted for every goal after PUT `/user/goal` |
| onboarding resumes after interruption | `onboarding.integration.test.ts` (state recomputed from rows); `onboarding_flow_screen_test.dart` + `widget_test.dart` (opens on the server's step) |
| under-18 birth date is rejected | `onboarding.integration.test.ts` (17 y 364 d rejected, 18 today accepted); `onboarding_flow_screen_test.dart` (rejection stays on the form) |

Acceptance: onboarding is 7 screens and ends in a real target (Persona C:
BMR 1348, TDEE 2069, 2276 kcal, 106 P / 337 C / 56 F, verified by hand);
targets recompute on goal change (PUT test + goal editor); consent recorded
with the policy version (rows asserted incl. IP hash).

**CI:** `8965619` — `ci-core` success · `ci-mobile` success (81 tests, conformance suite, APK) · `ci-api` **failure** at Typecheck. Cause: `packages/core` now exports from `dist/` and the API scripts only pre-built `@fitos/contracts`; a clean checkout had no core dist. Fixed in `678e164` (`deps:build` builds both; verified locally with dist removed and by booting the image). On `678e164`: `ci-core` success · `ci-api` **success** (87/87, 0 skipped on the PG 18 service, image booted) · `ci-mobile` in progress when this report was committed; it passed on `8965619` and no mobile file changed since.

## KNOWN ISSUES

1. **Manual acceptance (§31 "complete onboarding; verify plausible targets
   against a manual calculation") has not been executed on the emulator.**
   The Docker image is rebuilt and boots; the owner runs the flow. The
   expected numbers for Persona C are above.
2. **ADR-004 is PROPOSED, not accepted.** Hand-written DTOs + the conformance
   test are in place; the owner ratifies or reverts. §7.1 names
   openapi-generator; the ADR records why its output was unusable.
3. **Time zone is still not sent by the client.** Every user gets
   `Asia/Kolkata`; "today" for the 18+ check and `effective_from` is computed
   in that zone. `flutter_timezone` + a profile setting remain open.
4. Profile facts are read-only on the client apart from the goal. Editing
   height/weight/diet lands with the features that need them (weight → Phase
   12 trend, diet → Phase 9 mess).
5. `user_limitations` has a table and no API or screen; §32 leaves it out of
   the 7 screens and nothing reads it until Phase 4.
6. Screen 6's mess list is a static mirror of core's `vit/config.ts` until
   Phase 9 ships `GET /mess/providers/{slug}/messes`.

## DEVIATIONS FROM SPEC

All deliberate; each with the reason.

- **`body_metrics` pulled forward from Phase 12.** The onboarding weight
  needed a home the trend engine will read; a `weight_kg` column on the
  profile would have been thrown away later.
- **Activity level is asked on screen 3 (experience), not a screen of its
  own.** §32 caps at 7 screens; Mifflin-St Jeor needs activity; experience
  and activity are one question about the same week.
- **`user_profiles` carries `training_location`, `equipment`, `is_vit_student`
  and the mess reference.** §32 asks them; §9 does not list columns for
  them; the profile is where the generator (Phase 4) and mess (Phase 9) will
  read them.
- **`OnboardingState.completed` and `userProfileSchema.onboardingStage`
  added to the contracts.** Not in §10.1; the client needs a stage to route
  on without a second round-trip, and `completed` distinguishes "all
  answered" from "targets computed".
- **Stored stage caps at `vit` until `/complete`.** Answering the last step
  must not mark the session complete or the client would route to TODAY
  before the plan was ever computed.
- **Onboarded users may stay on `/onboarding`.** The guard only forces them
  off auth/splash; otherwise screen 7 would be yanked away the instant
  `/complete` marked the session.
- **Dart DTOs are hand-written with a conformance test (ADR-004), not
  generated.** openapi-generator's dart-dio output from the fastify-zod
  document had zero named schemas, route-named models and `AnyOf get anyOf`
  for the answer union. Pending ratification.
- **Riverpod 3 automatic retry disabled on load providers.** It reports
  `isLoading` through ~13 s of back-off; §6.6 wants the failure shown.
- **`GET /user/goal` is 404 before onboarding**, rather than `{ goal: null }`.
  A missing goal is a not-found, and the client never asks before onboarding.
- **Client does not send a time zone** (carried from Phase 1; see known issues).

## NEXT PHASE

- **Phase 3: Exercise database** — exercise tables, 120+ seeded exercises
  with muscles/alternatives/contraindications, search API, browser UI, seed
  integrity tests. Not started.

**Blockers:**

1. **Manual acceptance on the emulator** — owner: complete onboarding and
   compare screen 7 to the numbers above.
2. **ADR-004 ratification** — owner decision; nothing in Phase 3 depends on
   the answer but the longer it waits the more DTOs exist.
3. Neon dev has neither migration applied; local Docker is what every test
   ran on. Not blocking Phase 3.
4. §36 Q2 (Cloud Run region) still open; gates the first deploy, not Phase 3.
