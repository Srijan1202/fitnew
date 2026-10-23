# Beta 3.3 — plan

**Date** 2026-10-23 · **Branch** `phase-19` · **Status: approved by the owner 2026-10-23.**

The owner's list for 3.3, and the four questions they answered on 2026-10-23. Records were checked and left as they are: they work, but appear only from the second session of a lift.

| # | Change | Owner's answer |
|---|---|---|
| X | App features switched on and off from the admin panel (backlog F4 / E18) | — |
| H | A streak and a weekly goal ring on Home (F5) | A day counts when **a workout or any food is logged**; planned rest days and Skip today never break it |
| M | Mess menu ratings, 👍/👎 per dish (F6) | **Everyone sees "👍 82 % · 40"**, anonymous |
| R | Share your programme | **A code and a link**; **structure only**: never weights, history or name |

**The 3.3 APK is not put on the website until the owner says so.** That covers `site.ts`, `version.json` and `deploy -Apk`.

---

## X — Feature switches in the admin panel

**What exists:** the `feature_flags` table, the admin **Flags** page, `GET /meta/config` and the app's `flagOn()`. No feature uses them yet.

**The change:**
- **A fixed list of switches,** seeded by migration and all **on** by default:

  | Key | Switches |
  |---|---|
  | `share-programme` | R: share and use shared programmes |
  | `mess-ratings` | M: rating dishes and seeing the results |
  | `streaks` | H: the streak and the goal ring on Home |
  | `community-foods` | sharing a food with everyone, and community foods in search (F2) |
  | `food-requests` | "Ask us to add" and missing-food counting (F1) |
  | `weekly-report` | the premium weekly report |

  The admin page shows each switch's plain name and what it does, with an on/off toggle. Every change is audited, as now.
- **The app hides what is off.** Entry points disappear (buttons, Home cards, menu rows); nothing shows an error. A switch that is off in the middle of a screen hides the control the next time the screen builds.
- **The server refuses what is off** for server-side features (share, ratings, community, requests), with 403 `feature-off`. Turning a switch off therefore works for old APKs too.
- **When phones notice:** the app reads `/meta/config` when it starts and when it returns to the foreground, at most every 5 minutes. A change reaches people within minutes and needs no new APK. Unknown, for example offline, counts as **on**, as `flagOn()` does today.
- **Tests:**
  - each feature hidden when its switch is off;
  - the server's 403 for each server-side feature;
  - the config is re-read on resume;
  - the seeded list matches the app's list.

## H — Streak and weekly goal ring on Home

**The streak** (core, 100 % branch coverage):
- A day **counts** when a workout is completed or any food is logged that day, in the user's time zone.
- A planned rest day and the day used by **Skip today** are **excused**: they neither break nor add to the run.
- Today not logged yet does not break it. Home then says "Log today to keep your 12-day streak".
- The streak is the number of counted days in the current run. Missing a day that isn't excused resets it to 0.
- The server computes it from sessions, food logs and the programme: `GET /home/streak` → `{ current, best, todayCounted }`. Nothing is stored.

**The weekly goal ring:**
- Workouts **done ÷ planned** this week, Monday to Sunday, for example "2 of 4". It fills as sessions complete.
- Tap → Training. Hidden when there is no programme.

**Home:**
- One compact card at the top with 🔥 **12** days and the ring.
- When the streak is 0: "Log a workout or a meal to start a streak". No shaming copy, ever.
- Behind the `streaks` switch.

**Tests:** core cases (rest days, skip day, time zone midnight, gaps, today), API integration, the Home card's states.

## M — Mess ratings

- **On each dish of a served meal** (today or earlier, never a future menu): 👍 / 👎. Tap again to take the vote back; change it any time.
- **One vote per person per dish per mess.** The same dish at another mess is rated separately, because kitchens differ.
- **Everyone sees** "👍 82 % · 40 ratings" on the dish. With fewer than **5** ratings it shows "Not enough ratings yet", so a single vote never decides the number.
- **Anonymous:** results never show who voted.
- **The vote is the voter's own data:** it's in their export, deleted with their account, and **the privacy policy gains a sentence** about it.
- **Admin panel → Mess ratings:** per mess, the best and worst dishes, with counts.
- **Limits:** about 60 votes an hour per user.
- **Data:** a new table `mess_dish_ratings` (user, mess, dish slug, 👍/👎, time), with a migration and its down migration.
- Behind the `mess-ratings` switch, on the server and in the app.
- **Tests:**
  - a vote, then a change, then taking it back;
  - a future menu is refused;
  - the threshold;
  - export and delete;
  - the admin list;
  - the switch.

## R — Share your programme

**Sharing (Training → ⋯ → Share programme):**
- The server takes a **snapshot** of the active programme's structure:
  - the days, rest days and session names;
  - the exercises in order;
  - sets, rep ranges and target RIR per exercise.
- It **never** includes weights, logs, notes, the mesocycle, or who shared it. The snapshot keeps the programme's name; nothing else.
- It gets a code such as **FIT-K7Q2XM**: 6 characters from an alphabet without look-alikes, about 700 million possibilities.
- The phone's share sheet sends: "Try my FITOS programme 'Push Pull Legs': code FIT-K7Q2XM · tryfitos.me/p/K7Q2XM".
- Later changes to your programme are **not** in the snapshot. Share again for a new code. You can **stop sharing** a code (delete it), and an account deletion deletes its codes.

**Using a code (Training → Use a shared programme, or the link):**
- **The link** `tryfitos.me/p/K7Q2XM` is a website page showing the programme read-only (days, exercises, sets and reps) and "Open FITOS → Training → Use a shared programme → enter K7Q2XM". The page reads a new public endpoint, `GET /v1/shared-programmes/:code`. It is rate-limited and returns structure only. CORS is allowed for tryfitos.me only. **This is a website change, separate from the APK,** so it can go live before 3.3 is on the website.
- **In the app:** enter the code, see the same preview, then **Use this programme**. A confirmation says it **replaces your current programme**. Your history, records and weights stay, and your old programme is kept but inactive.
  - The copy becomes your active programme, with `source: shared`.
  - Your own last weights still pre-fill sets, as in 3.1.
  - Exercises your equipment setting excludes are listed in the preview: "needs a barbell".
- **Data:** a new table `shared_programmes` (code, the owner, the snapshot as JSON, created and stopped times) and the `programs.source` value `shared`. Migration and its down migration.
- **Privacy:** the policy gains a sentence about shared programmes. The owner of a code is never shown to anyone.
- **Limits:** creating codes about 10 a day per user; looking codes up about 30 an hour per IP.
- Behind the `share-programme` switch.
- **Tests:**
  - the snapshot has no weights or user;
  - a code round trip;
  - a stopped code returns 404;
  - deleting the account deletes its codes;
  - using a code replaces the active programme and keeps the old one;
  - the public endpoint's limits and CORS;
  - the app's share, enter-code and preview flows;
  - the website page.

---

## Order and release

1. **X** first: the others ride on its switches.
2. **H**, then **M**, then **R** (the biggest; it touches the website too).
3. Each part is committed with its tests and local CI checks (mobile format, lint, codegen, analyze, tests; API typecheck, lint, tests, OpenAPI).
4. **Release:**
   - the API with its migrations, and the switches seeded;
   - the admin panel;
   - the website's `/p/` page, after the API;
   - the APK **1.0.0-beta.3.3 (9)**, built, tagged and given a GitHub release.
   - **Not on the website until the owner says.**

**Docs:**
- ADR-033 (feature switches);
- an ADR-018 amendment (streak and goal ring);
- an ADR-014 amendment (mess ratings);
- ADR-034 (shared programmes);
- privacy policy sentences in the app and on the website.
