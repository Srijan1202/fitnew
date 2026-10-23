# Beta 3.2 — plan (part 1 of the owner's list)

**Date** 2026-10-23 · **Branch** `phase-19` (beta 3.2 is a phase-19 release) · **Status: awaiting the owner's approval. No code yet.**

The owner listed the first three 3.2 changes and answered four questions (2026-10-23). More changes will follow; this plan grows with them.

| # | Change | Owner's answer |
|---|---|---|
| U | "A new version is available": one tap goes to the website download | **Both**: a pop-up once per new version, then a Home banner until they update |
| C | Active calories: FITOS estimates what a logged workout burned and combines it with Health Connect | **Smart, no double count**; **shown only**, the food target does not change |
| T | Set your own calorie and protein targets | **Calories + protein**; FITOS splits the rest into carbs and fat |

---

## U — Update available (backlog F1)

**Source of truth: the website.** `pnpm build` in `fitos-website` writes `/version.json` from `src/site.ts`, the file that already describes the APK: `{ "version": "1.0.0-beta.3.2", "build": 8, "url": "https://tryfitos.me/download/", "notesUrl": "https://tryfitos.me/blog/…", "released": "…" }`. Every website deploy with a new APK updates it automatically; nothing else to remember per release.

**The app:**
- On start and on resume, at most once every 6 hours, `GET https://tryfitos.me/version.json`. No sign-in, no user data, nothing sent but the request.
- If `build` is higher than the app's own build number:
  - the first time for that version, a dialog: "FITOS 3.2 is out", the notes link, **Update** / **Later**;
  - after that, a slim banner at the top of Home: "FITOS 3.2 is out · Update", with × to hide it for that version.
- **Update** opens `url` in the browser. This needs `url_launcher`, a new dependency, and an Android `<queries>` entry for https.
- Offline, or a bad or missing file: nothing is shown, never an error.
- The minimum-build gate's "Update FITOS" screen (E1) gets the same **Download** button.

**Tests:** newer, same and older builds; the dialog once per version; the banner and its ×; offline; a malformed file; the website test that `version.json` matches `site.ts`.

---

## C — Active calories, combined

**The estimate (core, 100% branch coverage):** `workoutActiveKcal(durationMin, bodyWeightKg, workingSetsPerHour)`.
- Formula: active kcal = (MET − 1) × kg × hours. The "− 1" removes resting energy, as Health Connect's *active* calories do.
- MET from the 2024 Compendium of Physical Activities: **3.5** for typical resistance training (code 02050), **5.0** for dense, vigorous sessions (≥ 20 working sets per hour; code 02052).
- Duration is the session's own (start to finish), capped at 3 hours. Weight is the trend weight.
- Rounded, and always shown with "≈" as an estimate.

**Combined, on the phone only.** Health Connect data never leaves the phone (owner B4, ADR-008), so the sum is computed on the phone, never on the server.
- Today's active kcal = Health Connect's active kcal for the day + Σ over today's completed FITOS sessions of max(0, the FITOS estimate − Health Connect's active kcal *during that session's window*).
- So a watch that tracked the gym session is not counted twice; a phone that only counted steps gets the workout added.
- Without Health Connect: the workouts' estimate alone.

**Shown:**
- Home's activity tile: "≈ 420 active kcal", with "280 phone/watch + 140 workouts" underneath.
- The Health screen: the same split, and a line per session.
- **Not** added to the food target (owner: show only).
- **Not** sent to the server or to FITOS AI.

**Tests:** core (the bands, the cap, no weight, zero minutes); combining (no Health Connect, Health Connect covering the session, partly covering it, two sessions); the tile and the Health screen.

---

## T — Your own calorie and protein targets

**Server:**
- `nutrition_targets` gains `source` (`fitos` | `custom`; migration 0025 with its down migration). History stays append-only.
- `PUT /v1/nutrition/targets/custom {kcal, proteinG}` writes a new row with `source: custom`. Fat and carbs come from core `adjustTargets` (the fat floor of max(0.8 g/kg, 22 % of kcal); carbs take the rest), and fibre is 14 g per 1,000 kcal.
- `DELETE /v1/nutrition/targets/custom` writes FITOS's suggestion again (`source: fitos`).
- **Hard limits (422):**
  - kcal 1,200–6,000;
  - protein 0.6–3.3 g per kg of trend weight, and 30–400 g;
  - protein and the fat floor must fit inside the calories (carbs ≥ 0).
- **Warning only** (shown, allowed): outside FITOS's suggestion by more than ±25 % kcal, or protein outside 1.2–2.2 g/kg.

**What keeps a custom target:**
- A weight or profile change no longer recomputes it. It recomputes FITOS's suggestion only for display ("FITOS would suggest 2,350 kcal").
- The weekly calorie-adjust (TODAY, Phase 12) is not offered while the target is custom.
- **A goal change resets to FITOS's suggestion.** The goal editor says so before saving.

**App:**
- Nutrition → Targets → **Set my own**: two fields with steppers, the carbs and fat they leave, FITOS's suggestion beside them, and any warning.
- **Use FITOS's suggestion** resets.
- Everywhere targets show, a small "your target" mark when custom.
- FITOS AI's context says the target is the user's own.

**Tests:**
- core: the split at the limits;
- API: set, reset, every limit, warnings, a weight change keeping it, a goal change resetting it, no calorie-adjust while custom, history rows, the export;
- app: the editor, warnings, reset, the mark.

---

## Order and release

1. **T** (server first, then the app);
2. **U** (website, then the app);
3. **C** (core, then the app).

Each part is committed with its tests. The API is released when T is done (migration 0025, backward-compatible with 3.1). Then the owner's next 3.2 items are added to this plan. When the list is done: **beta 3.2**, build 8, on GitHub and the website, with a post. The update banner announces it to 3.1+ users from then on (3.1 does not have the check, so the jump to 3.2 is the last one that needs telling).

**Docs:**
- ADR-031 (custom targets and the `source` column);
- amendments: ADR-008 (combined active calories, phone only) and ADR-026 (the update check).

**Not in this part:** eating back workout calories (owner: no); cardio METs per exercise (later: the library has no cardio exercises yet); the Play Store's own updates (sideloaded beta).


---

# Part 2 — the owner's further 3.2 items (2026-10-23)

| # | Change | Owner's answer |
|---|---|---|
| S | Subtle sound and haptics, especially in tracking (rest over) | — (defaults below) |
| F1 | Food searched and not found is flagged and reported, then added in a later release | — |
| F2 | A customer can share a food they add; others see it as a community food | **Immediately, marked Community** |
| F3 | Expand the food database | **All four groups**: Indian dishes, USDA whole foods, gym and protein products, drinks and street food |
| P | Progress charts: 1 week, 1 month, 3 months; 1 week by default | — |
| E | Leg extension "missing", and any other missing exercise | Not found **when adding to a day or routine** |
| I | More app icons: gold and others | **Gold and the extras premium**; standard and White free |

## S — Sound and haptics (subtle)

**Events, in the session:**
- **Rest over:** a soft two-note chime and one short vibration, or the rest notification when the app is in the background;
- **10 seconds left:** one light tick, haptic only;
- **Set done:** a light tap;
- **Personal record:** a slightly firmer double tap;
- **Session finished:** a short three-note chime.

**Elsewhere:** a light tap on toggles and steppers.

**How:**
- The chimes are tiny sounds made for FITOS, bundled with the app, played quietly (−12 dB).
- They follow the phone's notification volume and are **silent in silent or vibrate mode**.
- Haptics use the phone's own haptic engine and follow the system haptics setting. New dependency: `audioplayers`.
- **Profile → Sounds & haptics:** separate switches for sounds and for haptics, both on by default.

**Tests:** each event fires once, nothing fires with the switches off, and nothing fires twice when the app comes back from the background.

## F1 — Missing foods, reported automatically

- When a food search ends with no results, the phone reports the search text (normalised, at most 60 characters, one report per text per user per day). There is no user id in the report row; a rate limit protects it.
- An empty result also offers **Ask us to add "…"**, which reports it with a flag that a person asked.
- **Admin panel → Missing foods:**
  - what people searched for and didn't find, most-wanted first (searches and people), first and last seen;
  - mark each one **added**, **already there** (a spelling the search should match: becomes an alias), or **ignore**.
- Search improves too: Indian spellings (roti/chapati/phulka, dahi/curd…) go in as aliases from the reports.
- Migration with a down migration; API and integration tests; panel page.

## F2 — Community foods (shared at once, marked)

- Creating a custom food gains a switch: **Share with everyone**, off by default. Shared foods are visible to all users at once, marked **Community · unverified**, and listed after FITOS foods in search.
- **Checks before sharing (422):**
  - a name of at least 3 characters;
  - per-100 g values within physical bounds (≤ 900 kcal, macros ≤ 100 g);
  - calories that agree with 4P + 4C + 9F within ±25 %;
  - no duplicate of an existing FITOS food's name, which offers that food instead.
- **Quality:**
  - anyone can **Report wrong numbers** on a community food, and it goes to the admin panel;
  - **Admin panel → Community foods** can **verify** (it becomes a FITOS food), **edit**, or **hide** one. Hidden foods stay in the logs of people who used them.
- **Privacy:** the creator's name is never shown, only "Community". Deleting your account leaves shared foods in place, without any link to you. The privacy policy's food section gets one sentence on this.
- Migration (`foods.visibility`: private, community or hidden); API, sanity-check, report and admin tests; app switch, badge and report.

## F3 — A bigger food database (about 400 more)

| Group | About | Source |
|---|---|---|
| Hostel and everyday Indian dishes | 150 | Estimate ranges from standard recipes, marked as estimates, as Phase 7 did (never verified, never "high") |
| Whole and packaged foods | 100 | USDA FoodData Central (public domain), measured values with the FDC id kept |
| Gym and protein products | 60 | Generic typical label values (whey, bars, peanut butter, oats, soya chunks, paneer, eggs…), no brand tables copied |
| Drinks and street food | 90 | Estimate ranges (chai, coffee, lassi, juices, shakes; pani puri, vada pav, momos, rolls, Maggi…) |

- Every food gets its portions (piece, katori, glass…) and aliases, like the 305 today.
- `foods.manifest.json` and the seed tests check each entry: Atwater consistency, bounds, units, no duplicates.
- **Order:** the missing-food reports from F1 come first once there are any; then the groups above.
- A seed release; the admin edit protection (D5) keeps hand-corrected foods untouched.

## P — Progress windows: 1W · 1M · 3M, default 1W

- `PROGRESS_WINDOWS` gains `7d`; the selector reads **1W · 1M · 3M** and opens on **1W**. The choice is remembered on the phone.
- Every chart and figure on Progress follows the selected window.
- **The "≥ 7 days apart" rule for a change:** in a one-week window, a change shows when the first and last readings are at least 6 days apart (a full week of days). Otherwise the screen says "Too early for a trend this week". Recorded as a decision.

## E — Exercises: findable, and the real gaps filled

**Why leg extension "was missing":** it is in the library and on the live server. But the "Add exercise" picker shares its filters with the Library screen and keeps them. A muscle or equipment filter set in the Library earlier (e.g. Chest) silently hid quad exercises in the picker.

**Fix:**
- the picker opens with **no filters** every time, with the active filters always visible;
- a **Clear filters** line whenever filters are on;
- in a day editor, the day's muscles are offered as **one-tap chips**, never an invisible filter.

**Real gaps added to the library**, each with muscles, equipment, instructions, alternatives and contraindications as in the seed:
- **Chest:** chest dip, Smith incline press, machine fly, decline dumbbell press;
- **Back:** shrugs (barbell, dumbbell), assisted pull-up machine, dumbbell pullover, trap-bar deadlift, rack pull;
- **Arms:** EZ-bar curl, barbell preacher curl, reverse curl, wrist curl, cable hammer curl, close-grip push-up;
- **Shoulders:** upright row, cable Y-raise;
- **Legs and glutes:** hip adduction machine, glute kickback machine, Smith lunge, belt squat;
- **Core:** ab wheel rollout, Russian twist, lying leg raise, cable woodchopper.

That is about 26. **Cardio** (treadmill, cycling, rowing machine…) needs time-and-distance logging rather than sets and reps, so it is **not** in 3.2. It is noted for later, together with cardio calories for C.

## I — App icons

**Free:**
- **Standard:** lime F on black;
- **White:** black F on white.

**Premium:**
- **Gold:** gold F on black, matching the premium rim;
- **Outline:** a lime outline F on black;
- **Midnight:** a lime F on deep navy.

**How:**
- Each icon is rendered from the brand kit (`brand/build_kit.py`): launcher sizes plus the adaptive and monochrome layers.
- Android launcher aliases; **Profile → Appearance → App icon**.
- Switching tells the user the phone may close FITOS once to apply it.
- Losing Premium switches a premium icon back to Standard on the next launch, as themes do.

**Tests:** the choice, premium gating, and the fallback. The alias switch goes through a small platform channel, faked in tests.

## Order for part 2

1. E: the picker fix and the new exercises;
2. P;
3. S;
4. F1, then F2;
5. I;
6. F3, the biggest; it is data work and can ship in a seed release after the app.

Every part is committed with its tests. The API is released as server parts land; beta 3.2 is built when all of it is in.

**Docs:**
- ADR-032 (community foods and missing-food reports);
- amendments: ADR-024 (Progress windows), ADR-027 (premium icons) and ADR-029 (sound and haptics);
- the privacy policy line for F2.
