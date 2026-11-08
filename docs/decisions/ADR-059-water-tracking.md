# ADR-059 — Beta 6.0: water tracking (F7)

**Status:** Proposed. It becomes ACCEPTED after the owner's check on the S24.

The owner, 2026-11-08, on the recommendation of F7 for 6.0 ("ok do it"). BACKLOG F7: one tap on Home, and a daily target from body weight.

## Decisions

| # | Decision |
|---|---|
| W1 | **One card on Home**, under Today's tiles. It shows the day's water against the target, with a progress bar and the glasses still to go. **+ Glass** adds 250 ml and **−** takes a glass off. Tapping the card opens a sheet with +250 ml, +500 ml, +750 ml, +1 L and −250 ml, and says how the target is set. |
| W2 | **The target** is core's `waterTargetMl`: 35 ml for each kg of the latest weigh-in, rounded to the nearest 250 ml glass and kept between 1.5 L and 4 L. Without a weigh-in it is 2.5 L. The sheet says it is a guide, because heat, sweat and food change the need. |
| W3 | **Stored on the server**, one total a day: `water_logs` (migration 0049), unique on user and local date, 0 to 10 L. It goes with the account (CASCADE), so it is in Download my data and is deleted with the account. A day can be changed up to 7 days back, never ahead, in the stored time zone. |
| W4 | **Offline-first.** A tap changes the total on the phone at once. The total is kept on the phone, per account, until the server has it. The phone sends the day's **total** with `PUT /v1/water/days/{date}`, never a "+250", so a repeated send changes nothing. Taps within 0.8 s are one send. A total the server lacks is sent again when FITOS next opens, or with the next tap. The card says "not synced yet" until the server has it. |
| W5 | **The admin's `water` switch.** When it is off, the card is hidden and the server refuses water (403 feature-off). |
| W6 | **The policy** says FITOS keeps "the water you drink each day" (version `2026-11-08.2`, the second change that day). Everyone accepts it once. The API and the app are released together, as in 5.8, because joining Community and onboarding need the current version. |
| W7 | **Not in 6.0:** water reminders, water in Progress or the weekly report, Health Connect hydration, and FITOS AI context. |

## Release

- **API:** migration 0049. `deploy.ps1` is run just before the app is published.
- **App:** a new release, 1.0.0-beta.6.0 (36), as the owner prefers for a new version.
- **Website:** the post, the policy, and the download.
