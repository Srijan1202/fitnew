# ADR-058 — Beta 5.9: Food · Progress · Recovery in Nutrition, and Community as a tab

**Status:** Proposed. It becomes ACCEPTED after the owner's check on the S24.

The owner, 2026-11-08: "move the community to the progress and recovery section and move progress and recovery to the nutrition; make food as the default and switchable between progress and recovery; last section should be the community which have its own area".

## Decisions

| # | Decision |
|---|---|
| T1 | **The bar** is Home · Training · AI · Nutrition · Community. Community takes the fifth place, which was Progress (since Phase 12), with the trophy icon (`emoji_events`, already in the 5.8 release font). |
| T2 | **Nutrition has three parts:** Food · Progress · Recovery, on the switch that Training uses (`FitModeSwitch`, already N parts since 5.8). It opens on Food, and the choice holds while the app is open. Food is the EAT screen, unchanged. Progress and Recovery are the parts from beta 5.7 (ADR-056), unchanged. Each part is built the first time it is chosen. |
| T3 | **The ways into Progress and Recovery** now open Nutrition with that part chosen: Home's readiness and check-in sleep tiles, and the check-in reminder (Recovery), and the weigh-in and the weekly recap (Progress). The `/progress` route is gone. Progress photos (`/progress/photos`) and the weekly report (`/progress/weekly`) keep their addresses, as screens above the bar. |
| T4 | **Community is a tab** at `/community`, with no back button and room for the floating bar. Its settings and club pages open above the bar. The Home card, the Profile row and the friend-request push switch to the tab. With the admin's `community` switch off, the tab says "Community is switched off for now". |
| T5 | **No server change.** The app change is Dart only, and adds no icon outside the 5.8 font. |
