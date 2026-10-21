# ADR-023 — Privacy: consent per purpose (FITOS AI its own), export and deletion by the foreign keys, redaction and secret scans

**Status** PROPOSED — written from the Phase 17 audit (2026-10-22) and implemented on `phase-17`. Becomes ACCEPTED with Phase 17's acceptance (manual checks pending).
**Date** 2026-10-22
**Phase** 17
**Affects**
- MASTER-SPEC: §23 (privacy), §24 (security), §9.2 (`consent_records`), §10.1 (`/user/consents`, `/user/export`, `DELETE /user`), §31 Phase 17, §38 (on acceptance only).
- ADR-020 (AI): every AI route now also needs the `ai-processing` consent.

---

## Context

**§31 Phase 17:**
- Tasks: consent flows; export; delete (including storage objects); log redaction; rate limits; Secret Manager; nightly `pg_dump`; privacy policy.
- Tests: delete removes **every** row and storage object · export complete and machine-readable · redaction verified in log output · rate limits enforced.
- Acceptance: deletion leaves no residue (verified by direct query) · no secret in the repo or the app binary.

**§23:**
- DPDP Act 2023: specific, informed, revocable consent per purpose, logged with the policy version;
- erasure within 30 days; portability as machine-readable JSON;
- a breach procedure; a published policy; 18+ only.

**Already in place:**
- consent records from onboarding (two purposes);
- pino redaction of the main fields;
- per-user rate limits;
- the 18+ check at onboarding;
- `scripts/backup-local.ps1`.

**Owner (2026-10-22):**
- FITOS AI gets its own consent, asked before first use;
- deletion is immediate.

## Decisions

1. **D1 — Consent per purpose, AI its own (owner).**
   - `consent_type` gains `ai-processing` (migration 0020, with a down that rebuilds the enum).
   - Onboarding asks only the **required** purposes (privacy policy, health data); FITOS AI is asked by a sheet before the first chat, meal description or explanation. The sheet says what is sent to Google and that the alpha uses the free tier.
   - `GET/POST /user/consents`. Every change is a new record with the current policy version and the salted IP hash.
   - A required purpose can be re-granted (after a policy change; `needsReconsent`) but not withdrawn: deletion is the way out.
   - The server enforces it: `AiBudget.check` returns 403 `FORBIDDEN` (issue `ai-processing`) before any model call.
2. **D2 — The policy.** `docs/legal/privacy-policy.md`, version `2026-10-22` (`CURRENT_POLICY_VERSION` bumped).
   - The same text is in the app (`policy_text.dart`), kept in step by a test that also checks the version against the contracts.
   - It discloses the alpha honestly: the server on the developer's PC, plain HTTP on the local Wi-Fi, Gemini's free tier, backups.
3. **D3 — Erasure, immediate (owner).**
   - `DELETE /user` with `{"confirm":"DELETE"}`, in one transaction:
     - audit entries *about* the user lose the id (`subjectDeleted: true`);
     - the `users` row goes, and every owned row with it through `ON DELETE CASCADE`;
     - `SET NULL` pointers (an admin's `reviewed_by`, an audit actor) are nulled.
   - Then the Firebase sign-in is removed through an `AccountDeleter` seam (a failure is reported as `signInRemoved: false`; nothing of FITOS remains either way).
   - The phone then cancels its reminders, clears its database and preferences, and signs out.
   - **Storage objects:** none exist; body photos are not built. Any future file store must join this path (noted in §23).
4. **D4 — Export by the foreign-key graph.**
   - `POST /user/export` walks the database's own CASCADE foreign keys from `users`, so it is complete by construction and covers any later table.
   - Format: `{ format: 'fitos-export', version: 1, exportedAt, userId, notes, tables }`, each row as stored, as JSON, sent as an attachment.
   - SET NULL references are **not** followed: they would carry other people's data (an admin's export would include the corrections they reviewed).
   - The phone hands the file to the share sheet (`share_plus`).
5. **D5 — Redaction verified.**
   - Request URLs are logged with sensitive query values masked (`email`, `token`, keys, passwords) — `/admin/users?email=` would otherwise log an email.
   - The redaction paths are extended (passwords, ID tokens, API keys, `x-goog-api-key`).
   - A test reads the real pino output of a Fastify instance.
6. **D6 — No secrets, checked.**
   - `scripts/check-secrets.mjs` scans every tracked file (in CI) and every built APK (`alpha.ps1` runs it after the build). It looks for private keys, service-account JSON, Google, GitHub, Slack and OpenAI-style keys, and the actual Gemini key from `docker/.env`.
   - The public Firebase client key is allowed in the APK only.
   - It was verified against a planted negative control.
7. **D7 — Rate limits.** Per user: export 3 an hour, deletion 5 an hour, on top of the general 120/min.
8. **D8 — Deferred, honestly.**
   - **Secret Manager** waits for hosting (GCP, owner-gated, O1); secrets stay in gitignored files on the PC.
   - **The nightly `pg_dump`:** the script exists and verifies each dump; scheduling it is the owner's Task Scheduler step (O5).
   - The breach procedure is written (`docs/legal/breach-procedure.md`).

## Consequences

- An account can leave completely, and the tests prove it by searching every column of every table.
- FITOS AI is now opt-in for every user, including existing ones: the first AI use after this build asks.
- New tables are covered by export and deletion automatically, as long as they reference their owner with a CASCADE foreign key (a convention now worth keeping).
