# ADR-053 — Beta 5.4: FITOS AI sees today's food, readiness, weight trend and the mess; busy answers retry, then a lighter model

**Status:** ACCEPTED 2026-11-04 (owner's check on the phone: "working"). Proposed as: Owner, 2026-11-03: "Smarter FITOS AI", the answers in `docs/phase-plans/beta-5.4-plan.md`, then "go".
**Date:** 2026-11-03
**Phase:** 19 (beta 5.4)
**Affects:** Phase 8 J17 (the food log not shared with the assistant), ADR-010 and ADR-020 (FITOS AI), the privacy policy.

---

| # | Decision |
|---|---|
| D1 | **Today's food is shared with chat; earlier days never are** (owner: "Yes, today's meals too"). This reverses J17 **for today only**. <br>• The context carries today's totals, what is left of the targets, the meals logged and up to 25 dishes, with a count of any more. <br>• Ranges are kept where the log holds estimates ("1241–1436"). <br>• `foodLogShared` is `'today-only'`; the excluded list names `food-log-history`. <br>• The nutrition tool returns the same projection. <br>• The system prompt says it sees today's log only and never judges, shames or moralises about food. |
| D2 | **Readiness:** today's score, band and advice, and the last 7 check-ins (sleep, sleep quality, soreness, energy, stress). Nothing is made up when there is no check-in. |
| D3 | **Weight:** the trend, the weekly and 30-day change, the days of data and whether the trend is reliable. Never the raw readings. |
| D4 | **The mess and today's menu:** the hostel, the mess, and up to 15 dish names per meal. The menu says whether it was **published**, **inferred** from the cycle, or **none**. The prompt tells the model to say so when the menu is inferred. |
| D5 | **Every part is read through the services**, never repositories, and is scoped to the person asking. A real-database test checks that another user's food never reaches the context. |
| D6 | **Busy answers** (owner: "Retry + lighter backup model"). <br>• A 5xx is retried twice, after about 1 s and then 3 s. <br>• Still busy, or over quota (429), means the backup model `GEMINI_FALLBACK_MODEL` is asked once. <br>• A bad key or any other 4xx is never sent to the backup. <br>• Unset means no backup; the error stands. <br>• The usage row records which model answered. |
| D7 | **The phone says so.** The chat stream gains a `retry` event. The thinking line reads "FITOS AI is busy — trying again…" until the next event. |
| D8 | **The free tier stays** (owner: "Not now, stay free"). The backup is `gemini-3.5-flash-lite`, the lightest stable model, set in Parameter Store. A model name is configuration, never code. |
| D9 | **A new privacy policy version, `2026-11-03`.** The chat clause lists what is sent: the plan and recent workouts, today's check-in and readiness, the weight trend, the mess and its menu, and today's logged food (never earlier days). <br>• It is changed in the same words in the repo, on the website and in the app. <br>• The consent sheet and the privacy screen say the same. <br>• Everyone is asked to agree again. |
| D10 | **Two new starter prompts:** "What should I eat tonight?" and "How much protein is left today?". |

## Release

- **API:** deploy with `GEMINI_FALLBACK_MODEL` set. No migration.
- **App:** a Shorebird patch to 1.0.0-beta.5.3 (build 33), Dart only.
- **Website:** the policy text and a short post; no APK, no announce.
