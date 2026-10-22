# ADR-030 — Skip today: the whole week moves one day later

**Status:** PROPOSED. Owner decision 2026-10-22; built on `phase-19`. Becomes ACCEPTED when the owner has checked it on the S24.
**Date:** 2026-10-22
**Phase:** 19 (beta; owner request, not in MASTER-SPEC §31)
**Affects:**
- MASTER-SPEC §12 (the weekly programme) and §9.3 (`programs.skipped_on`, the weekday constraint);
- §10.1 (`POST`/`DELETE /training/today/skip`), §16 (TODAY on a skipped day), Phase 15 (reminders).

---

## Context

The owner (2026-10-22): "an option to skip this day, so the routine moves on, leaving that day; everything rotates by one day. People do four days on, then one day of rest."

The programme is a week of seven days, each on a weekday, so "skip" had to be defined. The owner chose, from three options:
- **this one:** shift the whole week, permanently;
- push to the next rest day, this week only;
- a rolling cycle not tied to weekdays.

## Decisions

| # | Decision |
|---|---|
| D1 | **Skip today** moves every day of the active programme one weekday later: Sunday's goes to Monday, rest days included. Day ids, exercises and order are unchanged, so history, progression and the mesocycle are unaffected. It is one transaction: `program_days_program_day` is now a `DEFERRABLE` unique constraint (migration 0023), checked at commit. |
| D2 | **Today is skipped:** `programs.skipped_on` holds the date. `GET /training/today` for that date returns `skipped: true` with no session (that weekday now holds yesterday's). TODAY shows a rest day, and the reminders plan neither a workout reminder that day nor a "missed session" the next morning (core `PlanFacts.skippedDates`). |
| D3 | **Rules:** only today, only on the active programme, once a day (`409 already-skipped`). Refused while a session is open (`session-open`) and after a session was completed today (`trained-today`). **Undo** (`DELETE`) moves every day back and clears the date, only on the same day (`409 not-skipped`). Both need a connection. |
| D4 | **In the app:** Training → ⋯ → "Skip today" appears when today is a training day not yet skipped. A confirmation says what moves. Afterwards the snackbar has Undo, today's tab shows "Skipped — tomorrow is {session}" with Undo skip, and Home's workout tile says "Skipped". |

## Consequences

**Good:**
- Missing a day never breaks the routine's order. A four-days-on user can skip whenever life intervenes and keep the sequence.
- No new model: still a week of seven days, so everything that reads it keeps working.

**Bad / accepted:**
- **The weekdays drift.** After a skip, Push is no longer on Monday. That is the point, but it is visible in the week strip.
- **Only today can be skipped,** not a future day. A rolling cycle (option 3) stays a possible later phase.
