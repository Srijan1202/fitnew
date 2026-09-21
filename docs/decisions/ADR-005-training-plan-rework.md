# ADR-005 — Training plan: professional templates, one-day-at-a-time architecture, planned sets

**Status** ACCEPTED — decided by the owner 2026-09-21 after manual review of the first Phase 4 build
**Date** 2026-09-21
**Phase** 4 (rework)
**Affects** MASTER-SPEC.md §31 Phase 4 ("UI: weekly plan, program editor, custom builder"), §9.2 (programme tables), §10.1 (`/training/*`)

---

## Context

The first Phase 4 build satisfied §31's letter — a generator, three
endpoints, a "weekly plan" screen — and failed as a product. The owner's
review: the plan read as a data dump (all seven days stacked on one page),
there was no way to prescribe or record what happens set by set, generated
push/pull days routinely held three exercises, and users had only two ways
in (generate, or build from scratch). The generator itself was sound.

Four decisions came out of that review. This ADR records them so later
phases (Phase 5 logging above all) build on them rather than around them.

## Decisions

### 1. Three entry modes: Generate, Professional, Custom

A programme comes from one of three deliberate modes, presented as three
panels, never as three buttons:

- **Generate** — the deterministic `packages/core` generator, unchanged in
  kind (§12.2 split table, §12.3 landmarks, equipment/limitation filters,
  shortfalls). No LLM, then or later.
- **Professional** — a library of recognisable training structures
  (push/pull/legs, bro split, upper/lower, full body, push/pull, two muscle
  groups a day, 5-day bodybuilding, 3-day full body, 4-day upper/lower,
  6-day push/pull/legs). **Templates are structure only** — days, session
  names, the muscles each session owns, the movement patterns it must
  contain. Exercises are chosen for the user by the same engine that
  generates plans (`materializeTemplate` → `buildProgram`), against the
  user's equipment, limitations and level, with the same volume caps and
  the same honest shortfalls. A template is previewed (nothing stored)
  before it is applied. No template is described as best, optimal or
  scientifically superior; they are structures people already know.
- **Custom** — the user's own: days → day details → muscle groups →
  exercises → sets/reps/starting weight → save. Reorder by drag.

### 2. One day at a time

The plan screen shows a fixed day selector (MON … SUN; ● selected, ○
training, — rest) and **only the selected day**. The week is never rendered
as a single vertical page. Each exercise is a card with two states:
collapsed (number, name, primary muscle, sets × reps, starting weight) and
expanded (every set editable in place, equipment, instructions fetched on
first open, the generator's reason, replace / remove). Progressive
disclosure; nothing navigates away to change a number.

### 3. `planned_sets`: per-set plan targets, edited on the day screen

`planned_exercises` stays the parent prescription (sets × rep range × RIR
× increment) that the progression engine reads. Underneath it,
**`planned_sets`** holds one row per set — `reps_min`, `reps_max`
(collapsed to one number when the user pins it), `weight_kg` (nullable),
`rir`. Generated and template programmes write uniform rows from the
prescription with **`weight_kg = NULL`**: the generator never invents a
load (§12.4 rule 1, "no history → establish baseline"). The user types a
starting weight per set on the expanded card; edits are held as a per-day
draft and sent as one PATCH after a short pause, flushed at once on
leaving the screen, retried on failure, never silently lost.

### 4. Plan targets are not actuals

What `planned_sets` holds is the **plan**: the target for that set today.
What the lifter **actually did** — reps, load, RIR, the set as performed —
is Phase 5's `set_logs` (§9.2), recorded per `workout_session` with
`client_set_id` idempotency and the §33 offline queue. Phase 5 overlays
actuals on this structure: a session starts from the day's `planned_sets`,
each logged set references its planned set, and progression (§12.4) reads
`set_logs`, not `planned_sets`. Nothing in this rework implements sessions,
logging, PRs, deloads or mesocycle advancement.

## Generator refinements made under this ADR

Measured before the change (60-min sessions, 3–6 days × 3 levels × 4
goals, full gym): pull sessions had a median of **3** exercises, and **40**
sessions lacked any direct exercise for a muscle the day owned (mostly no
triceps work on push/upper days — bench and press secondaries satisfied the
number). Two rules fixed it without touching the MEV/MAV framework:

- **Direct coverage** — each muscle a session owns gets at least one
  exercise with it as a primary mover whenever a performable one exists.
  Secondaries still count 0.5 sets toward volume; they never satisfy
  coverage. Pull days require a horizontal *and* a vertical pull, and
  prefer rear-delt work for the shoulder slot. A muscle with no performable
  primary (bodyweight-only biceps) stays a shortfall, as the owner decided
  earlier.
- **Exercise count** — a session aims for `min(5, ⌊minutes / 12⌋)`
  movements, adding more only where a muscle still has room under its
  MAV-low share. Volume caps, time ceilings, equipment and limitations are
  never traded for count. Where the cap binds (six-day PPL in week 1) the
  session is shorter and the rationale says why.

After: no session in the matrix at ≤ 3 exercises; coverage gaps 40 → 0.

## Consequences

- §31 Phase 4's "weekly plan" is delivered as a day-selector screen; the
  spec's wording is read as intent (see the week), not layout (see it all
  at once).
- The professional library is an addition to the spec; it lives in
  `packages/core/src/training/templates.ts` as data and shares the engine,
  so it can never violate an equipment constraint the generator honours.
- Migration `0004`: `planned_sets`, `programs.template_slug`,
  `program_source += 'template'`, nine new `split_type` values. Its down
  script rebuilds both enum types (Postgres cannot drop a value) after
  removing rows only the new schema can hold.
- Phase 5 must: create sessions from `planned_sets`; write actuals to
  `set_logs` with a reference to the planned set; leave `planned_sets`
  untouched by logging; advance `mesocycle_week` on completion.
