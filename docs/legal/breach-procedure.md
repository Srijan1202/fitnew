# FITOS — personal data breach procedure

**Version** 2026-10-22 · MASTER-SPEC §23.5 · ADR-023

A breach is any loss, leak or unauthorised access to the personal data FITOS holds. Examples: the PC or a backup stolen; the database reachable from outside; a key published; data shown to the wrong user.

## 1. Contain (first hour)

1. Stop the leak:
   - stop the API: `docker compose -f docker/docker-compose.yml stop api`;
   - take the machine off the network if it is compromised.
2. Rotate what may be exposed:
   - the Firebase service-account key (Firebase console → Project settings → Service accounts → generate a new key, delete the old one);
   - `GEMINI_API_KEY` (Google AI Studio);
   - `CONSENT_IP_SALT`.
3. Keep evidence: copy the API logs (`docker logs fitos-api > breach-<date>.log`) and note the time of every step.

## 2. Assess (same day)

- What data, whose, how many accounts, and over what period.
- Was it encrypted?
  - Backups are not.
  - Alpha traffic on the LAN is plain HTTP.
- The admin panel's `audit_logs` show every admin action and account lookup.

## 3. Notify (without delay)

- **Users affected:** tell them what happened, what data, what FITOS did, and what they can do (change their password; delete their account in Privacy & data).
- **The Data Protection Board of India,** as the DPDP Rules require.
  - `UNVERIFIED`: the exact form and deadline for an operator of this size. A human must confirm before public launch.
- Record what was sent, to whom and when.

## 4. Fix and review (within a week)

- Close the cause and add a test or check that would have caught it (the secret scan and the no-residue test are examples).
- Write a short note in `docs/audits/`: timeline, cause, fix, and what changes.

## Contacts

- **Operator:** the FITOS developer.
- A published contact and grievance officer will be named before any public launch (privacy policy, "Your rights").
