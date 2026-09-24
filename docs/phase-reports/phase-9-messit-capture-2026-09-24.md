## PHASE 9 — MessIT fresh capture and drift check (2026-09-24)

**Purpose.** The owner asked for a fresh read-only capture of all six MessIT endpoints before any
Phase 9 code, compared against the 2026-09-07 fixtures. If the format had changed in a way that
affects the approved design, work was to stop.

**Verdict: no drift that affects the approved Phase 9 design.** The response *format* is identical to
§14.1. The *content* has changed a lot, but in ways the approved design already handles, so
implementation proceeds. The details are below.

### How it was captured

- 2026-09-24 06:16 UTC. One `GET` per endpoint, with no auth, no cookies and no user data (User-Agent
  `FITOS-capture/1.0`). All six returned `200 application/json` through Cloudflare, with an `ETag`,
  `Cache-Control: public, max-age=0, must-revalidate` and no `Last-Modified`.
- The bytes are saved **verbatim** in `packages/core/test/fixtures/messit-2026-09-24/` with a
  `capture.json` manifest (URL, bytes, SHA-256, ETag, date range).
- The 2026-09-07 fixtures in `packages/core/test/fixtures/` are **unchanged**, and every existing test
  still uses them.

### Format (the §14.1 contract): unchanged

| Check | All six endpoints |
|---|---|
| Top level | `{hostel: int, mess: int, menu: list}`, the same keys and no new ones |
| Day | `{date: "YYYY-MM-DD", menu: list}`; every date is well-formed, none are duplicated |
| Entry | `{type: int, menu: string}`, the same keys; `type` is only 1–4 |
| Entries per day | always 4 (one per slot) |
| Core `isMessItResponse` | accepts all six |
| Core `detectCycleLength` | 14 on all six |

### Content drift (what changed since 2026-09-07)

| # | Change | Design impact |
|---|---|---|
| 1 | **Every endpoint now publishes the whole month** (2026-09-01 → 2026-09-30, 30 days) and covers today. The stale men's special and non-veg endpoints (August only on 2026-09-07) are current. | None. The freshness classification and the three menu states stay. Dates after 30 Sep are cycle-inferred (2026-10-02 is inferred from 2026-09-18 on all six). |
| 2 | **Past dates were edited retroactively.** No overlapping date is byte-identical: 0 of 25 overlapping days across the four endpoints that overlap. | None for history: logs keep their Phase 8 snapshot. A changed payload is a new `mess_menu_snapshots` row (D3), and a past date is read from the newest snapshot that contains it (D5), so a past day shows the menu *as currently published*. |
| 2a | Spelling fixes: Panneer → Paneer, Chat → Chaat, Makani → Makhani, Sai → Shahi Kurma, Jal Frezi → Jalfrezi, Bindi Dopiyaza → Bhindi Do Pyaza, Subji → Subzi, Beet Root → Beetroot. | These produce new dish slugs, which are new `mess_dish_nutrition` rows. The "already logged ✓" mark on a *past* day matches by slug, so a log made before a rename isn't ticked against the renamed dish. It's cosmetic; the log itself is unaffected. |
| 2b | Every breakfast now ends with "Bread, Butter, Jam, Tea, Coffee, Milk", and every snack with "Tea, Coffee, Milk". | None. Core already marks these as ambient items (`isAmbient`), which are loggable but de-emphasised. |
| 2c | A real menu change: men's veg 2026-09-18 snack "Masala Vada" → "French Fries". "Brown Bread" was dropped from the women's 09-06/09-20 breakfast. | None. It's evidence that the upstream edits past days (row 2). |
| 3 | **Upstream cleaned most of the §14.2 defects** (counts across all six captures): | None. The parser still handles all nine (the old fixtures keep them under test), because they were real and can return. |
| | · label spacing: only `Veg:`, `Non Veg:` and `Sweet:` now (was `Veg : `, `Veg :  `, `Non Veg : `, `Sweet :  `…) | |
| | · `,,` 0 (was 10) · space before a comma 0 (was 4) · orphan "White," 0 (was 2) · "/" alternatives 0 (was 2) · duplicate within a meal 0 (was 1) · unsorted dates 0 endpoints (was 4 of 6) | |
| | · still present: "Veg. Cutlet (2 Nos)" (a period and a count in the name) | |
| 4 | The men's special mess (1-1) has **no diet labels**; its non-veg items are unlabelled ("Scrambled Egg"). | None. The keyword classifier finds them (21 non-veg and 37 egg dish-occurrences in the month), as §14.5 intends. |

### What the existing core parser makes of the fresh data (read-only run)

| Endpoint | Dish occurrences (30 days) | Ambient | Diet `unknown` | No estimate | Role-fallback estimate |
|---|---:|---:|---:|---:|---:|
| 1-2 men's veg | 984 | 291 | 0 | 5 | 19 |
| 1-3 men's non-veg | 1020 | 286 | 90 | 8 | 19 |
| 1-1 men's special | 1161 | 305 | 158 | 20 | 22 |
| 2-2 women's veg | 972 | 290 | 0 | 4 | 24 |
| 2-3 women's non-veg | 1000 | 290 | 109 | 8 | 18 |
| 2-1 women's special | 1142 | 305 | 162 | 18 | 29 |

- **294 distinct dishes** across the six endpoints.
- **12 have no estimate at all.** Core returns `null` for the `other` role: Subzi, Dry Jamoon, Kova
  Mysorepaku, Rasagulla, Green Veg Subzi, Badusha, Idiyappam, Stew, Salna, Urapadai, Mint Lemon,
  Pineapple Pudding. These are shown without an estimate and **can't be tap-logged** (quick add
  still works). Under D9, entries are added to the table only for such observed dishes, each with its
  reasoning.
- **15 use a role fallback** (a generic estimate with no gram weight: servings only, low confidence).
- **20 match a table entry marked `high`.** The medium cap is enforced structurally (API and database).
- **Diet `unknown`** appears only in the non-veg and special messes, for dishes the classifier can't
  place (for example Veg Puff, Soups, Cake). It's shown as "unknown" and never as veg (§14.5, D16).

### Conclusion

The format is unchanged; the approved design (D1–D23 with the owner's clarifications) stands. The
content findings are handled by the design and recorded here. Phase 9 implementation proceeds on
`phase-9`.
