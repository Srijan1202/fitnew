# ADR-019 — Recovery: a daily check-in, readiness computed on read, advice that never changes the plan

**Status** ACCEPTED 2026-10-22 — Phase 13 passed the owner's S24 manual checks. (Was PROPOSED: written from the Phase 13 audit (2026-09-25) and implemented on `phase-13`. Becomes ACCEPTED with Phase 13's acceptance (S24 manual checks pending).)
**Date** 2026-09-25
**Phase** 13
**Affects**
- MASTER-SPEC: §18 (Recovery), §16.1 (`low-readiness` band), §16.2 (rest-day recovery status), §9.2 (`recovery_logs`), §10.1 (`/recovery/*`), §26.2 (the `low-readiness` persona), §31 Phase 13, §38 (on acceptance only).
- ADR-007: the deload offer gains a third trigger.
- ADR-017: TODAY gains `low-readiness` (engine `today-3`).
- ADR-018: the Recovery section of Progress & Recovery gains the check-in.
- ADR-008/009: unchanged — Health Connect stays on the phone.

---

## Context

**What §18 specifies:**
- an optional daily card — sleep hours, sleep quality, soreness, energy, stress (1–5);
- a deterministic readiness score, 100 minus five capped penalties;
- four bands: ≥ 75 no change; 55–74 an advisory note; 35–54 suggest −1 set on accessories; < 35 suggest a rest day, escalating to a deload check after 3 days;
- the `DECISION` that recovery **never silently changes the plan**.

**What §31 asks of Phase 13:**
- `recovery_logs`, `/recovery/today` and `/recovery/log`;
- the `UserModel` and TODAY extended;
- tests at every band boundary, "low readiness never silently mutates the plan", and graceful degradation;
- acceptance: readiness only from available inputs, recommendations advisory and dismissible.

**What already existed and is reused unchanged:**
- the Phase 6 rep-decline and RIR-drift signals (`training/progression.ts`);
- the Phase 6 deload offer, with accept, decline and snooze (`training/deload.ts`);
- the Phase 12 nutrition adherence (`progress/summary.ts`);
- TODAY's informational-action rules (`recommend/events.ts`);
- the `cached_json` offline view;
- the Progress & Recovery page.

## Decisions

1. **The check-in (D1, D2):**
   - `recovery_logs` follows §9.2: one row per user and local date (UNIQUE), every value optional but at least one present (a check).
   - Sleep 0–24 h with one decimal; the scales 1–5.
   - `source` is `manual` only. It hard-deletes, because it is not in §9.1's soft-delete list.
   - `POST /recovery/log` upserts the local date and **replaces** that day's values. It can be dated up to 7 days back (readiness never looks further), never ahead. Returns 201/200.
2. **Readiness formula (D3–D6):** computed on read, never stored, all integers.

   | Component | Penalty | Max |
   |---|---|---|
   | Sleep debt | 10 × mean nightly shortfall below 7.5 h, over the check-ins of the last 7 local days | 25 |
   | Soreness | 5 × (soreness − 1) | 20 |
   | Energy | 5 × (5 − energy) | 20 |
   | Performance drop | 25 × (rep-decline + RIR-drift points) ÷ (2 × lifts judged) | 25 |
   | Adherence gap | 10 × the share of missed protein/calorie marks (Phase 12 rules) | 10 |

   - **Performance drop** judges a lift only when it was trained in the last 7 days and has three sessions at the same load. Deload-week sessions are left out, as Phase 6 does.
   - **Adherence gap** is nutrition adherence: §17's "adherence" means protein and calories. It covers logged days in the 7 days *before* the day, because today's eating is not finished.
   - **Only available inputs count:**
     - Readiness exists only for a day with a check-in.
     - A component without its input adds nothing and is reported as not available.
     - Sleep quality and stress are logged and shown, but §18's formula has no term for them, so they do not move the score.
3. **Bands and advice (D7):** ready ≥ 75, advisory 55–74, reduce 35–54, rest < 35. The advice is deterministic English from core, never a diagnosis.
4. **Escalation (D8):**
   - Readiness under 35 on 3 consecutive local days adds the deload trigger `readiness`. The run ends today, or yesterday while today has no check-in yet, so a morning without a check-in does not break it.
   - It feeds the existing **offer**: accept, decline, the 7-day snooze and the active week keep their Phase 6 behaviour.
   - Fatigue and MRV are checked first, unchanged.
   - The same state is read by `/training/today`, `/training/volume`, deload accept, TODAY and the AI tools.
5. **TODAY (D9):**
   - Engine `today-3`; the kind `low-readiness` sits at band **89**, beside the session it is about; reason `readiness-low`.
   - It fires only on a training day that is not done:
     - band reduce, when today has accessories (non-compound, not ruled out) → "one fewer set on accessories" (subject `fewer-sets`);
     - band rest → "consider resting" (subject `rest`).
   - **Informational:** accepted or dismissed, never completed. Nothing in the plan changes either way.
   - The rest-day action carries today's readiness (§16.2), with or without a programme.
6. **Health Connect (D10):** never sent. The card shows the phone's sleep as a hint and never pre-fills it.
7. **Mobile (D11):**
   - The check-in and the readiness display live in the Recovery section of Progress & Recovery (ADR-018 D1), above the Phase 12 device context.
   - The check-in is online only and fails clearly. The last `/recovery/today` is cached in `cached_json` and labelled with its time.
   - No new queue; the workout and nutrition engines are unchanged.
   - The Phase 12 page is otherwise untouched; its visual polish is a separate, later pass.
8. **Persona (D12):** `low-readiness` is the 12th TODAY persona, snapshotted.
9. **AI (D13):** recovery data is not added to the AI context (Phase 14).

## Consequences

- **Readiness is reproducible from source rows alone.** Nothing derived is stored, so `rebuild-derived` needs no change.
- **"Never silently mutates the plan" is tested at the API.** The planned sets, the programme's deload columns and `/training/today`'s exercises are identical before and after three poor check-ins, after a `low-readiness` accept or dismiss, and while the deload is offered. Only the user's own deload accept changes anything.
- **The engine version changed** (`today-3`), so every TODAY content hash changes once: the next GET stores new rows, and old ones are kept.
- **Escalation needs a programme,** because a deload is a programme state. Without one, readiness and the rest suggestion still appear.
