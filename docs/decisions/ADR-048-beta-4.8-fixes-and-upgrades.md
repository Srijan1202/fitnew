# ADR-048 — Beta 4.8: the owner's bugs, polish, and every package brought up to date

**Status:** PROPOSED. Owner, 2026-10-30: "4.8 will be only bug fixing and polishing what we have made", then "go" on `docs/phase-plans/beta-4.8-plan.md`. Becomes ACCEPTED with the owner's check on the phone.
**Date:** 2026-10-30
**Phase:** 19 (beta 4.8)

---

## Bugs (the owner's)

| # | Decision |
|---|---|
| A1 | **The streak is a month calendar.** It shows every day of the month, Monday first, with days to come left blank. ‹ › and a swipe go back to the month the account began; it opens on this month. Core `streakCalendar` covers the first of the joining month (a year at most) to today. It arrives as `calendar` in `GET /progress/streak`; `days` stays for 4.4–4.7. |
| A2 | **A planned rest day shows as rest unless you trained** (a workout or a run). A meal alone no longer turns it "logged". Core `streakDayStatus` takes `trainedDays`. The streak's count is unchanged. |
| A3 | **Rewards show what they unlock** (`RewardArt`), on Streak & rewards and on Badges. Each shows its art: the app icon, the theme's colours, the picture or the rim. A running badge without a reward shows its group's mark. Until earned, the art is dimmed with a lock on top. |
| A4 | **The weight chart fits its readings.** Half-kilogram steps while the readings span under 3 kg; whole kilograms otherwise. The time axis starts at the first reading inside the window. |
| A5 | **Every bottom sheet opens above the tab bar** (`useRootNavigator: true`; 19 of 24 did not). Log weight's Save had been hidden behind the bar. A test in the real shell taps Save with hit-test warnings fatal; it fails without the fix. |

## Polish (found)

- **Streak legend:** missed is an outline, distinct from skipped. The page says once how a day counts.
- **Switches:** unchosen options in plain ink (`segmentedButtonTheme.foregroundColor`).
- **Home:** tiles allow two lines. The streak ring is 72 px, so "this week" fits.
- **Nutrition:** "Today's mess" and Suggested plate sit in one block.
- **Section labels:** flush with their blocks everywhere (FitGroup, FitSection, Profile, Running).
- **Progress:** labels and blocks use the screen margin.

## Upgrades

| Where | Done | Kept back, and why |
|---|---|---|
| Flutter SDK | 3.47.2 → **3.47.8**: CI pin, this PC, the Shorebird release | 3.47.9: Shorebird's newest Flutter is 3.47.8. |
| Flutter packages | camera 0.12.2, go_router 18.1.2, and the transitive ones | geolocator 14.0.1: 14.0.3+ needs a dbus incompatible with connectivity_plus 7.3.2. |
| zod / fastify-type-provider-zod | 3.25 → **4.6**, 4 → **7** | — |
| postgres, @fastify/cors, @fastify/rate-limit, fastify-plugin | **4.0**, **11**, **11**, **6** | — |
| TypeScript | 5.9 → **6.0.3** | 7.0: typescript-eslint supports TypeScript < 6.1. |
| vitest, coverage, Vite | 2 → **5**, 5, **8.3** | — |
| ESLint, @eslint/js | 9 → **10** | — |
| Next.js, eslint-config-next | 15 → **16.4** | — |
| @types/node, tsx | **26**, 4.23.15 | — |
| Node (API image, CI) | 22 → **24 LTS** | — |
| Shorebird CLI | updated | — |

**Consequences of the upgrades:**
- **The API's 422 envelope is unchanged.** Type-provider 7 reports `instancePath` and `message`, mapped back to `path` and `issue`.
- **The OpenAPI document regenerated:** nullable as `anyOf`, unions as `oneOf`. The app's contract test folds both back.
- **zod 4 types a bare schema as `unknown`.** The AI tools keep zod 3's loose args typing, with a comment; the args are still parsed before each tool runs.
- **TypeScript 6 no longer loads Node's types by default.** Core's tsconfig lists them.
- **vitest 5 counts both arms of every `if`, and every function.** Core keeps its 100 % branch gate: `coverage-beta48.test.ts` covers the newly counted cases, and the unreachable ones carry hints stating their invariants.
- **ESLint 10:** one useless assignment fixed.
- **Next 16:** flat config. One new React rule (`set-state-in-effect`) is off, with the reason in the config.

## Release

1. API deploy (`calendar`, the upgrades, Node 24) and the admin deploy.
2. APK 1.0.0-beta.4.8 (build 26) on Flutter 3.47.8, a new Shorebird release.
