## PHASE 15 — NOTIFICATIONS — IMPLEMENTATION COMPLETE, S24 ACCEPTANCE PENDING

**Date** 2026-10-21 · **Branch** `phase-15` from `926c48b` (Phase 14, itself not yet accepted) · **not merged**

**Status:** **implemented and tested; NOT accepted, NOT frozen.**
- The S24 manual checks (§7) have not been run.
- §38 Phase 15 is not ticked; ADR-021 is PROPOSED.

**Commits**
- `b1d2e7f` — core `notify/`: time and habits, the copy bank with guardrails, the planner; tests
- `08d3cfe` — contracts `notifications.ts`; OpenAPI
- `b5fde46` — API `/notifications/*`, migration 0018 (`notifications`, `push_tokens`) with a down; integration and migration tests
- `e47e94b` — mobile: scheduling, cancel-on-activity, taps and Snooze, FCM token, Profile → Notifications; tests
- `f914faa` — the Sunday recap moved to 16:00 (found by printing a sample week, §5)
- plus the documentation commit: this report, the plan, ADR-021, the MASTER-SPEC and BACKLOG amendments

**Decision record:** [plan](../phase-plans/phase-15-plan.md), [ADR-021](../decisions/ADR-021-notifications.md) (D1–D7).

**Owner decisions (2026-10-21):**
- Duolingo-style and "all and more";
- the phone schedules (option A);
- **Cheeky** tone (amends §21's no-guilt rule);
- **keep 2 a day**.

### 1. WHAT MASTER-SPEC REQUIRES (and where it is)

| Requirement (§21, §31, §9.2, §38) | Built |
|---|---|
| FCM registration | `POST /notifications/token` → `push_tokens`; `firebase_messaging` 16.7.0 |
| Scheduled notifications | server plan (core `notify/planner.ts`) → scheduled on the phone (Cloud Scheduler replaced, ADR-021 D1) |
| Local rest timers | unchanged; now share one plugin set-up with the reminders |
| Preferences, every kind toggleable | `/notifications/settings`; Profile → Notifications |
| ≤ 2 a day | planner cap (already-sent ones counted), 3 h apart, quiet hours |
| No copy from an LLM | a fixed template bank; tests check every planned item is a template |
| No shame framing | **amended by the owner** (Cheeky). Guardrails tested in every tone: nothing about the body, no food guilt, no insults |
| `notifications` table | migration 0018, the plan's ledger with outcomes |

### 2. THE TECHNIQUES

- **Learned timing:** around when *you* train, log dinner, weigh in and check in (the median of the last 5 weeks).
- **Only when useful:** no workout reminder once you have started or on a rest day; no protein nudge once you reach 75 %; no streak saver once you have logged.
  - **Cancelled on the phone the instant you do the thing**, offline too.
- **2 a day, 3 h apart, never in quiet hours;** the most useful ones first.
- **Back-off:** ignored 3 times → every other day; 6 → a week off; any open resets.
- **Fresh words that learn:** no repeat within a week; the variants you open most win; words with your data (your session, your streak, your target) lead.
- **Comeback arc:** day 2, day 4, and on day 7 "These reminders don't seem to be working. So we'll stop for now."
- **Readiness-aware:** gentle words on a low-readiness day, no workout reminder on a rest-band day.
- **Snooze 1 h** on the notification; a tap opens the right screen (the protein nudge opens dinner logging).
- **Transparency:** "Coming up" with *why* for each, and "Send me a sample".

### 3. ACCEPTANCE (automated)

| Criterion | Evidence |
|---|---|
| ≤ 2 a day | core: across settings and a 7-day programme; already-sent counted. API: per day in the real plan |
| Every kind toggleable, preferences respected | core and API: a kind off never appears; everything off empties the plan and the future ledger; mobile: each switch sends just its change |
| No LLM copy | every planned item's variant is a TEMPLATES entry, rendered; no model is called |
| Guardrails | a banned-words test over every template |
| Phone side | cancel on activity (offline), protein reached, comeback on open, outcomes reported once, permission asked once, a tap opens the screen, the plan survives a restart |

### 4. TESTS

| Suite | Count | New for Phase 15 |
|---|---|---|
| core | 914 | `test/notify.test.ts` (24) |
| contracts | 86 | `notifications.test.ts` (4) |
| API | 483 | notifications integration (9), migration 0018 |
| Flutter | 675 | coordinator (8), settings screen incl. 360 px and 411 px at 2× text (7), conformance (3) |

`flutter analyze --fatal-infos`, TypeScript typecheck and lint: clean. OpenAPI exported.

### 5. A SAMPLE WEEK (planner output for a persona)

A user who trains Push/Pull/Legs at about 18:40 and logs dinner at about 20:15, planned at 08:10 on a Monday:
- *Mon 17:40* "Psst. Push." · *Mon 21:00* "21 days. Don't blink. — Nothing logged today. Your streak has until midnight."
- *Tue 08:20* "Push sends its regards" (cancelled if Push was logged) · *Tue 19:30* "Protein called. You missed it."
- *Wed 12:30* "Your plan is getting dusty" (only if the app was not opened) · *Wed 17:40* "Gym > scrolling — … Pull starts in about an hour."
- *Mon +7 12:30* "These reminders don't seem to be working — So we'll stop for now."

Printing this found one fault: the Sunday recap never fitted beside the evening protein nudge. It was fixed in `f914faa`.

### 6. KNOWN LIMITS AND OPEN ITEMS

- **A plan is as fresh as the last sync.** Reminders already on the phone fire even if the PC is off. A change made on another device reaches this phone only when it next syncs. Server push (O9) needs hosting.
- **Learned times need history:** 3 sessions (2 on that weekday), 3 dinner logs. Until then: 17:00 workout reminder, 19:00 protein nudge, 08:30 mornings.
- **Android may delay inexact alarms** when exact alarms are not allowed. FITOS uses exact alarms when the phone permits.
- Not built: dish names in the protein nudge (E17); a notification centre.
- **Still open from before:** O2, O3, O6, O7, O8; Phases 13 and 14 S24 runs.

### 7. S24 MANUAL CHECKLIST

**Setup**
- **APK:** `Downloads\fitos-phase15-f914faa-lan-10.195.252.11.apk` (`phase-15`, API host `http://10.195.252.11:8080`; rebuilt after the LAN IP changed from 172.16.205.231). It includes Phase 14.
- **API:** container rebuilt from `phase-15`, migration 0018 applied (19 migrations), `/health` 200.
- **Backup** first: `C:\Users\Jirans\FitOS-backups\fitos-20261021-202532.dump`.

**A. Permission and settings**
1. First launch after sign-in: Android asks to allow notifications. Allow. (If you deny, Profile → Notifications shows "Notifications are off for FITOS on this phone" with **Allow notifications**.)
2. Profile → **Notifications**: Reminders on; tone **Cheeky**; every kind with its own switch (Weigh-in and Recovery check-in off); quiet hours 22:30 / 07:30.
3. Each kind that is on shows **Next: <day time>**. **COMING UP** lists them with their words and a *why* line.
4. **Send me a sample**: a notification appears at once in Cheeky words.
5. Switch **Gentle**: Coming up changes to gentle words. Switch back.
6. Turn one kind off: it leaves Coming up. Change quiet hours: times inside them move or go.

**B. Delivery and timing (needs a day)**
1. Leave a planned reminder pending (e.g. today's workout reminder) and close the app. It arrives at the time shown, with a **Snooze 1 h** button.
2. Tap it: FITOS opens on the right screen (workout → Plan; protein → log food, Dinner; streak → Home; recap → Progress).
3. Snooze one: it comes back about an hour later.
4. Reboot the phone with a reminder pending: it still arrives.

**C. Only when useful**
1. On a training day, **start the workout before** the reminder time: it does not arrive.
2. Log enough protein (≥ 75 % of target) before 19:00: no protein nudge that evening.
3. Log anything before 21:00: no streak saver that night.

**D. Limits**
- No day gets more than **2** reminders (the rest timer during a workout does not count).
- Nothing arrives in quiet hours.

**E. Regression**
- The rest timer still notifies in a workout, and tapping it opens the app.
- Logging, workouts, TODAY and AI as before.

**Accept Phase 15 when** A–E pass (the comeback arc needs days of not opening the app; optional). Then:
- ADR-021 → ACCEPTED;
- §38 Phase 15 ticked (server push deferred, O9);
- this report updated.

No merge without your approval.
