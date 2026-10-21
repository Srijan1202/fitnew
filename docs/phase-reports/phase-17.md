## PHASE 17 — SECURITY & PRIVACY HARDENING — IMPLEMENTATION COMPLETE, MANUAL ACCEPTANCE PENDING

**Date** 2026-10-22 · **Branch** `phase-17` from `d614116` (Phase 16, approval pending) · **not merged**

**Status:** **implemented and tested; NOT accepted, NOT frozen.**
- The manual checks (§6) have not been run.
- §38 Phase 17 is not ticked; ADR-023 is PROPOSED.

**Commits**
- `a092274` — privacy API: consents, export, deletion, the AI consent gate, redaction, migration 0020; tests
- `c88bd3b` — the secret scan (CI, every APK)
- `7ed366a` — the app: AI consent sheet, Privacy & data, the local wipe, the policy; tests
- plus the documentation commit: this report, the plan, ADR-023, the breach procedure, the MASTER-SPEC and BACKLOG amendments

**Decision record:** [plan](../phase-plans/phase-17-plan.md), [ADR-023](../decisions/ADR-023-privacy.md) (D1–D8).

**Owner decisions (2026-10-22):**
- FITOS AI gets its own consent, asked before first use;
- deletion is immediate.

### 1. WHAT MASTER-SPEC REQUIRES (and where it is)

| Requirement (§31, §23, §24, §38) | Built |
|---|---|
| Consent flows | per purpose, versioned records; FITOS AI optional and revocable, enforced by the server; re-consent on a policy change |
| `POST /user/export`, machine-readable | the CASCADE foreign-key graph, JSON with notes, as an attachment; Download my data in the app |
| `DELETE /user`, every row and storage object | immediate, typed DELETE; CASCADE; audit entries about the user anonymised; Firebase sign-in removed; the phone wiped. No storage objects exist |
| Log redaction | more fields; sensitive query values masked in URLs |
| Rate limits | export 3/h, delete 5/h per user (plus the existing ones) |
| Secret Manager | **deferred** with hosting (O1) |
| Nightly `pg_dump` | script exists and verifies each dump; **scheduling is your step** (O5) |
| Privacy policy | `docs/legal/privacy-policy.md` v2026-10-22, the same text in the app |
| Breach procedure (§23.5) | `docs/legal/breach-procedure.md` |
| No secret in the repo or the binary | `check-secrets.mjs`: tracked files in CI, every APK in `alpha.ps1` |

### 2. ACCEPTANCE (automated)

| Criterion | Evidence |
|---|---|
| **Deletion leaves no residue (direct query)** | API: a user with data in many tables (programme, session and sets, food, check-in, TODAY, reminders, push token, consents, an admin lookup about them). After `DELETE /user`, **every column of every table** that can hold text is searched for their id, email and Firebase uid: zero hits. The admin's audit entry stays, anonymous. Firebase removal failing still leaves no residue |
| Export complete and machine-readable | API: for every table referencing `users` with CASCADE, the export holds exactly the rows a direct query finds; JSON-parsed against the contract; another user's id and email absent |
| Redaction verified in log output | API: a Fastify instance with the production logger, its real output searched for an email, tokens, a password, keys, a weight and a cookie: none |
| Rate limits enforced | API: the 4th export in an hour is 429; another user is unaffected |
| No secret in the repo or binary | 793 tracked files and the new APK's 684 entries scanned: clean; a planted private key and Google key are caught |
| Consent | API: AI refused (403) without it, allowed with it, refused again when withdrawn; a required purpose cannot be withdrawn; every change a record with the version. App: Read it asks first; "Not now" sends nothing; Allow records consent, then reads |

### 3. TESTS

| Suite | Count | New for Phase 17 |
|---|---|---|
| core | 921 | — |
| contracts | 86 | — (the shapes are exercised by API and conformance tests) |
| API | 504 | privacy integration (7), redaction (2), migration 0020; AI suites now grant consent first |
| Flutter | 685 | Privacy screen (7, including the doc/app policy sync), the AI consent gate, conformance (2) |

TypeScript typecheck and lint: clean. `flutter analyze --fatal-infos`: clean. OpenAPI exported.

### 4. ON THIS PC

- **Backup** before the migration: `C:\Users\Jirans\FitOS-backups\fitos-20261022-011423.dump`.
- The API container was rebuilt from `phase-17`, migration 0020 applied (21 migrations).
- **The LAN IP changed back to 172.16.205.231.**
- **APK:** `Downloads\fitos-phase17-7ed366a-lan-172.16.205.231.apk`, scanned for secrets by the build.

### 5. WHAT CHANGES FOR YOU AS A USER

- The first time you use FITOS AI on this build (chat, Describe your meal, Explain simply), it asks for the AI consent. Your existing account has not given it.
- Profile → **Privacy & data** shows "The privacy policy changed" until you accept version 2026-10-22.

### 6. MANUAL CHECKLIST

**A. On the S24**
1. Open the AI tab and send a message. The **Allow FITOS AI?** sheet explains what goes to Google.
   - **Not now:** nothing is sent.
   - Send again and **Allow**: the answer comes.
2. Profile → **Privacy & data**:
   - the "policy changed" card: **Accept the updated policy**, and it goes;
   - the FITOS AI switch is on: turn it off, then use Describe your meal, and it asks again.
3. **Download my data:** the share sheet opens with `fitos-export-<date>.json`. Save it to Files and open it: your workouts, meals and check-ins are there.
4. **§31 manual — delete a test account** (not your own):
   1. sign up a throwaway account on the phone, onboard it, log a meal;
   2. Privacy & data → **Delete my account**, type `DELETE`;
   3. you are signed out, and the app is back at sign-in.

**B. On the PC — the direct query**

5. With the test account's email, in PowerShell:
   ```
   docker exec fitos-postgres psql -U fitos -d fitos -c "select count(*) from users where email = '<test email>'"
   ```
   It shows `0`. The automated test does the full every-column search.
6. Firebase console → Authentication: the test account is gone.

**C. Your one-time step (O5)** — schedule the nightly backup:
```
schtasks /Create /TN "FITOS backup" /SC DAILY /ST 23:30 /TR "powershell -NoProfile -ExecutionPolicy Bypass -File \"D:\dev\fit new\scripts\backup-local.ps1\""
```

**Accept Phase 17 when** A and B pass. Then:
- ADR-023 → ACCEPTED;
- §38 Phase 17 ticked (Secret Manager deferred; the backup schedule ticked when C is done);
- this report updated.

No merge without your approval.

### 7. OPEN

- **O10:** before any public launch, a human confirms the DPDP obligations, names a contact and grievance officer, and settles the Board notification form.
- **Still open from before:** O1 (hosting / Secret Manager), O2, O3, O5, O7, O8, O9.
