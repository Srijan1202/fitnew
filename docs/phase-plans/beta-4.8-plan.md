# Beta 4.8 plan: bugs, polish, upgrades

**Owner, 2026-10-30:** "4.8 will be only bug fixing and polishing what we have made". The owner reported four bugs and asked to find more, polish, and update all packages.
**Status:** awaiting the owner's go.
**Shape:**
- one APK release, 1.0.0-beta.4.8 (build 26), because the Flutter SDK changes;
- an API deploy first (streak calendar, upgrades);
- an admin deploy (upgrades).

---

## A. The owner's four bugs

| # | Bug | Cause (found) | Fix |
|---|---|---|---|
| A1 | The streak shows the last 4 weeks, not the month | `GET /progress/streak` sends 28 days (core `streakDays`) | **Month calendar**, Monday first, with every day of the month (Oct 1–31). ‹ › and a swipe go to earlier months, back to the month you joined. Days after today are blank, and the title shows the month. The server sends the days from the month you joined up to today (one year at most), as `calendar`. `days` stays for 4.4–4.7. |
| A2 | Every day is blue, though some were rest days | Core puts "logged" (a workout **or a meal**) before "rest". A meal on a rest day made it "logged". | A planned rest day shows **Rest** (green) unless you trained that day (a workout or a run). A meal no longer hides it. How the streak is counted does not change. |
| A3 | Rewards show a plain lock | `_RewardTile` draws `Icons.lock_outline` | Each reward shows **what it unlocks**, with a lock on top until earned: |
| | | | • the picture (Spark, Century); |
| | | | • the theme's colours (Ember, Road, Mileage); |
| | | | • the app icon (Blaze, Finisher, gold 42, Bolt); |
| | | | • the rim (Ember rim). |
| | | | Running badges show their own badge. |
| A4 | The weight graph looks small | The kg axis rounds to whole kilos (61–63 for 61.2–61.6). The time axis starts on the window's first day even when the readings start later. | The kg axis fits the data: half-kilo steps under 3 kg, 10 % margin. The time axis starts at the first reading inside the window, so the line uses the whole width. |

| A5 | Progress → Log weight: **Save sits behind the tab bar** (owner's screenshot) | The sheet opens on the tab's own navigator, under AppShell's floating bar. This is the beta 4.0.1 lesson, and 19 of the 24 bottom sheets still do not open on the root navigator. | **Every bottom sheet opens above the bar** (`useRootNavigator: true`): Log weight and measurements, photos, mess, portion, recovery, TODAY's "why", premium, pictures, AI consent, feedback, recommendations, exercise filters, shared programmes. A test opens Log weight inside the real tab shell and taps Save. |

## B. More found

1. **Streak page repeats itself.** "Your best streak… A day counts when you log a workout or a meal" appears twice: under the grid and again above the rewards. Keep the legend once.
2. **Legend greys too close.** "Skipped" and "Missed" are nearly the same dark grey. Missed becomes an outline; skipped stays a filled grey.
3. **Progress's 1W / 1M / 3M** draws the unchosen windows in the accent colour. The app's other switches draw them in plain ink.
4. **Home tiles cut their text**, for example "Health Connect is no…" and "Target 2,276 kcal · 10…". Allow two lines.
5. **Nutrition's "Today's mess" and "Suggested plate"** sit on the bare background between blocks. Put them in one block, like the meals below.
6. **Section labels are indented two ways.** "ABOUT YOU" (Profile) and the grouped lists are indented; Home's and Running's are flush. Make them all flush with the blocks.
7. **A full screen pass** in Dark, Light, Cobalt and FITOS Dark. Every tab and the main pages are rendered and checked for:
   - cut text;
   - contrast (accent text on the new themes);
   - leftover lime or green hard-coded where the theme's accent belongs.

   Anything found is fixed and listed in the ADR.

## C. Upgrades

| Where | From → to | Notes |
|---|---|---|
| Flutter SDK (CI pin, WSL release build) | 3.47.2 → 3.47.9 | Patch release. A new Shorebird release, since 4.8 is an APK anyway. Shorebird CLI 1.6.133 → latest. |
| Flutter packages | camera 0.12.2, geolocator 14.1.2, go_router 18.1.2 and the transitive ones | Minor versions. |
| zod + fastify-type-provider-zod | 3.25 → 4.6, 4 → 7 | The biggest change. Schemas and error details must stay the same: the API's 422 `details` and the OpenAPI document. The contract tests on both sides catch any drift. |
| postgres (driver) | 3.4 → 4.0 | The integration tests run on real Postgres. |
| @fastify/cors, @fastify/rate-limit, fastify-plugin | 10 → 11, 10 → 11, 5 → 6 | |
| Next.js + eslint-config-next (admin) | 15.5 → 16.4 | The static export must still build. |
| TypeScript | 5.9 → 7.0 | Only if typescript-eslint and the build accept it. Otherwise the latest 5.x, and I say so. |
| vitest + coverage, ESLint + @eslint/js, @types/node, tsx | 2 → 5, 9 → 10, 22 → 26, patch | Core's 100 % branch gate must still hold. |

The rule for each major: upgrade, then typecheck, lint, all tests, and the OpenAPI and contract checks. If one cannot pass without rewriting working code for no gain, it stays on its current major, with the reason in the ADR.

## D. Release

1. API deploy (streak calendar, upgrades), then the admin deploy.
2. APK 1.0.0-beta.4.8 (26), website and blog post, announcement.
3. The owner's field check: the October calendar with rest days green, earlier months, rewards showing their pictures, the weight graph.
