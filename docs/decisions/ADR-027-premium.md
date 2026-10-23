# ADR-027 — FITOS Premium: AI, the weekly report, colour themes and three pictures behind an owner-approved premium; profile pictures and the gold rim

**Status:** PROPOSED. Owner decisions 2026-10-22; built on `phase-19`. Becomes ACCEPTED when the owner has checked it on the S24 (the Phase 19 report's manual checks).
**Date:** 2026-10-22
**Phase:** 19 (beta; owner request, not in MASTER-SPEC §31)
**Affects:**
- MASTER-SPEC §19 (FITOS AI is premium-only), §6.2 (premium colour palettes, one of them dark), §9.2 (`users.premium_since`, `premium_granted_by`, `avatar_id`; `premium_requests`), §10.1 (`/premium`, `/premium/request`, `/user/avatar`, `/progress/weekly`, `/admin/premium/*`), §20 (the admin panel's Premium page), §23 (the policy lists premium requests and the picture);
- ADR-020 (AI): every AI route also needs premium.

---

## Context

The owner (2026-10-22):
- "all AI features are locked and you need a premium account";
- users request premium from the AI page and from Profile; the owner approves it in the admin portal;
- premium accounts have a golden rim around the profile picture;
- ten pre-made profile pictures, three of them for premium only;
- suggestions for more premium features.

**Owner answers:**
- premium lasts **until revoked**;
- **admins are premium** automatically;
- the pictures are **illustrated in the app**;
- extras built now: **higher AI limits, a weekly progress report, colour themes**.

## Decisions

| # | Decision |
|---|---|
| D1 | **Premium** is `users.premium_since` (set on approval, cleared on revoke, with `premium_granted_by`) **or** the admin claim on the token. Nothing is stored for admins, and admins can't be revoked here. |
| D2 | **Requests:** `premium_requests` holds an optional message (up to 500 characters), the status (pending, approved or denied), the owner's note (up to 300) and the decision time. A partial unique index allows one pending request per user. Requests are rate-limited to 5 a day. Approving or denying is a single transaction with its audit row. The user sees the note. The rows are the user's (CASCADE): exported and deleted with the account. |
| D3 | **FITOS AI is premium:** each AI route checks premium **before anything else** except the kill switch: before the consent, the action lookup or any model call. A free user gets 403 with issue `premium-required`. `AiBudget.check` repeats the check as a second line. |
| D4 | **Higher AI limits:** premium limits are the existing `AI_*_PER_HOUR` and `AI_DAILY_TOKEN_BUDGET` times `AI_PREMIUM_LIMIT_MULTIPLIER`, default 2. It is a server setting (`set-parameter.ps1`), so no release is needed to change it. |
| D5 | **Pictures:** ten ids in contracts (`AVATARS`, checked by the database). Seven are free (dumbbell, runner, yoga, cyclist, swimmer, boxer, hiker) and three premium (crown, flame, trophy). The app draws each as a Material icon on a coloured disc; the premium three are gold on ink. `PUT /user/avatar` refuses a premium picture without premium (403). Revoking premium clears a premium picture in the same transaction. Without a picture the app shows the initials. |
| D6 | **The gold rim:** a gold sweep-gradient ring with a soft glow around the picture, on Home and in Profile, when the user is premium. |
| D7 | **The weekly report:** a pure core function, `weeklyReport`, under the 100% branch gate. It covers sessions against the plan, the owned muscles by landmark band, records, protein and calorie days (unlogged days are unknown, never misses) and the trend weight. It writes plain sentences with no streaks and no shaming. `GET /progress/weekly?week=` serves the current ISO week or one of the 3 before it (the weeks `/training/volume` covers), premium only. |
| D8 | **Themes:** the nine §6.2 tokens become one `FitPalette`. Paper is the default and the only free palette; the premium palettes are Night (dark), Forest and Ocean. The tokens stay the same nine roles, so pine, amber and oxide keep their meanings. A change rebuilds the whole widget tree in place, with no lost screen. The choice is kept on the phone; a premium palette falls back to Paper when the app learns the user isn't premium. This amends §6.2's "no dark theme" for premium only. |
| D9 | **In the app:** `ensurePremium()` runs before `ensureAiConsent()` at all three AI entry points. The AI tab shows the pitch and the request in place of the chat for a known-free user. Profile gains the picture (tap to change), a Premium card and the theme picker. Progress gains a Weekly report entry with a lock for free users. While the status is unknown (offline), nothing is locked locally, and the server still enforces every rule. |
| D10 | **Admin panel:** a Premium page lists requests filtered by status (pending by default), with who asked and their message. It approves or denies with a note, lists the members with who approved them, and revokes. The request list shows the asker's email and name, because approving needs to know who. Every decision is audited. |

## More premium ideas (not built; for the owner to choose)

- **Programme builder by FITOS AI:** the owner's "generator to AI" plan, premium first.
- **Meal planning for the week** from the mess menus and the targets.
- **Export a monthly PDF report** to share with a coach.
- **Exercise video and form cues** in the library.
- ~~**Custom app icon** (gold).~~ Built in beta 3.2 (amendment below).
- **Early access** to new features through flags (E18), for premium accounts.

## Consequences

**Good:**
- One rule (premium) is enforced on the server and explained in the app.
- The owner controls who gets the AI's Google cost, which matters with O7 open.
- The report and the themes reuse what exists.

**Bad / accepted:**
- **Every user loses AI until approved,** including alpha testers who had it.
- **Themes are kept per phone,** not per account.
- **The palette change touched 80 files mechanically:** `const` was removed where a colour is used. Behaviour is unchanged; visual review is part of the manual checks.

## Not in this decision

- Payment. Premium is free during the beta and approved by hand.
- Server-side theme preference.

## Amendment — app icons (beta 3.2, owner 2026-10-23)

The owner asked for different app icons: a gold one and more, with Gold and the extras premium and a white one free.

- **Five icons,** each built from the brand kit's own designs (`apps/mobile/tool/app_icons.py`, using `brand/kit_assets.py`). The F is the same size as on the standard launcher icon.

  | Icon | Look | Who |
  |---|---|---|
  | Standard | lime F on carbon (the launcher icon until now) | everyone |
  | White | ink F on white (the kit's minimal-2-white) | everyone |
  | Gold | gold F on carbon, in the premium rim's gold | premium |
  | Glow | lime F on graphite with the green glow (the kit's bold-2-glow) | premium |
  | Lime | carbon F on lime (the kit's bold-3-lime) | premium |

  "The extras" became Glow and Lime because the kit already designed them.
- **How the icon changes:** Android has one activity-alias per icon (`.IconStandard`, `.IconWhite`, …), each an adaptive icon. MainActivity is no longer the launcher entry. Exactly one alias is enabled; the manifest enables Standard. `AppIcons.kt` enables the chosen alias first and then disables the others, so the launcher never sees an app with no entry (`DONT_KILL_APP`).
- **The phone keeps the choice.** Nothing is stored in Dart or on the server, the same as the themes (kept per phone).
- **In the app:** Profile → Appearance → App icon shows the five previews. Premium icons show a lock and open the premium sheet for a free user. A note says the phone may close FITOS once while it changes the icon, because some launchers do. The picker is hidden where the icon can't change (`fitos/device` channel missing).
- **Losing premium:** a premium icon goes back to Standard as soon as the app knows the user isn't premium, as the premium themes do (D8).
- **The premium perks** now read "Themes and app icons".
- **Tests:** a source guard keeps the manifest, `AppIcons.kt`, the generated resources and the `AppIcon` enum in step. There are controller tests (refusal, fallback) and whole-app flows for free, premium and losing premium.
- **Accepted:** the monochrome (themed) icon is the same F for all five icons. Some launchers drop the home-screen shortcut and add the new icon in the app drawer.

## Amendment — streak rewards (beta 3.4, owner 2026-10-24)

The owner asked for streak rewards, as **streak-only items** (not premium ones), at **7 · 14 · 30 · 60 · 100** days.

| Days | Reward | What it is |
|---|---|---|
| 7 | **Spark** picture | A small lit flame, in ember |
| 14 | **Ember** theme | A dark palette, carbon warmed through, with ember-orange actions |
| 30 | **Blaze** app icon | The F in an ember gradient on carbon (activity-alias `.IconBlaze`) |
| 60 | **Ember rim** | An ember ring around the picture, worn instead of the gold rim; it can be switched off in Profile |
| 100 | **Century** | A picture, plus a "100 DAYS" badge on Profile |

- **Earned by the best streak ever** (ADR-018's streak, which looks back 400 days). When `GET /v1/progress/streak` is read, every milestone the best run has reached is recorded in `user_rewards` (migration 0030). Each is recorded once and kept forever, even after the streak breaks. Past runs count, so early testers were credited at once.
- **The same for free and premium users.** These are not premium items, and the premium sheet never opens for them.
- **Shown once:** the streak read returns `newRewards`. Home shows "🔥 N days! You unlocked: …" once and refetches the earned list.
- **`GET /v1/user/rewards`** works whatever the `streaks` switch says (ADR-033): what was earned keeps working while streaks are off. Rewards are not *granted* while the switch is off, because the streak endpoint itself is refused.
- **Pictures are enforced by the server.** `PUT /user/avatar` with `spark` or `century` answers 403 `reward-locked` until earned. The `users.avatar_id` check gains both ids; the down migration resets them to none.
- **The theme, icon and rim are checked on the phone,** as the premium themes are (D8). A locked item shows 🔥 and "Reach a N-day streak to unlock the …". An unearned streak theme or icon left on a phone by another account falls back once the earned list is known.
- **Profile:**
  - a **Streak rewards** row ("2 of 5") opens the list, earned or "N more days than your best";
  - an **Ember rim** switch, once earned;
  - the 100-day badge beside the premium badge.
- **Never shaming:** nothing is taken away, and nothing says "lost".
- **Tests:**
  - grants at the thresholds, once, retroactive, and kept with streaks off;
  - the picture lock;
  - the contracts and the app agree on ids and days;
  - the pickers' locks;
  - the celebration shown once;
  - the rim switch;
  - migration 0030 up and down.
