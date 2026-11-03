# ADR-052 — Beta 5.3: Cobalt by default everywhere, premium Violet themes, and a redesigned admin panel

**Status:** ACCEPTED 2026-11-03 (owner's check on the phone, patch 1 included, and in the panel). Proposed as: Owner, 2026-11-01: the request and answers in `docs/phase-plans/beta-5.3-plan.md`, then "ok go this is 5.3 update". Becomes ACCEPTED with the owner's check on the phone and in the panel.
**Date:** 2026-11-01
**Phase:** 19 (beta 5.3)
**Affects:** ADR-047 (the main themes), ADR-028 (the brand), ADR-046 (the panel stayed FITOS Dark).

---

| # | Decision |
|---|---|
| D1 | **Automatic is Cobalt / Cobalt Light.** `FitPalette.forMode` returns Cobalt in the phone's dark mode and the new **Cobalt Light** in light mode. Cobalt Light has a cool near-white paper `#F6F8FC`, navy ink `#0B1220` and the same cobalt actions `#2E6BF0`. Dark and Light stay as free choices. |
| D2 | **Everyone moved once** (owner): the saved theme moves to `theme.v3`. `theme_id` and `theme.v2` are only removed, so every phone opens on Automatic. |
| D3 | **Violet and Violet Light, premium** (owner). <br>• **Violet:** true black, actions `#7C3AED` (deeper than the `#8B5CF6` glow, so white labels reach 5.7:1). <br>• **Violet Light:** paper `#FAF8FF`, plum ink `#170F26`, actions `#7C3AED`. |
| D4 | **The logo's mark follows the theme.** `FitPalette.mark` is a gradient or null (ink): lime on the green FITOS themes, cobalt on Cobalt and Cobalt Light, violet on Violet and Violet Light. |
| D5 | **The launcher icon is the cobalt mark on true black**, and so is the splash. The old lime-on-carbon icon becomes **Classic**, free in the icon picker (`.IconClassic`). An icon someone already chose is kept. |
| D6 | **Profile → Appearance folds away.** It opens closed every time; the closed row says "Automatic · Standard icon" (the theme, then the icon). |
| D7 | **Checked:** AA contrast for the four new themes (`test/core/theme/palette_contrast_test.dart`); the picker and folding in `premium_flow_test.dart`; the icon source guard. |
| D8 | **The brand kit** gains cobalt assets next to the lime ones (`brand/README.md`). |
| D9 | **The website** uses the same tokens. <br>• Cobalt or Cobalt Light, by the visitor's setting; it was dark only before. <br>• The logo, favicon and share image are cobalt. <br>• The class names keep their old words (`lime`, `carbon`, `white`) but now name roles. <br>• The phone screenshots on the site are still the old lime app until new ones are taken. |
| D10 | **The admin panel, redesigned** on the same tokens. <br>• Dark or light by the computer, with a switch to pin one (localStorage, set before the first paint). <br>• An icon sidebar with counts of what is waiting: untriaged feedback, premium requests, corrections, missing foods, demos not yet decided. <br>• A top bar with **Search (Ctrl+K or /)**: pages, a person by email or id, foods, exercises. <br>• A toast after every change the API accepted. <br>• The overview is a dashboard: numbers, then the response rates as bars. <br>• Foods and exercises search as you type, sort by column, and open in a side panel; the `/edit` pages still work. <br>• Support looks up straight from Search. <br>• Exercise demos open large, with ← and → to step through. <br>The API and what an admin can do are unchanged. |

## Release

- **APK:** 1.0.0-beta.5.3 (build 33), a new release, because the launcher icon is native.
- **API:** no change. Migration 0043 (demo rejection notes) ships with whatever API deploy comes next, if not already deployed.
- **Order:** the app, then the website (it announces), then the admin panel (`admin.ps1`).
