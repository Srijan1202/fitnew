# Beta 6.1 plan — rolling cycles, the AI programme builder, a week of mess meals, the monthly PDF, premium early access, and five smaller items

**Status:** GO. The owner said "do all for next beta" and answered §11 on 2026-11-10 with the recommended answer each time: force the update, FITOS's own week planner, the list plus one free line, and premium for the AI builder, the week plan and the PDF. Q1 is not asked and takes its recommended answer.
**Date:** 2026-11-10
**Owner, 2026-11-10:** "do all for next beta". The nine items:
1. F2: rolling cycles
2. the AI programme builder
3. the weekly mess meal plan
4. the monthly PDF report
5. premium early access
6. E17: the protein nudge names a dish
7. E3: a lift's full history
8. E23: the theme saved on the account
9. E19: editing exercise alternatives in the admin panel

Items 2–5 are from E22.

Each section says what changes, where, and how it is tested. The decisions only the owner can make are in §11; the plan follows the recommended answer until told otherwise.

---

## 1. F2: rolling cycles ("4 on, 1 off")

Today a programme is 7 weekdays (`program_days.day_of_week` 1–7, unique). Skip today moves the whole week one weekday later (ADR-030). A cycle drops the weekdays: day 1, day 2 … day N, then back to day 1.

| # | Change | Detail |
|---|---|---|
| C1 | **The model** | `programs.schedule`: `week` (today's behaviour, the default) or `cycle`. <br>• A cycle programme has `cycle_start`, the date of its day 1. Its days carry `position` 1…N, where N is 2–14 (§11 Q1). <br>• Weekly programmes are untouched. <br>• Migration **0052**. Its down migration refuses while a cycle programme exists. |
| C2 | **Which day is today** | Core's `cycleDayFor(date, cycleStart, length)` gives ((date − start) mod N) + 1, in the user's zone, with 100 % branch coverage. Every reader asks core and never computes this itself. |
| C3 | **The server sends dates** | `GET /training/program` gains `schedule`, `cycleLength` and `upcoming`. `upcoming` lists the next 14 dates, each with its day id or rest. <br>• The week strip, TODAY, the reminders and Home's widget read dates, not weekdays. <br>• Weekly programmes fill `upcoming` the same way, so one code path serves both. |
| C4 | **Skip today on a cycle** | Moves `cycle_start` one day later, so everything after today moves a day. Undo moves it back the same day. ADR-030's rules all still apply: only today, once a day, not with a session open or after training today. |
| C5 | **Choosing a cycle** | <br>• "How do you want to train?" asks **Weekdays** or **Days on / off**. The presets are 2 on 1 off, 3 on 1 off, 4 on 1 off, 5 on 2 off and 3 on 2 off, plus **Custom length**. <br>• The generator fills the training days in the same split order (push, pull, legs…). <br>• The custom builder gets a Weekdays \| Cycle switch, with days added and removed one at a time. <br>• An active programme can switch either way under Training ⋯ → **Schedule**. A confirmation shows the next 7 days. |
| C6 | **Everything that counts weeks** | <br>• **Volume per muscle:** a 7-day average, the sets in one cycle × 7 ÷ N. The §12.3 landmarks are checked on that. <br>• **Mesocycle and deload:** stay on calendar weeks. <br>• **Weekly goal ring:** the planned sessions are the cycle's training days that fall in this Monday–Sunday. <br>• **Recovery load, the streak's rest days, the AI context and the weekly report:** each reads `upcoming` or the dates of completed sessions. Each has its own test with a 5-day cycle. |
| C7 | **Shared programmes** | A FIT-code keeps `schedule` and the cycle length. Using a cycle code starts its day 1 today. The website preview lists "Day 1 … Day N". |
| C8 | **Running plans** | Plan runs keep their weekdays. A cycle gym day and a plan run can land on the same date, as a gym day and a run can today. |
| C9 | **Older apps** | An app before 6.1 can't read a cycle programme. Recommended: raise the minimum build when 6.1 is out (§11 Q2), so every phone updates first. |

## 2. The AI programme builder (premium)

| # | Change | Detail |
|---|---|---|
| A1 | **The questions** | Training ⋯ → **Build with FITOS AI**, and a fifth choice on "How do you want to train?". It asks: <br>• the goal (prefilled from the profile); <br>• weekdays or a cycle, and how many days; <br>• minutes per session; <br>• muscles to bring up (optional); <br>• **exercises to leave out, picked from the list** (§11 Q4); <br>• one optional line, "anything else?". |
| A2 | **What the model gets** | <br>• The answers. <br>• The training setting's equipment. <br>• The catalogue filtered to that equipment, as id, name, primary muscle and pattern only. <br>It gets no name, body weight, history or logs. |
| A3 | **What it returns** | A structure only: days, session names, exercise ids in order, sets, rep ranges and target RIR. Weights are never included, as with every FITOS plan. |
| A4 | **FITOS checks it** (§19.2) | <br>• Every id exists, is not retired and suits the equipment. <br>• Sets, reps and RIR are within the generator's bounds. <br>• Weekly sets per muscle are within the §12.3 landmarks. <br>• No day runs over the minutes asked for by more than 15 %. <br>A plan that fails is repaired once (the bad exercise is swapped for one of its alternatives, or sets are trimmed). If it still fails, the deterministic generator builds it instead, labelled as such. |
| A5 | **The preview** | The same screen as a shared programme, with days, exercises and sets, plus "Why this plan" in two or three lines from the model. Under it are **Use this programme** and **Ask again**. Using it goes through `putCustom` (source `custom`, ADR-034 D5), and the old programme is kept. |
| A6 | **Limits** | AI purpose `programme`: 5 a day. It needs AI consent and premium. Migration **0053** adds `programme` to `ai_route`. |

## 3. A week of mess meals (premium)

| # | Change | Detail |
|---|---|---|
| M1 | **FITOS plans it, not the AI** (§11 Q3) | Core's `planWeek` runs the mess recommender (Phase 10, ADR-015/016) for each served meal of today and the next six days, in meal order. It counts the day's earlier plates as eaten, so a day's plates share the day's targets the way the recommender splits them. <br>• A dish planned (or eaten) in the three days before loses ties, through the recommender's own variety term, so the week varies. <br>• The numbers are FITOS's own, and no AI quota is used. <br>• 100 % branch coverage. |
| M2 | **`GET /v1/mess/week-plan`** | Gives 7 days, each with its served meals, each meal with its plate (the recommendation's own plate shape) and status, and the day's totals. <br>• Each day is marked **published** or **inferred from the menu cycle**, and an inferred menu is never shown as published. A day without a menu has no meals. <br>• It uses your mess, or `?mess=`. <br>• Premium only, with its own switch (`mess-week`). Nothing is stored. |
| M3 | **In the app** | Mess → the **This week** button (a calendar icon) opens a day strip, then the meals. <br>• Today's meals have **Log this to Lunch** (and so on), through the existing mess log. <br>• Later days are for planning and can't be logged. <br>• A meal with no plate says why ("Nothing at this meal suits your diet and allergies"). |

## 4. The monthly PDF report (premium)

| # | Change | Detail |
|---|---|---|
| R1 | **`GET /v1/progress/monthly?month=2026-10`** | Like the weekly report, for a calendar month: <br>• sessions done against planned (the plan's days per week over the month's days so far), hard sets, weight moved, and the five most-worked muscles (from the weekly volume table, over the ISO weeks whose Thursday is in the month); <br>• personal records; <br>• runs and km; <br>• logged days, protein days, calories within 10 %, and the average kcal of a logged day; <br>• water days at target (the day target from the latest weigh-in); <br>• check-ins and average sleep; <br>• the start and end of the trend weight. <br>Core's `monthlyReport` builds it, with 100 % branch coverage. Premium only, with its own switch (`monthly-report`). This month and the 12 before it are offered. |
| R2 | **The PDF is made on the phone** | The pure-Dart `pdf` package (3.13.1) draws it: ink on white with the Cobalt accent, so it prints the same whatever the theme. Text the built-in font cannot draw is cleaned (`pdfSafe`). It opens the share sheet (`share_plus`, already in the app) to save or send it. **It is never uploaded or stored on the server.** |
| R3 | **Where** | Progress → **Monthly report (PDF)**, under the weekly report. The screen shows the month (earlier ones with the arrows) and **Share as PDF**. |

## 5. Premium early access

| # | Change | Detail |
|---|---|---|
| E1 | **Three states per switch** | Off · **Premium** · Everyone, in place of on/off. Migration **0051** gives `feature_flags` an `audience`. Existing switches become Everyone if on and Off if off. |
| E2 | **The server decides per user** | `features.require(key, request)` lets premium accounts (and admins, premium by role) through a Premium switch, and refuses the rest with 403 `early-access`. Reads that only show or hide something (mess ratings in the menu, community foods in search) ask `isOn(key, userId)` the same way. |
| E3 | **The app** | `/meta/config` stays public, and a Premium switch reads as off there, so older apps hide it. A new signed-in `GET /v1/me/features` returns this account's switches and which are early access. It is re-read whenever the public config is (start, and coming back after 5 minutes). Profile → Premium names the features this account has in early access, and the perks list gains "Early access". |
| E4 | **The admin panel** | The flags page gets the three-way control and a note on who sees what. Turning a switch off keeps its audience for next time. Each change is audit-logged with the audience. |

## 6. E17: the protein nudge names tonight's dish

| # | Change | Detail |
|---|---|---|
| P1 | **The planner picks it** | The reminders are planned on the server (Phase 15) for 7 days ahead. For each date with a **published** dinner menu, the plan names the dish with the most protein a serving that the mess recommender would allow on this user's plate (diet, allergens, dishes they dislike, a FITOS estimate). Core's `proteinDishOf` does the pick, with 100 % branch coverage. |
| P2 | **New lines** | Three cheeky and two gentle, for example: <br>• cheeky: "Protein has entered the mess: {dish} is on tonight's menu. About {protein} g protein a serving."; <br>• gentle: "{dish} is on tonight's mess menu, about {protein} g protein a serving." <br>When there is a dish, these lines are chosen; when there is not, today's lines are. They are under the same no-body-talk rules (`BANNED`, tested). The "why" line names the dish. |
| P3 | **When it isn't used** | <br>• no mess, or no **published** dinner menu. A menu inferred from the cycle may not be what is served, so no dish is named from it; <br>• no dish passes the filters; <br>• the best dish is under 10 g protein a serving. <br>In those cases today's lines are used. A menu that cannot be read never stops the plan. |

## 7. E3: a lift's full history

| # | Change | Detail |
|---|---|---|
| H1 | **`GET /v1/training/exercises/:id/history`** | Every completed session with that lift, newest first, 20 at a time (`before` cursor). Each has the date, the sets (weight × reps, RIR), the top set, estimated 1RM and volume. Abandoned sessions are left out, as they are from records. |
| H2 | **The screen** | Tap a lift in Progress → Strength, or **History** on the exercise's page. <br>• An all-time estimated-1RM chart, with records marked. <br>• The session list underneath. <br>The "last 3 sessions" during a workout stay as they are. |

## 8. E23: the theme saved on the account

| # | Change | Detail |
|---|---|---|
| T1 | **Stored** | `user_preferences.theme_id`: a palette id or `auto` (Automatic). Null means no phone has sent one yet. Migration **0050**. It is set with the existing `PATCH /v1/user/preferences` and read with `GET`. It is part of Download my data and goes with the account (foreign keys). |
| T2 | **The app** | <br>• Choosing a theme saves it on the phone first, as now, then sends it. One that could not be sent is marked with its account and sent at the next start, and is not overwritten by the account's older choice. <br>• At sign-in and each start, the account's choice is applied when it differs. An account that never sent one (everyone before 6.1) takes this phone's. <br>• A theme the account can no longer use (premium lapsed, a reward not earned) falls back to Automatic on the phone, as now. That correction is never sent, so it does not overwrite the account's choice. |

## 9. E19: editing alternatives in the admin panel

| # | Change | Detail |
|---|---|---|
| X1 | **`PUT /v1/admin/exercises/:id/alternatives`** | Takes the whole list, each with a reason (`equipment`, `injury` or `preference`). The app keeps listing them by reason, then name, so there is no order to edit. <br>• It refuses the exercise itself, a newly added retired exercise, duplicates, another movement, no shared primary muscle (§12.6, as the seed's tests), and more than 10.
<br>• An `equipment` or `preference` link is kept both ways: the other exercise gains or loses the reverse. Every exercise touched is marked edited, so the seed leaves it alone. <br>• Audit-logged with the before and after. |
| X2 | **The panel** | The exercise page gets an **Alternatives** section: search to add (same movement only), a reason picker, and remove. It is the only change to the admin panel apart from §5's control. |
| X3 | **Who it reaches** | The app's swap sheet and the AI builder's repair step (A4) read the new list at once. Programmes already made keep their exercises. |

## 10. Privacy, tests and release

- **Privacy:** a new policy version, `2026-11-10`.
  - With FITOS AI on, the programme builder sends your answers, your equipment and the exercise list to Gemini, never your name, weight or history.
  - The theme choice is kept on your account.
  - The monthly PDF is made on your phone and never uploaded.
  - The same words go in the repo, on the website and in the app, and everyone is asked to agree again, as in 5.4.
- **Tests:** new core code with 100 % branch coverage (cycle day, volume average, the week plan, the dish pick). Real-database tests for:
  - every route, with premium and early access checked on the server;
  - a cycle programme read by TODAY, the reminders, the ring, recovery and the weekly report;
  - skip and undo on a cycle;
  - migrations 0050–0053 up and down.

  On the app side, widget tests for every new screen, with the `useRootNavigator` guard kept. Before release, an emulator pass through each feature, as the owner asked for 6.0.
- **Release:** one API deploy (0050–0053), then the app.
  - Everything in the app is Dart, so it **can** go as a Shorebird patch to 6.0. The plan is a **new APK, 1.0.0-beta.6.1 (37)**, because it changes the programme model and goes with the minimum-build raise (C9).
  - The website gets the policy, a post and the release values.
  - **ADR-060** records the decisions.
- **Size:** this is the largest beta so far, about three 5.x betas together. Build order, each step committed and tested on its own:
  1. E19
  2. E23
  3. E3
  4. early access
  5. E17
  6. the PDF
  7. the week plan
  8. rolling cycles
  9. the AI builder (last, because it builds on cycles and E19)

## 11. Owner decisions

| # | Question | Recommended |
|---|---|---|
| Q1 | Cycle lengths | 2–14 days, with the five presets in C5 plus Custom |
| Q2 | Older apps and cycle programmes | Raise the minimum build to 6.1's when it ships |
| Q3 | Who plans the mess week | FITOS's own recommender: exact numbers and no AI quota |
| Q4 | What the AI builder may hear about injuries | Exercises to leave out, picked from a list, plus one optional free line. The line is sent to Gemini, so the screen says so |
| Q5 | Premium only | The AI builder, the week plan, the monthly PDF and early access. Cycles, E17, E3, E23 and E19 are for everyone |
