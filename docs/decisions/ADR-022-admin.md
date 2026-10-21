# ADR-022 — Admin: a local panel behind the admin claim, every change audited, corrections applied by slug

**Status** PROPOSED — written from the Phase 16 audit (2026-10-22) and implemented on `phase-16`. Becomes ACCEPTED with Phase 16's acceptance (manual checks pending).
**Date** 2026-10-22
**Phase** 16
**Affects**
- MASTER-SPEC: §20 (Admin), §9.2 (`audit_logs`, `feature_flags`, `mess_dish_overrides`, the admin marks), §10.1 (`/admin/*`, `/meta/config`), §31 Phase 16, §38 (on acceptance only).
- ADR-014/015 (mess): reviewed corrections change estimates and diets by slug. Logged snapshots never change.
- ADR-013 (foods) and ADR-005 (exercises): the seeds leave admin-edited rows alone.

---

## Context

**§20:**
- Next.js at `apps/admin`.
- Functions: the mess correction queue · food corrections · exercise CRUD · provider health (last success per endpoint, staleness) · user support lookup (**no body photos, no raw food logs**) · feature flags · the recommendation acceptance-rate dashboard.
- Access: the Firebase custom claim `role: admin`, on the server, every request. **Every admin action writes to `audit_logs`.**

**§31 Phase 16:**
- DB `mess_dish_corrections` (it exists since Phase 9, as pending reports) and `audit_logs`.
- Tests: the admin claim is enforced server-side · a non-admin receives 403 · every action is audited.
- Acceptance: corrections apply to future menus by slug · provider health shows per-endpoint staleness.
- Manual: correct a dish; confirm it applies to the next occurrence.

**Owner (2026-10-22):**
- the grant is a script the owner runs;
- the panel runs on this PC only (no Vercel for now).

## Decisions

1. **D1 — Local panel, same-origin proxy.**
   - `pnpm --filter @fitos/admin dev` (or `build` + `start`) serves http://localhost:3000.
   - The browser calls `/api/*` on that server, which Next.js forwards to the API (`FITOS_API_URL`, default `http://localhost:8080`). The API gains no CORS opening and the panel never touches the database.
   - Sign-in uses the app's own Firebase accounts: Google, or email and password. Firebase client config is public and lives in `apps/admin/.env.local` (gitignored).
   - Vercel (§20) is deferred with hosting (BACKLOG O1).
2. **D2 — The claim, granted by the owner.**
   - `admin-grant <email> [--revoke]` sets or removes `role: admin` through Firebase Admin. Run it in the container, which already has the credentials mounted: `docker exec fitos-api node apps/api/dist/scripts/admin-grant.js you@example.com`. Then sign out and in.
   - Every `/v1/admin/*` route runs `requireAdmin` at **preValidation**: 401 without a session, 403 without the claim. A non-admin never learns a body's shape (no 422).
3. **D3 — Audit.**
   - `audit_logs` (§9.2) gets one row per change, written in the same transaction as the change: action, entity, id, actor and metadata (before/after where useful).
   - **Support lookups are audited too**, found or not.
   - The actor is kept on account deletion (`set null`).
4. **D4 — Corrections apply by slug.**
   - The queue groups pending reports by dish slug, with the current estimate and any diet override.
   - **Accept:**
     - a numeric field: the reviewed range (the report's, or one the reviewer adjusts) replaces that field of `mess_dish_nutrition` for the slug. It is kept within per-serving bounds (core `applyCorrection`) and written with a provenance row in `mess_dish_nutrition_revisions`.
     - a diet report: `mess_dish_overrides` sets the slug's diet. It applies in `MessService.resolveDay`, the one place both the menu and the meal suggestions read, through core `applyDietOverrides`.
     - "other": marked resolved.
   - **Reject:** changes nothing.
   - Reviewed once (409 after).
   - A reviewer can also edit a dish's estimate or diet directly, with a reason.
   - Meals already logged keep their snapshot.
5. **D5 — FITOS foods.**
   - An admin edit replaces the name, aliases (normalised), the verified flag and the nutrition rows, and stamps `foods.admin_edited_at`. **The seed then leaves that food alone.**
   - The Phase 7 rules hold: an estimate is never verified and never high confidence.
   - Users' own foods are neither listed nor editable.
6. **D6 — Exercises.**
   - Create (with a slug) and edit the seed's fields except alternatives, which are kept. `exercises.admin_edited_at` makes the seed skip the row and its joins; other exercises can still name it as an alternative.
   - **Retire** (`retired_at`) takes an exercise out of the library list and the generator's catalogue. Existing programmes, sessions and its detail page keep it. Restore brings it back.
   - No delete, because history references exercises.
7. **D7 — Provider health.** Per mess endpoint: last attempt, success and change, consecutive failures, the last error, and core `endpointHealth`:
   - **failing** at 3 or more failures in a row;
   - **never** with no success yet;
   - **stale** with no success for more than 26 h;
   - **ok** otherwise.
8. **D8 — Flags and `/meta/config`.**
   - `feature_flags` (key, enabled, description, who and when) is set in the panel.
   - `GET /v1/meta/config` is **public** (§10.1) and returns `{ flags }`.
   - The minimum app version is not served yet (BACKLOG E1). The app does not read flags yet (BACKLOG E18).
9. **D9 — Support view: counts and dates only.**
   - It shows: profile basics, onboarding stage, goal, programme name, counts and last dates (sessions, food logs, weigh-ins, check-ins), FITOS AI calls in 7 days, and the reminder setting.
   - **It never shows** food log contents, weights or photos. A test asserts a logged meal's name and numbers are absent.
10. **D10 — Dashboards.**
    - TODAY (§16) per kind: shown, opened, accepted, dismissed and completed (distinct actions), with accept, dismiss and complete rates.
    - Reminders (Phase 15) per kind: sent, opened, cancelled on the phone, and the open rate.
    - Over 7, 30 or 90 days.

## Consequences

- The owner corrects mess and food data without SQL, and every change is answerable: who, when, what it was before.
- Seeds stay re-runnable without undoing reviewed corrections.
- The panel works only on the PC that runs the API, like the app's API itself, until hosting.
