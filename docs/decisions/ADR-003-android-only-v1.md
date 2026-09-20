# ADR-003 — V1 ships Android only

**Status** Accepted
**Date** 2026-09-20
**Phase** 0 (resolves a Phase 0 gate)
**Decided by** the project owner
**Resolves** MASTER-SPEC.md §36 open question 3
**Amends** §11 (auth), §31 Phase 19, §36, §37

---

## Context

§36 listed "iOS in V1?" as an open question requiring a human decision, flagged
for Phase 0 because it determines whether Apple Sign-In is in Phase 1's scope
and whether the Apple Developer subscription is incurred.

The question mattered now, not later, because Phase 1 is authentication. Adding
a third identity provider after the auth flow is built is more expensive than
including it from the start — so the decision had to precede Phase 1, not
follow it.

## Decision

**V1 is Android only.** iOS moves to V2.

## Consequences

### Removed from V1 scope

- **Apple Sign-In.** The App Store guideline that forces Apple Sign-In wherever
  other third-party social logins appear only binds apps submitted to the App
  Store. With no iOS submission, Phase 1 implements **email/password and Google
  Sign-In only**.
- **TestFlight** drops out of Phase 19; Play Store internal testing is the only
  beta channel.
- **~₹8,000/year Apple Developer membership** is not incurred. At zero revenue
  this is a real saving, not a rounding error — it is comparable to the entire
  projected infrastructure cost at 1,000 users (§27).
- **A Mac** is no longer required anywhere in the toolchain.

### Unchanged

- **`apps/mobile/ios/` stays in the repo.** It was generated in Phase 0, it is
  inert, and nothing builds it: `ci-mobile.yml` runs `flutter build apk` only.
  Deleting it would buy nothing and cost a regeneration later. It is simply not
  maintained during V1 — treat any iOS-specific breakage as expected until V2.
- **Package choices.** `flutter_secure_storage` (Keychain/Keystore) and
  `path_provider` are cross-platform by design; none of them were selected for
  iOS reasons, so none change.
- **The `health` package** (§7.1) still names HealthKit as its iOS backend, but
  health integration is V2 regardless, so nothing is pulled forward.
- **The privacy policy** is still required — §23 lists it as a legal obligation
  under DPDP *and* a Google Play requirement, independent of Apple.

### Watch

- **Do not let Android-only leak into the architecture.** The client is a single
  Flutter codebase and must stay one. Nothing in V1 may assume Android — no
  platform channels where a plugin exists, no Android-only storage assumptions.
  The cost of V2 iOS should be "submit it", not "port it".
- **`path_provider_foundation` and `objective_c` remain in the dependency
  graph** as transitive Apple-platform implementations even on an Android-only
  build. They are the packages behind the native-assets trap recorded in §25.
  Being Android-only does **not** remove them, so that trap still applies.

## Alternatives considered

| Alternative | Why not |
|---|---|
| Ship both in V1 | Doubles store/compliance surface and adds Apple Sign-In to Phase 1, for a wedge (VIT hostel students) that skews heavily Android |
| Build iOS but do not submit | Incurs the toolchain and Mac cost with none of the distribution benefit |
| Delete `apps/mobile/ios/` | Saves nothing; guarantees a regeneration and a diff in V2 |
