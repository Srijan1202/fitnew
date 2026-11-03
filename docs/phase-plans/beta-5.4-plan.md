# Beta 5.4 plan — a smarter FITOS AI

**Status:** waiting for the owner's "go". No code before it.
**Date:** 2026-11-03
**Owner, 2026-11-03:** chose "Smarter FITOS AI" for 5.4. Answers:
- The AI sees **today's food**: totals and the dishes logged today. This reverses J17 (Phase 8) for today only.
- On busy or quota errors: **retry, then a lighter backup model**.
- **Stay on the free Gemini tier** for now (O7 stays open).

---

## 1. What the AI knows (O8)

Today the chat's context has the profile, targets, the programme, today's session, the last 3 sessions and this week's volume (ADR-010). It gains:

| # | Addition | Detail |
|---|---|---|
| C1 | **Today's food** (owner, reverses J17 for today) | <br>• Eaten against the target: kcal, protein, carbs, fat, fibre; a range where entries are estimates. <br>• Which meals are logged. <br>• The dishes logged today, each with its portion and kcal and protein. <br>• **Never past days.** Never photos or notes. |
| C2 | **Readiness** | Today's check-in and readiness score (sleep, soreness, energy, stress), and the last 7 days' scores, so the AI can say "go lighter today". |
| C3 | **Weight trend** | The trend weight now, its change over the last 4 weeks, and the number of readings. Not every reading. |
| C4 | **The mess** | Where the user eats (VIT hostel and mess), and today's menu dish names when there is one. That way "what should I eat tonight" answers from the real menu. |
| C5 | **Bounded** | Everything stays small. The context has a size test, so it can't grow without notice. |
| C6 | **Rules for the model** | <br>• Food numbers are estimates when the app says so. <br>• Never moralise about food. <br>• Health Connect data still never reaches the server (B4 unchanged). |

## 2. Privacy

| # | Change |
|---|---|
| P1 | **A new privacy policy version**, so the app asks again. It says that, with FITOS AI consent on, today's logged food (totals and dishes) goes with each AI request, and that past days are never sent. |
| P2 | **The AI consent screen** and Privacy & data say the same thing in one line. |
| P3 | **Consent off still means nothing is sent** (Phase 17 unchanged). |

## 3. Busy errors on the free tier

| # | Change |
|---|---|
| R1 | **Two retries on "busy"** (503 and other 5xx), after about 1 s and 3 s, before any text is shown. Never on a bad key or a malformed answer. Today there is one retry. |
| R2 | **A lighter backup model.** <br>• If the main model is still busy, or answers "quota" (429), the same request goes to a lighter Gemini model. <br>• The backup is set by `GEMINI_FALLBACK_MODEL`. I check its name against Google's list of models on the server when deploying; empty means no backup. <br>• The answer says nothing different. The admin's AI usage records which model answered. |
| R3 | **On the phone,** while a retry is under way, the chat shows "FITOS AI is busy — trying again…" instead of a silent wait. Only if everything fails does it show the error, with a Try again button. |
| R4 | **The per-user limits stay the same** (D2–D8): chat 60 an hour, 200k tokens a day. |

## 4. Checks

- API tests for each part of the context, with absent data saying so. The context's size stays under its bound.
- Tests that past days' food and Health Connect data never appear.
- The provider: busy → retry → backup; quota → backup; a bad key gives the error and no backup.
- App: the "trying again" state, and the new consent text.
- A live smoke test on the server after deploy. This is the only way to see real 503s.

## 5. Release

- **API:** the context, the retries and the backup. No migration expected.
- **App:** a Shorebird patch to 5.3 if it is Dart only (the chat state and the consent copy); otherwise APK 1.0.0-beta.5.4 (34).
- **Website:** the privacy policy page (new version) and a short post.
- **ADR-053:** records the J17 reversal (today's food only) and the backup model.
