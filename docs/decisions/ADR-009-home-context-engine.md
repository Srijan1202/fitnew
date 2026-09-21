# ADR-009 — Home: a device-side deterministic context engine, and the Home redesign

**Status** ACCEPTED — owner decisions D3–D6 approved 2026-09-22 (Phase 6.5)
**Date** 2026-09-22
**Phase** 6.5
**Affects** MASTER-SPEC.md §16 (TODAY system — Phase 11 engine), §30 (business-logic ownership — bounded exception), §31 (Phase 6.5), §6 (Home layout)

---

## Context

§16 makes TODAY a server engine over the full `UserModel` (Phase 11). §30
says no fitness logic in Dart. Phase 6.5 needs "what should I do next?"
on Home *now*, and part of its input — the Health Connect snapshot —
must never leave the phone (ADR-008). Those three facts conflict; this
record resolves the conflict deliberately.

## Decisions

### 1. The Home engine runs in Dart, as a bounded exception to §30 (D3)

`HomeSuggestionEngine` (`lib/features/home/domain/`) is pure Dart with
no Flutter imports: twelve ordered rules over a `HomeContext`. It
**compares and orders**; it computes no fitness number. Every quantity it
looks at was computed elsewhere: the server's `/today` (session state,
recommendations, deload offer, neglect), `/volume` statuses, the profile
targets, and the health snapshot. The rules use the §16.1 priority bands
so that when Phase 11 wires the server engine, the ordering intent is
already the same and the Dart engine can shrink to "the rules that need
device-only data". No LLM anywhere in the path; the priority is never
shown.

Rules and bands: deload offered 95 → active workout 92 → scheduled
workout 90 → protein < 75 % of target 88 → calories left with protein on
track 75 → workout done 70 → neglected muscles 68 → sleep < 6 h 65 →
rest day 60 → PR today 50 → volume at MRV 45 → steps behind goal 40 →
Health Connect present but not connected 35. Ties keep rule order.
`eat-protein` XOR `eat-meal`; deload suppresses rest-day (§16.1). Rules
never fire on missing data. The carousel is the first four primary
suggestions; "More for you" is the rest (secondary ones — connect
health, volume — only appear there).

### 2. Thresholds are owner decisions, advisory, not scores (D4, D5)

- Step goal: 8,000 by default, kept in shared_preferences, editable on
  the Health Data screen. Movement fires under half the goal after 15:00
  local, or under the goal after 19:00.
- Sleep: under 6 h → "Keep today's session controlled" (training day) /
  "An easy day is a good day". Resting heart rate is shown, never judged
  (no baseline yet). No readiness score of any kind — Phase 13 owns that.

### 3. Nutrition is honestly absent until Phase 8 (D6)

`NutritionContext.notLogged` is what Home receives today. The Food block
reads "Not logged yet · Target 1,800 kcal · 120 g protein"; the food
rules cannot fire; "Log food" opens the Nutrition tab placeholder; the
week's Nutrition row is omitted rather than shown as 0 / 7.

### 4. Home information architecture

Header (greeting by local hour, date, profile) → "Your next move"
carousel → Today (Steps · Active calories · Food · Workout) → Recovery
(Sleep · Resting HR) → Body (only when a body metric is granted) → This
week (Training n / planned, Movement n / 7, Sleep n / 7) → "Training
volume →" → "More for you" → a freshness footer. Editorial: hairlines,
the display face for numbers, cards only in the carousel; every missing
value states its reason. Sign-out moved to Profile. Pull-to-refresh
refetches today, volume, history and the health snapshot.

### 5. Floating bottom bar

Same five destinations and shell; the bar now floats above the safe area
(paper at 88 % over a 12 px blur, hairline, restrained shadow, medium
radius, 60 px content, 12 / 10 px insets; `Scaffold.extendBody`).

## Consequences

- §30 gains a footnote: device-side *ordering* over server-computed
  numbers and device-only health data is permitted in
  `lib/features/home/domain`; fitness arithmetic still is not.
- Phase 11 reconciles: the server engine emits the same bands; the Dart
  engine keeps only rules that need the health snapshot.
- 16 engine tests pin every rule and the order; 10 Home widget tests pin
  every empty state.
