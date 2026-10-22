## PHASE 16 — ADMIN — IMPLEMENTATION COMPLETE, MANUAL ACCEPTANCE PENDING

**Date** 2026-10-22 · **Branch** `phase-16` from `1193bb5` (Phases 13–15 accepted and frozen) · **not merged**

**Status:** **implemented and tested; NOT accepted, NOT frozen.**
- The manual checks (§6) have not been run.
- §38 Phase 16 is not ticked; ADR-022 is PROPOSED.

**Commits**
- `39e3455` — core `admin/`: endpoint health, corrections, diet overrides, rate dashboards; tests
- `e2f8071` — contracts `admin.ts`; OpenAPI
- `f7ecf84` — API `/v1/admin/*`, migration 0019 with a down, seeds that keep admin edits, the `admin-grant` script; integration and migration tests
- `7480804` — the admin panel (Next.js), `ci-admin`
- `4ea2a83` — `/meta/config` public, as §10.1 says
- plus the documentation commit: this report, the plan, ADR-022, the MASTER-SPEC and BACKLOG amendments

**Decision record:** [plan](../phase-plans/phase-16-plan.md), [ADR-022](../decisions/ADR-022-admin.md) (D1–D10).

**Owner decisions (2026-10-22):**
- Phases 13–15 accepted;
- you grant the admin role with a script;
- the panel runs on this PC only.

### 1. WHAT MASTER-SPEC REQUIRES (and where it is)

| Requirement (§20, §31, §9.2, §10.1, §38) | Built |
|---|---|
| Next.js admin | `apps/admin`, local, same-origin `/api` proxy |
| Admin claim enforced server-side, non-admin 403 | `requireAdmin` at preValidation on every `/admin/*` route |
| Every admin action audited | `audit_logs` row in the same transaction; lookups too |
| Mess correction queue; corrections apply to future menus by slug | queue by slug; accept → estimate revision / diet override, applied in `resolveDay` |
| Food database corrections | FITOS foods editable; the seed keeps edits |
| Exercise CRUD | create, edit, retire, restore (no delete — history) |
| Provider health, per-endpoint staleness | `/admin/mess/health`, overview |
| User support lookup, no photos or raw food logs | counts and dates only |
| Feature flags | `feature_flags`, `/meta/config` (public) |
| Recommendation acceptance-rate dashboard | TODAY per kind, plus reminder open rates |
| Vercel | **deferred** with hosting (O1) |

### 2. ACCEPTANCE (automated)

| Criterion | Evidence |
|---|---|
| Admin claim, 401/403 | API: 15 admin routes × (signed out → 401, no claim → 403 FORBIDDEN, nothing written) |
| Every action audited | API: one row per accept, reject, dish edit, diet change, food edit, exercise create/edit/retire/restore, flag change and lookup, with the actor; audit paging |
| Corrections apply by slug to future menus | API: an accepted kcal correction shows in the served menu; a diet correction changes the menu's diet and clears again; a revision row; a second review is 409 |
| Per-endpoint staleness | core: ok / stale (> 26 h) / failing (≥ 3) / never. API: four endpoints set to each state, each reported |
| Seeds keep admin edits | API: a corrected food and an edited exercise survive `seedFoods` / `seedExercises` |
| Retired exercises | API: gone from `/exercises` and the generator's catalogue; back on restore |
| Support view hides food logs | API: a logged meal's name and numbers are absent from the response |

### 3. TESTS

| Suite | Count | New for Phase 16 |
|---|---|---|
| core | 921 | `test/admin.test.ts` (7) |
| contracts | 86 | — (the shapes are exercised by the API tests) |
| API | 494 | admin integration (10), migration 0019 |
| Flutter | 675 | — (no app change) |
| admin panel | — | `ci-admin`: typecheck, lint, production build (11 routes) |

TypeScript typecheck and lint: clean everywhere. OpenAPI exported.

### 4. ON THIS PC

- **Backup** before the migration: `C:\Users\Jirans\FitOS-backups\fitos-20261021-215225.dump`.
- The API container was rebuilt from `phase-16`, migration 0019 applied (20 migrations), the grant script is in the image. `/meta/config` and `/admin/*` answer as expected.
- The panel built and served on :3000; its `/api` proxy reached the API. It is not left running.
- `apps/admin/.env.local` holds the app's **public** Firebase client config and is gitignored.

### 5. KNOWN LIMITS AND OPEN ITEMS

- **Local only:** the panel reaches the API on this PC. Vercel waits for hosting (O1).
- **Sign-in:** Google sign-in in the panel needs `localhost` among Firebase Auth's authorised domains. It is there by default; if the popup says otherwise, add it in the Firebase console. Email and password works as well, if your account has a password.
- **Not built:** the app reading flags (E18), the minimum app version (E1), editing alternatives (E19).
- **Still open:** O2 (§18 cap), O3 (merges), O7 (paid Gemini), O8, O9.

### 6. MANUAL CHECKLIST (about 15 minutes, on the PC)

1. **Make yourself admin** (once), in PowerShell:
   `docker exec fitos-api node apps/api/dist/scripts/admin-grant.js <your sign-in email>`
   It says "now an administrator".
2. **Start the panel**, in `D:\dev\fit new`: `pnpm --filter @fitos/admin dev`. Open http://localhost:3000.
3. **Sign in** with the same account as on the phone. You land on **Overview**, with six menu endpoints and their state, users, and the TODAY and reminder tables.
   - (In a private window with an account that is not admin: "Not an administrator", with the grant command.)
4. **§31 manual — correct a dish:**
   1. On the phone, open the mess menu and report a dish's calories with the dish's correction option.
   2. In the panel, open **Mess corrections**: the report is there, grouped under the dish, with the current estimate. Adjust Low/High if you like, then **Accept**.
   3. On the phone, open the **next day the dish appears** (or the same day again): it shows the new numbers.
   4. A meal you had already logged with it keeps its old numbers.
5. **Diet:** use "Edit this dish directly" to set a dish to `egg`. The phone shows it as egg. Set it back to "As parsed".
6. **Foods:** search a food, open it, change a number and give a reason, then **Save correction**.
7. **Exercises:**
   1. **New exercise** with a slug, name, equipment, muscles and two steps; it appears in the app's exercise library.
   2. **Retire** it: it leaves the library.
   3. **Restore** it.
8. **Flags:** add a flag (it starts off) and turn it on. http://localhost:8080/v1/meta/config shows it.
9. **Support:** look up your email. You see counts and dates, and no meal names or weights.
10. **Audit log:** every step above is listed, with your email.

**Accept Phase 16 when** 1–10 pass. Then:
- ADR-022 → ACCEPTED;
- §38 Phase 16 ticked (Vercel deferred);
- this report updated.

No merge without your approval.
