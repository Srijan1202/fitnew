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
