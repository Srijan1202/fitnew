# ADR-014 — VIT mess: a snapshot mirror, menus on read, and mess dishes through the Phase 8 snapshot

**Status** ACCEPTED — owner approval of the Phase 9 audit, D1–D23 with the owner's clarifications (2026-09-24)
**Date** 2026-09-24
**Phase** 9
**Affects** MASTER-SPEC §5 (estimate table row), §9.2 (`mess_*` tables, `food_logs`, `food_log_items`), §9.3, §9.4, §10.1 (mess routes, profile PATCH), §14.6, §31 Phase 9, §33, and the mess data-flow diagram. The spec is amended only where it would otherwise contradict what is built (owner D22, the J22 rule); this record holds the reasons.

---

## Context

`packages/core` already parsed, classified and estimated MessIT menus, and
had a VIT provider that fetched live with an in-memory 6 h cache. MASTER-SPEC
§9.2 sketched eight `mess_*` tables — including `mess_days`, `mess_meals`
and `mess_dishes`, which §9.4 itself calls rebuildable caches of the
snapshots — a Cloud Scheduler job, and `food_log_items.mess_dish_id`.

Two facts shaped Phase 9: GCP work is paused (Gate 6.7-3), so no Cloud
Scheduler; and the fresh read-only capture of 2026-09-24
(docs/phase-reports/phase-9-messit-capture-2026-09-24.md) showed the MessIT
format unchanged but its content edited retroactively — past days re-spelt,
items appended, a snack replaced.

## Decisions

### 1. The mirror is a job; Cloud Scheduler is deferred (owner D1)

`apps/api/src/jobs/mirror-mess.ts` (`pnpm mess:mirror`, `node
dist/jobs/mirror-mess.js` in the image) fetches the six endpoints with a
fixed User-Agent and no user data, 10 s timeout each; validates every payload
with core `isMessItResponse` (hardened to check every entry, owner D23) and
that it is the endpoint's own hostel/mess; stores it; records per-endpoint
status; and writes estimates for newly seen dishes. A session-level Postgres
advisory lock keeps two runs from overlapping. The exit code is non-zero only
when every endpoint failed.

It is the shape a Cloud Scheduler → Cloud Run job needs. **Cloud Scheduler is
not set up** — it is a deployment dependency deferred while GCP is paused.
For local and LAN use the API runs the same code on a 12-hour in-process
timer (5 s after boot, then every 12 h), on by default only when
`NODE_ENV=development` (`MESS_MIRROR_INTERVAL_HOURS` overrides; 0 = off).

### 2. No `mess_days`, `mess_meals`, `mess_dishes` (owner D2)

A day's menu is at most four strings. The server picks the snapshot and
parses it with core on read, in well under a millisecond. Storing the parse
would add a rebuild duty, and a stale copy whenever the parser or the
estimate table changes, for no gain in correctness or speed. The spec's
`mess_days (mess_id, menu_date)` index becomes a GIN index on
`mess_menu_snapshots.dates`.

### 3. Snapshots deduplicated by hash; the newest content wins (owner D3, D5)

`mess_menu_snapshots` keeps each distinct payload once per mess
(`UNIQUE (mess_id, payload_hash)`, the hash of the parsed payload), with
`first_seen_at`, `last_seen_at` and the dates it publishes. A repeat fetch
only moves `last_seen_at`. Rows are never updated in content or deleted:
MessIT keeps no history, and this is it.

A date is answered by core `resolveDayFromSnapshots`, most recent content
first:
1. the most recently seen snapshot that publishes the date → `exact`;
2. else the cycle projected from the latest snapshot alone;
3. else the cycle over the recent snapshots together (up to 60), each date
   from its newest copy;
4. else `unavailable`, with the latest published date.

Latest-first matters: MessIT edits published days, so older and newer
copies of the same cycle can disagree, and a union taken first would find
contradictions where the latest payload alone has a clean 14-day cycle. The
union is a fallback for a thin latest payload only. A past day therefore
shows its menu *as currently published*; what the user logged is unaffected
(decision 5).

### 4. Freshness per endpoint (owner D4, D19)

`messes` carries `last_attempt_at`, `last_success_at`, `last_changed_at`,
`last_error` (`unreachable` / `malformed`) and `consecutive_failures`, per
endpoint — freshness differs by endpoint (§14.2), so a provider-level
`last_sync_at` would hide it. "Stale" means no successful fetch in 24 h. It
is reported separately from the menu's resolution (published / inferred /
unavailable).

### 5. A mess dish is logged as a Phase 8 snapshot; the item keeps only its slug (owner D10)

`POST /nutrition/logs` gains `entryMethod: 'mess'` with a mess code, the
menu date and dishes (slug + servings or grams) — no numbers. The server
checks that each dish is on that mess's menu for that date, takes the dish's
stored estimate (`mess_dish_nutrition`) as a per-serving row, and snapshots
it through Phase 8's `resolvePortion` / `snapshotNutrition`. The item stores
the full snapshot as for any food; `food_id` is NULL, `food_source` is
`estimated`, fibre is NULL.

Provenance is `food_log_items.mess_dish_slug text NULL` (CHECK: never
together with `food_id`) and `food_logs.mess_id` (FK, `ON DELETE SET
NULL`; CHECK: only on `mess` logs). There is **no** `mess_dish_id` foreign
key: dishes are parsed from snapshots, not stored, and a key into a derived
table would break when it is rebuilt. No food-library row is created per
dish. Mess dishes are not "recent foods" (those are library foods).

A dish with no estimate cannot be tap-logged (the app says so and points to
quick add). A serving with no weight takes servings only.

### 6. Saved meals keep mess identity (owner D11)

Phase 8 turned any item without a `food_id` into an exact quick add from the
low end of each range. A mess item is now stored as `{kind: 'mess',
dishSlug, name, servings}`; logging the meal re-snapshots the dish's current
estimate as a range. Food and quick-add items are unchanged.

### 7. Estimates: stored per slug, never overwritten, never `high` (owner D6, D7, D8, D9)

`mess_dish_nutrition` is written from core's table the first time a slug is
seen (every successful mirror run tries, so a dish that gains an estimate in
a later release gets its row on the next run) and never overwritten by a
re-run. The medium cap is structural: core `capMessConfidence` on every
stored and logged mess estimate, and a CHECK (`confidence <> 'high'`,
`source = 'estimated'`) on the table. Core's own table labels are unchanged,
because the Phase 7 food seed reads them. Fibre is NULL for every dish.

The table grows only by dishes observed in the live menus (D9): spelling
variants that share an existing estimate (Subzi, Jamoon, Mysorepaku,
Rasagulla, Badusha, Chaat, Mint Lemon, Pudding, Salna) and two new
low-confidence entries (Idiyappam, Stew). They are appended after the base
table so they can never capture a term the Phase 7 seed relies on; the seed
test confirms it. Urapadai stays unestimated: nothing in the table describes
it. No IFCT/INDB (licensing still blocked).

### 8. Corrections are pending only (owner D17)

`POST /mess/dishes/{slug}/correction` stores a report (`kcal`/`protein`/
`carb`/`fat` range, a `diet` class, or `other` with a note) as `pending`,
retry-safe by `clientCorrectionId`, rate-limited to 20/hour. It changes no
estimate. The author sees "report pending" on the dish; nobody else does.
Review (`reviewed_by`, accept/reject) is Phase 16.

### 9. The mess setting is editable and validated (owner D13, D14)

`PATCH /user/profile` accepts `isVitStudent` and `mess`; onboarding's `vit`
answer and the PATCH both refuse a mess the server does not list. The app's
pickers read `GET /mess/providers/vit-vellore/messes`. `/mess/menu` defaults
to the user's mess; `?mess=` browses any mess without changing the setting.

### 10. Offline (owner D18)

The app caches every menu it fetches in its `cached_json` table and fetches
tomorrow's own menu ahead when today's arrives, so both show offline, marked
as the saved copy. Logging a dish offline uses the Phase 8 queue unchanged;
the server validates and snapshots when the log arrives.

§14.6's "client cache: 6 h TTL" belonged to the old design, where the phone's
provider fetched MessIT itself. Now the server is the cache, and the menu
carries per-user state (logged marks, pending reports) that a 6-hour TTL
would freeze. So the app asks the server on every view, and uses its saved
copy only when the server cannot be reached. This is recorded as an
amendment for the owner to confirm.

## Consequences

- MessIT's outage or a malformed payload changes nothing but the reported
  freshness: the stored copy keeps being served.
- A past day's menu can change when MessIT edits it; logged items cannot.
- The `logged ✓` mark on a past day matches by slug, so a log made before an
  upstream re-spelling is not ticked against the re-spelt dish (cosmetic).
- Rolling back 0011 deletes mess logs and meals holding mess items (no 0010
  representation), rebuilds `daily_nutrition`, and rebuilds the enum.
- Deferred: Cloud Scheduler (deployment); correction review and provider
  health dashboard (Phase 16); plate recommendations (Phase 10); IFCT/INDB;
  the redistribution question (§36 Q6, before Phase 19).
