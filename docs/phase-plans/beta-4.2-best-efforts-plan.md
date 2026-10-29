# Beta 4.2 — plan: best efforts and distance badges

**Date** 2026-10-29 · **Branch** `phase-19` · **Status:** the owner set the scope and answered every question on 2026-10-29 (the table below). Waiting for the go; no code before it.

## The owner's answers (2026-10-29)

| Question | Answer |
|---|---|
| Distances | **400 m, 1 km, 1 mile, 5 km, 10 km, half, marathon**, the fastest stretch inside any run |
| Past runs | **All saved runs count** |
| Pauses | **Not counted: moving time**, as the splits use |
| "New record" after a run | **Straight away, worked out on the phone** (works offline); the server's figure stands once synced |
| Delivery | **A 4.2 APK through Update now** (patches stay for small fixes) |
| Badges | **In 4.2: the distance firsts only** (first run, 5K, 10K, half, marathon) |
| Rewards | **First 10K: a "Finisher" app icon. First half: a "Road" theme. First marathon: a gold "42" app icon.** First run and first 5K are badges only. |

Route replay stays for later (4.3, then the watch).

---

## E1 — What a best effort is

- **Distances:** 400 m, 1 km, 1 mile, 5 km, 10 km, half marathon (21.0975 km), marathon (42.195 km).
- **The fastest stretch of that distance inside any run**, not only whole runs (as Strava does). A 10 km run therefore also gives a 1 km, a mile and a 5 km effort.
- **How it is found** (core, `running/efforts.ts`):
  - every point of the track has its distance and time from the start;
  - two pointers slide along the track to find the shortest time for each distance;
  - both ends are interpolated between points, so a 1 km effort is exactly 1,000 m, not "the points nearest 1 km";
  - one pass per distance, so even a marathon of 15,000 points takes a few milliseconds.
- **Time (owner): moving time**, as the run's splits use. A pause (auto-pause at a crossing) is not counted, so a best 5 km is never slower than the 5 km split shown for the same stretch.
- **Not counted:**
  - treadmill runs (no track);
  - a run shorter than the distance;
  - an effort faster than the world record for its distance (a GPS jump, a ride in a car).

  Only that distance is skipped for that run, and the run itself is unchanged.
- **Honest about GPS:** at 400 m, phone GPS can be a second or so out. The records screen says so, as the sprint summary does (4.1).

## E2 — Where it is kept

- **Migration `0037`:** `run_best_efforts`, one row per run and distance (run, user, distance, seconds, where it started and ended in the run). It is deleted with the run (cascade) and with the account.
- **`runs.efforts_version`:** which version of the rules made the run's rows. When the rules change, old runs are worked out again.
- **Computed on the server** (core), when a run is saved.
- **Existing runs (owner: all saved runs):** the first time a user's records are asked for, every run without rows is worked out, up to 200 a request, so nothing big runs at deploy time.

## E3 — The API

- **`GET /v1/running/records`:** for each distance, the best three efforts (time, pace, date, the run's name and id), or none yet.
- **A run's detail** gains `efforts`: each distance it covers, the time, and its rank among all the user's efforts (1 = the record, 2, 3, or none).
- **Download my data** gains the efforts; deleting the account deletes them.

## E4 — In the app

- **Running → Records:** a card with the seven distances, the record time and its date, or "—" when there is none yet. Tapping a distance opens the run.
- **A run's report:** a "Best efforts" section listing each distance the run covers, with a gold, silver or bronze mark when it is the user's best, second or third.
- **After a run (owner: straight away, worked out on the phone, so offline too):** "New record: 5 km in 24:31" on the summary, and spoken by the voice coach if it is on. History marks the run with a trophy.
- **Older apps:** 4.1.x phones do not ask for records, and the run detail's new field is ignored by them.

## E5 — Distance badges and their rewards

- **The five badges:**

  | Badge | Earned by | Reward |
  |---|---|---|
  | First run | any saved outdoor or treadmill run | — |
  | First 5K | one run of at least 5 km | — |
  | First 10K | one run of at least 10 km | **Finisher** app icon |
  | First half | one run of at least 21.0975 km | **Road** theme |
  | First marathon | one run of at least 42.195 km | gold **42** app icon |

- **One run must cover the whole distance**, by the run's own distance. A treadmill run counts for the badges, but not for best efforts, which need a track.
- **Past runs count**, like best efforts: worked out the first time they are asked for.
- **Badges are kept, like streak rewards:** one row each in `user_rewards`, with the date of the run that earned it. Deleting that run does not take a badge back.
- **Rewards:** the three rewards are new entries in the existing reward list (beta 3.4).
  - The icons are new launcher aliases (`.IconFinisher`, `.IconFortyTwo`) drawn by `tool/app_icons.py`, so they need the APK.
  - The theme is a new palette, `road`: dark, steel blue, with the four semantic colours including `sky`.
  - Each is chosen where the other rewards are, in Profile.
  - A reward not earned shows how to earn it ("Run your first half marathon to unlock the Road theme").
- **Older apps:** `GET /user/rewards` checks reward ids strictly. The new ids are sent only to builds that know them (`X-FITOS-Build` ≥ 20, as readiness's sixth part was gated in 4.1), and that check is tested.
- **In the app:**
  - **Running → Badges:** the five badges, earned ones in colour with the date, the rest greyed with what earns them.
  - **After the run that earns one:** "Badge earned: First 10K. You unlocked the Finisher app icon." On the summary, and from the voice coach when it is on.
- **Privacy:** badges are worked out from runs the server already has, and are kept, exported and deleted like the streak rewards. The policy does not change.

## E6 — Not changed

- **Privacy:** best efforts are worked out from runs the server already has. Nothing new is collected, so the policy does not change.
- **The readiness score, the coach and plans** do not use records or badges in 4.2.

## Tests

- **Core:**
  - fixtures with known answers: a steady 10 km, a run with pauses, a GPS jump, a run just over and just under each distance;
  - interpolation;
  - the 100 % branch gate.
- **API:**
  - records and ranks;
  - existing runs filled in on the first request, in batches;
  - deleting a run removes its efforts (and the next best becomes the record);
  - other users never seen;
  - Download my data.
- **Badges:** each first earned once, from past runs too; a treadmill run counts; deleting the run keeps the badge; the new reward ids only for build ≥ 20; the three rewards unlock.
- **App:**
  - the Records card;
  - the Badges screen, the earned line after a run, the new icons and theme in Profile;
  - the report section and its marks;
  - the new-record line on the summary;
  - an old server without records (the card hides).
- **Field (S24):** two or three real runs, checked against the splits.

## Release

- 4.2 is an APK (build 20) through **Update now**: the owner chose it, and the two new launcher icons need it anyway.
- The API is deployed first (migration `0037`). Only 4.2 phones ask for records and badges, and 4.1.x phones are unaffected.
