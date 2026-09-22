# ADR-011 — Body weight: the FITOS value is the user's; Health Connect's stays on the phone

**Status** ACCEPTED for the closed alpha (Phase 6.6 Gate 7) — revisit before any automatic sync of health data
**Date** 2026-09-23
**Affects** MASTER-SPEC §9 (`body_metrics`), §10.1 (`PATCH /user/profile`), §19.4 / ADR-010 (privacy boundary), ADR-008 (Health Connect on device), owner decision B4

## Context

FITOS already stores weight as dated readings in `body_metrics`
(`measured_on`, `weight_kg`, `source` ∈ `onboarding | manual | health-sync`,
one reading per user per day, soft-deletable). The latest reading feeds the
nutrition-target formula; `latestWeightKg` on the profile is that reading.

Phase 6.5 reads a weight from Health Connect on the phone (ADR-008). Owner
decision B4 (Phase 6.6) forbids sending Health Connect data to the backend
or the model. Gate 7 adds a Profile → Personal details editor where the
user can change their weight — so there are now two weights a user can see.

No source precedence had been defined.

## Decision

1. **The FITOS weight is the user's.** `PATCH /user/profile { weightKg }`
   records it as today's `body_metrics` reading with `source = manual`
   (a second entry the same day replaces the first; earlier days are
   history and are never rewritten). Targets are recomputed on the server
   (`reason = weight-change`); the app never computes or writes a target.
2. **Health Connect's weight is the phone's.** It is shown next to the
   weight field as "Health Connect on this phone: 56.8 kg · date — it stays
   on the phone; enter it above if you want FITOS to use it." It is never
   sent, never copied into the field automatically, and never overwrites
   the FITOS value.
3. **No automatic precedence.** Neither value silently replaces the other.
   The user decides by typing the number they want FITOS to use.
4. `source = health-sync` stays unused until the owner lifts B4 for weight
   specifically.

## Why not a one-tap "Use this weight"

It would be convenient, but it is exactly a path by which a Health Connect
value reaches the FITOS server. Under B4 that needs the owner's explicit
decision, not a UI shortcut. Typing the number is the user's own entry.

## If B4 is lifted for weight later

The smallest next step is a user-confirmed import: "Use 56.8 kg (Health
Connect, 22 Sep)" → one `manual`-equivalent reading with
`source = health-sync` and the measurement date, never an automatic sync,
and the Profile shows which source the current value came from.
