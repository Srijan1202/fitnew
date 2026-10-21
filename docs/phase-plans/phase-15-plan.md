# Phase 15 — Notifications: implementation plan

**Status** Written from the audit on 2026-10-21 and implemented in one pass on `phase-15` from `926c48b` (Phase 14 on `phase-14`, not yet accepted). Acceptance pending the S24 manual checks.
**Decision record** [ADR-021](../decisions/ADR-021-notifications.md).

## 1. What MASTER-SPEC asks for

- **§31 Phase 15:**
  - Tasks: FCM registration; scheduled notifications (via Cloud Scheduler); local rest timers; preferences.
  - DB `notifications`; API `POST /notifications/token`.
  - Tests: ≤ 2 push a day · preferences respected · no copy from an LLM.
  - Acceptance: every notification individually toggleable; none use shame framing.
  - Manual: delivery and timing on a real device.
- **§21:** the five notifications and their timing; 2 a day; each toggleable; no guilt (amended, D3); the engine writes the copy.
- **§9.2:** `notifications (id, user_id, kind, scheduled_for, sent_at, opened_at)`; `user_preferences.notification_settings`.
- **§38:** FCM registration · scheduled notifications · local timers · preferences · ≤ 2/day enforced.

## 2. Owner input (2026-10-21)

- Notifications "very time based and creative like Duolingo… tracks the time… many more techniques… all and more".
- **Tone: Cheeky Duolingo-style** (amends §21's no-guilt rule). **Cap: keep 2 a day.**
- **Scheduling: option A**, the phone schedules (no Cloud Scheduler; no GCP changes).

## 3. Decisions (ADR-021)

| # | Decision |
|---|---|
| D1 | The server plans (core `notify/`), the phone schedules and cancels; the plan is rebuilt on sign-in, launch, resume and after activity |
| D2 | FCM token registered (`push_tokens`); no server push until hosting |
| D3 | Cheeky by default; guardrails tested (never body, never food guilt, no insults); Gentle by setting and on low-readiness days |
| D4 | Eight kinds: workout reminder, missed session, protein gap, streak saver, weigh-in (off), recovery check-in (off), weekly recap, comeback |
| D5 | Learned timing, only-when-useful, cap 2 / 3 h / quiet hours, back-off, variety that learns, transparency (`why`, sample), Snooze 1 h |
| D6 | `notifications` ledger per (user, kind, day), stable ids, the phone's reports |
| D7 | Settings in `user_preferences.notification_settings`, read with defaults, served typed |

## 4. Build (one pass)

1. **Core `notify/`:** `time.ts` (local clock, habits), `copy.ts` (the template bank, guardrails), `types.ts`, `planner.ts`; tests.
2. **Contracts:** `notifications.ts` (settings, patch, plan request/response, preview, token); OpenAPI.
3. **Database:** migration 0018 (`notify_kind`, `notify_status`, `notifications`, `push_tokens`) with a down; migration tests.
4. **API:** `modules/notifications` (repository, service, routes); integration tests.
5. **Mobile:**
   - `core/notifications` (the activity signal; one shared plugin init with the rest timer, Snooze, taps);
   - `features/notifications` (DTOs, API, scheduler, coordinator, settings screen);
   - activity reports from workouts, food logging, weigh-ins and check-ins;
   - Profile → Notifications;
   - `firebase_messaging` 16.7.0 for the token;
   - tests.
6. **Docs:** this plan, ADR-021, the MASTER-SPEC and BACKLOG amendments, the report with the S24 checklist.

## 5. API

| Method | Path | Request | Response |
|---|---|---|---|
| GET | `/v1/notifications/settings` | — | settings |
| PATCH | `/v1/notifications/settings` | any subset (kinds too) | settings |
| POST | `/v1/notifications/plan` | `{ events: [{ id, event: delivered \| opened \| cancelled, at }] }` | `{ generatedAt, timeZone, settings, items }` |
| POST | `/v1/notifications/preview` | `{ kind }` | `{ title, body }` |
| POST | `/v1/notifications/token` | `{ token, platform: 'android' }` | 204 |

All need auth, and every one has a 401 test.

## 6. Out of scope

Server push (O9); dish names in the protein nudge (E17); an in-app notification centre.
