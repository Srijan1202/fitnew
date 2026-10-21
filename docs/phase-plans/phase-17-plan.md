# Phase 17 — Security & privacy hardening: implementation plan

**Status** Written from the audit on 2026-10-22 and implemented in one pass on `phase-17` from `d614116` (Phase 16, approval pending). Acceptance pending the manual checks.
**Decision record** [ADR-023](../decisions/ADR-023-privacy.md).

## 1. What MASTER-SPEC asks for

- **§31 Phase 17:**
  - Tasks: consent flows; export; delete (incl. storage objects); log redaction; rate limits; Secret Manager; nightly `pg_dump`; privacy policy.
  - APIs: `POST /user/export`, `DELETE /user`.
  - Tests: delete removes every row and storage object · export complete and machine-readable · redaction verified in log output · rate limits enforced.
  - Acceptance: no residue after deletion (direct query) · no secret in the repo or the binary.
  - Manual: delete a test account; query the database directly.
- **§23:** consent per purpose with the policy version; erasure ≤ 30 days; portable JSON; breach procedure; published policy; 18+.
- **§24:** redaction fields; stricter limits; secrets out of the repo and the app.

## 2. Owner input (2026-10-22)

- FITOS AI gets **its own consent**, asked before first use.
- Deletion is **immediate**.

## 3. Decisions (ADR-023)

| # | Decision |
|---|---|
| D1 | `ai-processing` consent (optional, revocable, enforced by `AiBudget`); onboarding asks only the required ones; `/user/consents` |
| D2 | Privacy policy v2026-10-22 (doc + same text in the app, test-synced) |
| D3 | `DELETE /user` immediate, typed DELETE, CASCADE + audit anonymised + Firebase sign-in removed; phone wiped |
| D4 | `POST /user/export` by the CASCADE foreign-key graph (complete by construction) |
| D5 | URL query redaction + more paths; verified in real log output |
| D6 | `check-secrets.mjs` on tracked files (CI) and every APK (`alpha.ps1`) |
| D7 | Export 3/h, delete 5/h per user |
| D8 | Secret Manager (hosting) and the nightly schedule (owner) deferred; breach procedure written |

## 4. Build

1. **Contracts:** `CONSENT_TYPES` + `REQUIRED_`/`OPTIONAL_`; `privacy.ts`; policy version; OpenAPI.
2. **Database:** migration 0020 (`consent_type` + `ai-processing`, a rebuilding down).
3. **API:** `lib/account-deleter.ts`; `modules/privacy` (repository: consents, FK-graph export, delete; service; routes); the AI consent gate; logger serializer and paths; tests (no-residue scan, export completeness, redaction, limits).
4. **Scripts:** `scripts/check-secrets.mjs`; CI step; `alpha.ps1` APK scan.
5. **Mobile:**
   - `Forbidden` failure; `ConsentType.aiProcessing` and `.required`;
   - `features/privacy` (API, providers, AI consent sheet, the Privacy & data screen, policy text);
   - the gate on chat, Describe your meal and Explain simply;
   - the local wipe after deletion;
   - tests.
6. **Docs:** this plan, ADR-023, the policy, the breach procedure, the MASTER-SPEC and BACKLOG amendments, the report.

## 5. API

| Method | Path | Request | Response |
|---|---|---|---|
| GET | `/v1/user/consents` | — | `{ currentPolicyVersion, needsReconsent, items[] }` |
| POST | `/v1/user/consents` | `{ type, granted }` | same |
| POST | `/v1/user/export` | — | `{ format, version, exportedAt, userId, notes, tables }` (attachment) · 429 after 3/h |
| DELETE | `/v1/user` | `{ confirm: "DELETE" }` | `{ deleted: true, signInRemoved }` · 429 after 5/h |
