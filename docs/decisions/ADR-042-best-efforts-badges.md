# ADR-042 — Beta 4.2: best efforts and the running distance badges

**Status:** PROPOSED. The owner set the scope and answered every question on 2026-10-29 (`docs/phase-plans/beta-4.2-best-efforts-plan.md`), and said "go". Built on `phase-19`. Becomes ACCEPTED with the owner's acceptance of beta 4.2.
**Date:** 2026-10-29
**Phase:** 19 (beta 4.2)
**Affects:**
- ADR-038/039 (runs);
- the beta 3.4 rewards (`user_rewards`, `GET /user/rewards`);
- ADR-027/028 (app icons and themes);
- §6.2 (a new palette, Road).

---

## Decisions

| # | Decision |
|---|---|
| D1 | **Best efforts are the fastest stretch of each distance inside any run:** 400 m, 1 km, 1 mile, 5 km, 10 km, half, marathon. They are on moving time, the splits' own rules (owner: pauses do not count). Both ends are interpolated. The fastest stretch always starts or ends on a point, so both cases are tried, with two pointers per distance. Faster than the world record is left out for that distance (a GPS jump or a car). Treadmill runs have no track and so no efforts. The rules are in core `running/efforts.ts`, with a Dart port the phone uses; both have the same tests. |
| D2 | **Kept per run** (migration `0037`): `run_best_efforts` (a run, its distance, seconds, where the stretch starts), deleted with the run, and `runs.efforts_version`, so a change of rules works old runs out again. Worked out when a run is saved. Older runs (owner: all saved runs count) are worked out by `GET /running/records`, 200 a request, with `pending` saying how many remain; nothing runs at deploy. |
| D3 | **Ranks:** every run's detail carries its efforts, each ranked among the user's (1–3, else none; ties go to the earlier run). The history carries the distances a run holds the record for (`recordKeys`). `GET /running/records` gives the best three at each distance. Older apps read the new fields loosely and are unaffected. |
| D4 | **"New record" straight away** (owner): the finish screen works out the run's efforts on the phone and compares them with the last records the phone saw. It also checks the badges against the last earned list. It shows "New record: 5 km in 24:31" and "Badge earned: …", and the voice coach says them once. Without a records or badge list, nothing is claimed. The server's figures stand once the run syncs. |
| D5 | **Five distance firsts:** first run, 5K, 10K, half, marathon. One run must cover the distance by its own figure; a treadmill run counts, and 5 m of slack lets a run shown as "5.00 km" count. Each is dated by the first run that reached it and kept in `user_rewards` like the streak rewards; deleting that run keeps the badge. They are checked when a run is saved, when the records are read, and when the rewards are read. |
| D6 | **Rewards** (owner): first 10K unlocks the **Finisher** app icon (the lime F in a medal ring); first half unlocks the **Road** theme (dark asphalt, steel-blue actions); first marathon unlocks the **gold 42** app icon. The icons are new launcher aliases (`.IconFinisher`, `.IconFortyTwo`) drawn by `tool/app_icons.py`, so 4.2 is an APK. A theme or icon unlocks on a streak reward's id or a badge's id alike. A phone holding one its account has not earned goes back to the default once both lists are known. |
| D7 | **Older phones:** `GET /user/rewards` checks reward ids strictly on 4.1.x. The badges are sent only to builds 20 and later (`X-FITOS-Build`), and that check is tested. |
| D8 | **Where it shows:** Running has a slim Records · Badges row, so the history stays in view. Records shows each distance's record (or "—"); a distance opens its best three, and those open the run. A run's report has a "Best efforts" section with gold, silver and bronze. History marks a record-holding run with a trophy. Badges lists the five, earned or how to earn them, and what each unlocks. |
| D9 | **Privacy:** efforts and badges are worked out from runs the server already has. Nothing new is collected, so the policy is unchanged. Both are in Download my data and deleted with the account, through the foreign keys. |

## Consequences

- 4.2 is build 20, an APK through Update now. The API deploys first (`0037`), and 4.1.x phones are unaffected by it.
- **Field check on the S24:**
  1. Update now installs 4.2.
  2. Records fill in from your past runs.
  3. A run's best efforts match its splits.
  4. A run that beats a record says so at the end.
  5. Badges show what your past runs earned.
  6. Any unlocked icon or theme can be chosen in Profile.
