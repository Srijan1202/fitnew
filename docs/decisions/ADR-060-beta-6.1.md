# ADR-060 — Beta 6.1: rolling cycles, the AI programme builder, a week of mess meals, the monthly PDF, premium early access, and four smaller items

**Status:** Proposed. It becomes ACCEPTED after the owner's check on the S24.

On 2026-11-10 the owner said "do all for next beta" for nine items from BACKLOG. They answered the plan's questions (docs/phase-plans/beta-6.1-plan.md §11) with the recommended choice each time:
- force the update;
- FITOS's own week planner;
- leaving things out from a list, plus one optional free line;
- premium for the AI builder, the week plan and the PDF.

## Decisions

| # | Decision |
|---|---|
| D1 | **Rolling cycles (F2).** <br>• A programme is `week` or `cycle`, with `cycle_start` and `cycle_length` (2–14). A cycle day's `day_of_week` is its place in the cycle (migration 0052). <br>• Core `dayNumberOn` is the one rule for which day falls on a date, and the phone's `Program.dayNumberOn` matches it. <br>• Training ⋯ → Schedule switches either way (`PUT /training/program/schedule`, core `cycleLayout`, presets and on/off steppers), keeping day ids, exercises and history. <br>• Skip today on a cycle moves its start a day. <br>• These follow the dates: TODAY, the next session, the reminders (by date), the streak's rest days, the ring, planned volume (a 7-day average), shared codes (the pattern kept) and the AI context. |
| D2 | **Older apps** can't read a cycle. When 6.1 ships, the server's minimum build goes to 6.1's. |
| D3 | **The AI programme builder** (premium, AI consent, switch `ai-programme`). <br>• `POST /training/program/ai-draft` sends the answers, the goal and experience, and the exercises the person can do (short ids). It never sends a name, weight or history. <br>• Core `readProgrammeAnswer` and `fitProgramme` check and fit the answer (minutes +15 %, each muscle's MRV) and list every change. <br>• Nothing is saved until "Use this programme", which goes through the ordinary `PUT /training/program`. <br>• Its own AI purpose `programme` (migration 0053, 5 an hour). |
| D4 | **A week of mess meals** (premium, switch `mess-week`). <br>• `GET /mess/week-plan` runs FITOS's recommender (core `planWeek`) for every served meal of seven days. <br>• Each meal is planned as if the day's earlier plates were eaten, and dishes from the three days before lose ties. <br>• Each day is marked published or inferred. Today's plates can be logged. Nothing is stored and no AI is used. |
| D5 | **The monthly report** (premium, switch `monthly-report`). <br>• `GET /progress/monthly` covers this month and the 12 before it (core `monthlyReport`). <br>• The phone draws the PDF with the pure-Dart `pdf` package, ink on white with the Cobalt accent, and hands it to the share sheet. It is never uploaded. |
| D6 | **Premium early access.** <br>• A switch is Off, Premium or Everyone (`feature_flags.audience`, migration 0051). <br>• The server lets premium accounts and admins through a Premium switch and refuses the rest (403 `early-access`). <br>• The public config reads it as off, and `GET /me/features` gives the account's own switches. <br>• Profile → Premium names what is in early access. |
| D7 | **E17.** The protein nudge names the dinner dish with the most protein a serving that suits the person (10 g or more). It uses a **published** menu only, through five new lines under the same guardrails. |
| D8 | **E3.** `GET /training/exercises/{id}/history` returns every completed session with a lift. The Lift history screen shows the estimated 1RM over time and each session's sets, opened from Progress → Strength or Your history. |
| D9 | **E23.** `user_preferences.theme_id` (migration 0050) holds the theme, with `auto` meaning Automatic. <br>• The phone applies a choice at once and sends it. A choice it could not send is kept and sent at the next start. <br>• At sign-in the phone takes the account's theme. <br>• Entitlement fallbacks stay on the phone and are never sent. |
| D10 | **E19.** The admin panel edits an exercise's alternatives under §12.6's rules. Equipment and preference links are kept both ways. Every exercise touched becomes the panel's, so the seed leaves it alone. |
| D11 | **Privacy policy 2026-11-10.** <br>• The builder's data going to Gemini. <br>• The theme choice kept on the account. <br>• The monthly PDF made on the phone. <br>The same words go in the repo, on the website and in the app, and everyone is asked to agree again. |

## Consequences

**Good:**
- People who train "4 on, 1 off" no longer fight the weekdays.
- The premium tier gains three real features, and the admin can try new ones on premium accounts first.

**Bad / accepted:**
- **The past is read with today's schedule.** A cycle's history, and a week's after a switch, is read that way: the streak's rest days and the weekly report's "planned" for past weeks are approximate, as with ADR-030's weekday shift.
- **A new plan is made on weekdays, then switched.** The generator and the custom builder are unchanged.
- **The AI builder has no fallback plan.** When the model's answer is not a usable week, the screen says so, and the ordinary generator is one tap away.
