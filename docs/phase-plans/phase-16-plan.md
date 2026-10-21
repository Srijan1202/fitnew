# Phase 16 — Admin: implementation plan

**Status** Written from the audit on 2026-10-22 and implemented in one pass on `phase-16` from `1193bb5` (Phases 13–15 accepted). Acceptance pending the manual checks.
**Decision record** [ADR-022](../decisions/ADR-022-admin.md).

## 1. What MASTER-SPEC asks for

- **§31 Phase 16:**
  - Tasks: the Next.js admin; mess correction queue; food corrections; exercise CRUD; provider health dashboard; feature flags; audit logging.
  - DB `mess_dish_corrections` (exists), `audit_logs`.
  - Tests: admin claim enforced server-side · non-admin receives 403 · every action audited.
  - Acceptance: corrections apply to future menus by slug · provider health shows per-endpoint staleness.
  - Manual: correct a dish; confirm it applies to the next occurrence.
- **§20:** also the user support lookup (no body photos, no raw food logs) and the recommendation acceptance-rate dashboard; Vercel hosting.
- **§10.1:** `GET /meta/config` (flags, minimum app version; public).

## 2. Owner input (2026-10-22)

- Phases 13–15 passed the S24 checks (closed out in `1193bb5`).
- Admin role: **a script the owner runs**. Hosting: **this PC only**.

## 3. Decisions (ADR-022)

| # | Decision |
|---|---|
| D1 | Local Next.js panel; `/api/*` same-origin proxy to the API; Firebase sign-in with the app's accounts |
| D2 | `admin-grant` script (owner); `requireAdmin` at preValidation (401 / 403, never 422) |
| D3 | `audit_logs` row with every change in the same transaction; lookups audited |
| D4 | Accepted corrections apply by slug: estimate revisions with provenance; diet overrides in `resolveDay` |
| D5 | FITOS food edits (`admin_edited_at`, seed skips); estimate rules kept; custom foods out |
| D6 | Exercise create/edit (seed skips), retire/restore (out of library and generator); no delete |
| D7 | Endpoint health: failing (≥ 3) / never / stale (> 26 h) / ok |
| D8 | `feature_flags` + public `/meta/config` (min version not yet) |
| D9 | Support view: counts and dates only, audited |
| D10 | TODAY and reminder rate dashboards (7/30/90 days) |

## 4. Build

1. **Core `admin/`:** endpoint health, `applyCorrection`, `applyDietOverrides`, rate dashboards; tests.
2. **Contracts `admin.ts`;** OpenAPI.
3. **Database:** migration 0019 (`audit_logs`, `feature_flags`, `mess_dish_overrides`, `foods.admin_edited_at`, `exercises.admin_edited_at`/`retired_at`) with a down; the seeds skip admin-edited rows; migration tests.
4. **API:**
   - `modules/admin` (repository, service, routes); `MessService.resolveDay` applies overrides; the library and generator skip retired exercises;
   - `scripts/admin-grant.ts`;
   - integration tests.
5. **Admin panel:** sign-in gate, overview, mess queue, foods, exercises, flags, support, audit; `ci-admin` (typecheck, lint, build).
6. **Docs:** this plan, ADR-022, the MASTER-SPEC and BACKLOG amendments, the report with the manual checklist.

## 5. API (all `/v1`, admin claim unless noted)

| Method | Path | Purpose |
|---|---|---|
| GET | `/admin/me` | Am I an admin |
| GET | `/admin/overview?days=` | Health, pending, users, rates |
| GET | `/admin/mess/health` | Per-endpoint staleness |
| GET | `/admin/mess/corrections?status=` | The queue by slug |
| POST | `/admin/mess/corrections/{id}/review` | Accept / reject |
| PUT | `/admin/mess/dishes/{slug}/estimate` · `/diet` | Direct dish edits |
| GET/PUT | `/admin/foods`, `/admin/foods/{id}` | FITOS foods |
| GET/POST/PUT | `/admin/exercises`, `/admin/exercises/{id}` (+ `/retire`, `/restore`) | Exercises |
| GET/PUT | `/admin/flags`, `/admin/flags/{key}` | Flags |
| GET | `/admin/users?email=` or `?id=` | Support view (audited) |
| GET | `/admin/audit?limit=&before=` | The audit log |
| GET | `/meta/config` (**public**) | Flags for the app |

## 6. Out of scope

Vercel deploy (hosting, O1); the app reading flags (E18); minimum app version (E1); editing exercise alternatives; deleting anything.
