# Backlog — improvements parked for later

**Started** 2026-10-20 from the [full audit](audits/2026-10-20-full-audit.md) (owner: "keep the rest in the log, we will come back to it").
**Rule:** nothing here is scheduled. Each item is picked up only when the owner says so; anything that changes accepted behaviour gets its own plan first.

## Waiting on an owner decision

| # | Item | Why it waits | Notes |
|---|---|---|---|
| O1 | **Hosting**: now **AWS** (ADR-025, 2026-10-22) | The owner creates the account, domain and stack and runs every step (docs/hosting/AWS.md); no AWS resource is created without the owner | Everything is prepared on `phase-19` and rehearsed locally. Until the stack exists the app works only on the PC's Wi-Fi. Cloud Run stays ready as the second target. The admin panel (Phase 16) is still local; §20 names Vercel for it |
| O2 | **§18 readiness cap** | Spec consequence | The check-in alone bottoms out at 35 (the reduce band), so rest and escalation need a training or nutrition penalty. Options: count 35 as rest, change the caps, or keep §18 as written |
| O3 | **Merges into `main`** | Explicit approval only | Unmerged, all accepted: `phase-12`, `phase-13`, `phase-13-audit-fixes`, `phase-14`, `phase-15` (2026-10-22). `phase-15` contains all of them, so one fast-forward of `main` to it would bring everything in |
| O4 | **Phase 12 Progress & Recovery UI polish** | Owner: after Phase 13 is accepted | A separate visual pass; not to be mixed into feature work |
| O5 | **Nightly backup schedule** (§24, Phase 17) | Changes the PC's Task Scheduler | `schtasks /Create /TN "FITOS backup" /SC DAILY /ST 23:30 /TR "powershell -NoProfile -ExecutionPolicy Bypass -File \"D:\dev\fit new\scripts\backup-local.ps1\""` |
| O6 | ~~S24 pass on `phase-13-audit-fixes`~~ | Done 2026-10-22 | Covered by the combined Phase 13–15 build the owner passed |
| O7 | **Gemini paid tier (or Vertex AI)** | Owner, 2026-10-21: free tier for the alpha | **Before beta or any user outside the alpha group.** §19.3's privacy rule is suspended only for the alpha (ADR-020 D1). The change is configuration: a paid key in `GEMINI_API_KEY`; `ai_usage` shows real token use for sizing |
| O10 | **Before public launch: legal** | A human must confirm (§23 `UNVERIFIED`) | DPDP Rules obligations and deadlines for this operator; a published contact and grievance officer; the breach notification form to the Board (docs/legal/) |
| O9 | **Server push (FCM)** | Needs the API hosted (O1) | Phase 15 registers tokens (`push_tokens`) but the phone schedules every reminder from the plan (ADR-021 D1/D2). Push would make reminders current even when the app has not synced |
| O8 | **TODAY and recovery in the AI chat context** | §31 Phase 11/13 deferred them to Phase 14; not in Phase 14's task list | Would let the assistant answer "why rest today?" from readiness, but sends more health-adjacent data to the model (free tier, O7). ADR-020 "Not in Phase 14" |

## Engineering (no decision needed, not yet scheduled)

| # | Item | Size | Notes |
|---|---|---|---|
| E1 | Minimum app version in `/meta/config` | S | Flags were built in Phase 16; the version gate is still missing — **needed before beta** |
| E18 | The app reads `/meta/config` flags | S | Phase 16 serves them; nothing in the app switches on them yet |
| E19 | Edit exercise alternatives in the admin panel | S | Phase 16 keeps them as seeded (ADR-022 D6) |
| E2 | `/nutrition/targets` (current + history) | S | §10.1, no owning phase; targets are currently read through `/user/goal` |
| E3 | `/exercises/{id}/history` (full history of a lift) | S–M | §10.1; today only the last three sessions, via `/training/progression/{id}` |
| E4 | §33 pre-caching: tomorrow's plan and the 200 most-used foods | M | Tomorrow's mess menu is already cached ahead |
| E5 | Flutter dependency majors (go_router 14→18, firebase 6→7/4→5, riverpod 3.0→3.4, drift 2.29→2.35, flutter_secure_storage 9→11, connectivity_plus 6→7…) | L | Needs its own pass with device testing; `sqlite3_flutter_libs` is marked end-of-life (drift storage); the Kotlin Gradle Plugin warning comes from the firebase plugins |
| E6 | `fastify-type-provider-zod` 4 → 7 and zod 3 → 4 | M | Majors; not security-driven |
| E7 | Remove the pnpm `overrides` once upstream packages ship the patched transitive versions | S | Root `package.json` (`brace-expansion`, `fast-uri`, `postcss`, `source-map-js`) |
| E8 | Defence in depth: scope id-keyed workout writes (`updateSet`, session exercise updates) by user in SQL | S | The service already checks ownership first (tested); natural fit for Phase 17 |
| E9 | Workout `client_session_id` / `client_set_id` unique per user (food logs already are) | M | Migration + conflict handling; UUIDv4 makes collisions impractical, so low value |
| E10 | Session summary tonnage computed on the phone (§30 edge, Phase 5) | S | Display only; could read a server figure instead |
| E11 | Measure and record "< 3 s to log a set" (§38 Phase 5 box still open) | S | Device stopwatch run on the S24 |
| E12 | Split the largest screens (log_food 1,011 lines, what_to_eat 851, eat 820, workout_week 729) | M | Maintainability only; behaviour-neutral refactor |
| E13 | Food database gap: 305 of ~500 foods; licensing not confirmed (§38 Phase 7) | L | Needs licensed Indian data (Phase 7 report) |
| E14 | §38 Phase 0 open boxes: Neon staging/prod, the extra Firebase projects, Cloud Run region verification | — | Follow O1 (hosting) |
| E15 | Reading GitHub CI from this PC | S | The public API allows 60 calls an hour; installing `gh` (authenticated) would make CI checks reliable |
| E16 | `tsx` "module.register() is deprecated" warning | S | Upgrade tsx when convenient |
| E20 | Golden tests for `MetricDisplay`, `EstimateRange`, `LedgerRow`, `ConfidenceBar` (§26.4) | S | The components do not exist yet; write the goldens with the design-system pass (O4, ADR-024 D4) |
| E21 | Re-run the load test against the hosted API | S | Phase 19, after O1; `load:test` measures the local stack (ADR-024 D5) |
| E17 | Name a high-protein dish from tonight's mess menu in the protein nudge | M | Phase 10 suggestions exist on the Eat tab; the planner would need that day's menu at plan time (ADR-021 "Not in Phase 15") |

## Later phases (already in MASTER-SPEC, listed so nothing is lost)

- **Phase 14 (AI features):** built on `phase-14` (ADR-020); recovery and TODAY stay out of the chat context until O8 is decided.
- **Phase 17 (security & privacy hardening):** data export and account deletion are a legal requirement before any public launch (DPDP, §23). Also consent flows, log redaction and secrets in Secret Manager.
- **Phases 15, 16, 18–20:** notifications, admin, test hardening, beta and production.
