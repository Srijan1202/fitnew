# ADR-021 — Notifications: planned on the server, scheduled on the phone, timed from habits, cheeky by owner decision

**Status** PROPOSED — written from the Phase 15 audit (2026-10-21) and implemented on `phase-15`. Becomes ACCEPTED with Phase 15's acceptance (S24 manual checks pending).
**Date** 2026-10-21
**Phase** 15
**Affects**
- MASTER-SPEC: §21 (tone rule amended, kinds added), §9.2 (`notifications` columns, `push_tokens`), §10.1 (`/notifications/*`), §31 Phase 15 (Cloud Scheduler replaced), §38 (on acceptance only).
- ADR-012 (hosting): server push waits for hosting.
- ADR-017 / ADR-019: readiness is read to soften or skip reminders. No engine change.

---

## Context

**§21 asks for:**
- five notifications: rest timer, workout reminder, protein gap, weigh-in (off by default), weekly progress;
- at most 2 push notifications a day, each individually toggleable;
- no streak-shaming, no guilt, no "you missed…";
- copy written by the deterministic engine, never an LLM.

**§31 Phase 15 asks for:** FCM registration; scheduled notifications via **Cloud Scheduler**; local rest timers; preferences; `notifications`; `POST /notifications/token`.
- Tests: ≤ 2 push a day · preferences respected · no copy from an LLM.
- Acceptance: every notification individually toggleable; none use shame framing.

**The owner asked (2026-10-21)** for notifications "very time based and creative like the one Duolingo used… tracks the time… and use many more techniques… all and more". In answer to two questions:
- tone: **Cheeky Duolingo-style** (allows light guilt and streak pressure; amends §21);
- daily cap: **keep 2 a day**.

**Constraint:** no GCP changes without approval, so Cloud Scheduler is out. The API runs on the owner's PC, which is not always on.

## Decisions

1. **D1 — The server plans; the phone schedules.**
   - `POST /notifications/plan` returns up to 8 days of items: the instant, title and body, the screen a tap opens, and the rules that cancel each one (`cancelOn`).
   - The phone schedules them with `flutter_local_notifications` and rebuilds the plan on sign-in, launch, resume and after activity.
   - They fire with the PC off and the phone offline. This replaces Cloud Scheduler (owner: option A).
   - Every rule (timing, cap, back-off, words) is in core `notify/`. The phone only schedules and cancels (§30).
2. **D2 — FCM is registered, not used yet.** `POST /notifications/token` stores the device token (`push_tokens`, one row per token, moving to whoever signed in last). Server push waits for hosting.
3. **D3 — Tone: cheeky by default (owner decision, amends §21's no-guilt rule).**
   - Allowed: teasing, light guilt, streak pressure ("Legs got ghosted", "Your gains are packing a bag").
   - Guardrails in every tone, enforced by a banned-words test over every template:
     - the tease is about habits, never the body (no weight, size, shape or appearance);
     - never "eat less", never food guilt;
     - no insults.
   - **Gentle** is a setting, and it is used automatically on a low-readiness day (reduce or rest band).
4. **D4 — The kinds** (each individually toggleable, §21):

   | Kind | When | Default | Cancelled by |
   |---|---|---|---|
   | workout-reminder | 1 h before the user's usual start (that weekday, else overall; 17:00 until learned); training days only; not on a rest-band day | on | starting the workout |
   | missed-session | the morning after a planned session that was not logged | on | completing it late, or starting today's |
   | protein-gap | before the usual dinner log (45 min; 19:00 until learned) while protein < 75 % of target | on | protein reaching 75 % (checked when the food queue delivers) |
   | streak-at-risk | 21:00 if nothing is logged that day; names the real streak today | on | any log |
   | weigh-in | the usual weigh-in time, after 2+ days without a reading | **off** | a weigh-in |
   | recovery-checkin | the usual check-in time, until checked in | **off** | a check-in |
   | weekly-recap | Sunday 16:00 (clear of the evening nudge) | on | — |
   | comeback | day 2, 4 and 7 if the app is not opened; day 7 says "These reminders don't seem to be working. So we'll stop for now." and is the only word that day | on | opening the app |

   The rest timer (Phase 5) stays as it is and is not counted in the cap.
5. **D5 — Techniques, all deterministic:**
   - **Learned timing:** the median of the user's own local times over 5 weeks, with the day pivoting at 04:00, needing 3 repeats (2 per weekday).
   - **Only when useful:** nothing for a kind already sent, opened or cancelled that day.
   - **Cap 2 a day, 3 h apart:** highest priority first, already-sent ones counted, nothing in quiet hours (default 22:30–07:30, settable). Morning kinds move to the end of quiet hours; others move before its start, or drop.
   - **Back-off:** 3 ignored in a row (not opened, and the thing not done) → every other day; 6 → a week off. Opening one, or doing the thing, resets it.
   - **Variety that learns:**
     - no repeat of a kind's words within 7 days;
     - among fresh variants, the highest Laplace-smoothed open rate wins;
     - words using the user's own data (session name, streak, target) get a small head start;
     - ties go to a stable hash.
   - **Transparency:** every item carries `why`, shown in settings ("About an hour before you usually start training (around 18:40 lately)"), plus a "Send me a sample" button.
   - **Snooze 1 h** on the reminder itself (works with the app closed).
6. **D6 — The ledger.** `notifications` (§9.2) is one row per (user, kind, local date): `scheduled_for`, `variant`, `title`, `body`, `status` (planned → delivered → opened, or planned → cancelled) and its timestamps.
   - Re-planning keeps the ids (upsert) and deletes planned rows the plan dropped. Reported rows are never touched.
   - The phone reports outcomes with the next plan request. Reports are best effort, replay-safe and forward-only.
   - "Delivered" is reported only if the item was scheduled with permission.
7. **D7 — Settings** live in `user_preferences.notification_settings` (§9.2), read field by field with defaults (that column is also writable through the free-form `PATCH /user/preferences`). They are served typed through `GET`/`PATCH /notifications/settings`.

## Not in Phase 15

- Server push (D2; after hosting, BACKLOG O9).
- Mess-menu dish names in the protein nudge. The Phase 10 suggestions are on the Eat tab; naming a dish needs that day's menu at plan time (BACKLOG E17).
- An in-app notification centre.

## Consequences

- Reminders work on the alpha's real setup (PC sometimes off, phone often offline).
- The cheeky tone is a deliberate product choice by the owner. Gentle is one tap away, and automatic on low-readiness days.
- A plan is only as fresh as the last time the app reached the server. A user who stops opening the app gets the week already planned, then the comeback nudges, then silence. That is the intended Duolingo-style arc.
