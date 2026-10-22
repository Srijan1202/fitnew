# ADR-028 — The app follows the brand kit: FITOS Dark (default) and FITOS Light, Barlow, the kit's logo and icon; Paper kept as an option

**Status:** PROPOSED. Owner decisions 2026-10-22; built on `phase-19`. Becomes ACCEPTED when the owner has checked it on the S24.
**Date:** 2026-10-22
**Phase:** 19 (beta; owner request, not in MASTER-SPEC §31)
**Affects:**
- MASTER-SPEC §6.2 (the default palette, a tenth token), §6.3 (type);
- ADR-027 D8 (themes): the fallback for a lost premium theme.

---

## Context

The owner (2026-10-22), after the brand kit (`brand/`, README there):
- "save the current theme of app as optional";
- "make theme of app as in the brand kit, one bright and one dark version";
- "font, logo and everything according to brand kit";
- "in premium dark the fonts are not visible as they are also same colour".

**Owner answers:** bundle Barlow (downloaded from google/fonts, SIL OFL); **FITOS Dark** is the default for everyone who hasn't chosen.

## Decisions

| # | Decision |
|---|---|
| D1 | **Palettes:** **FITOS Dark** (default; carbon `#0A0D0B`, white type, lime `#C6F432` actions and pine) and **FITOS Light** (paper white `#F5F6F3`, ink `#0B0B0C` actions, pine darkened to `#2F7A18` so it reads as type). Both are free. **Paper** (the §6.2 original) stays, free. Night, Forest and Ocean stay premium. |
| D2 | **A tenth token, `accent`**, with `onAccent`: the primary action and the selected tab. It defaults to ink and paper, so every palette except FITOS Dark looks exactly as before. pine, amber and oxide keep their meanings. |
| D3 | **Fallback:** a premium palette the user no longer has falls back to the brand palette of the same brightness (Night → FITOS Dark; Forest, Ocean → FITOS Light), not to Paper. A saved choice is kept; a phone that never chose opens in FITOS Dark. |
| D4 | **Type:** Barlow 400/500/600/700, bundled (`apps/mobile/assets/fonts`, `OFL.txt` beside it), for all text and as the theme's default family. Metrics are Barlow SemiBold. Bahnschrift is Microsoft's and can't ship in an app. |
| D5 | **Logo:** `FitosWordmark` draws the kit's mark (two italic blades) and FITOS capitals as paths, ported from `brand/build_kit.py`. The brand palettes draw the mark in the lime gradient; the others in ink (the kit's minimal logo). |
| D6 | **Icon and splash:** `tool/brand.py` now renders the kit's bold app icon (gradient F on carbon), the adaptive foreground and monochrome, and the splash mark from the kit's geometry. The adaptive background and the splash are carbon. |
| D7 | **The dark-text bug:** `FitTypography.textTheme` was a static field, built once with the first palette's ink, so Night showed dark type on a dark canvas. It is now a getter. The tab bar's fixed Paper colour (light labels on a light bar on Night) now comes from the palette, and the status-bar icons follow the palette's brightness. |

## Consequences

**Good:**
- The app, the icon and the kit are one brand.
- Every existing palette still works, and Paper users see no change in colour.

**Bad / accepted:**
- **§6.2's light-foundation decision is reversed for the default.** Paper is one tap away in Profile.
- **The type changes for everyone** (it was the platform's sans-serif): about 420 KB more in the APK.
- **The splash is carbon** for every user, including FITOS Light and Paper users, because it shows before the app reads the choice.
