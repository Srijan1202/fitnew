# ADR-029 — An iPhone-like look: rounded, translucent blocks with a soft glow (all palettes but Paper); Profile as grouped settings

**Status:** PROPOSED. Owner decisions 2026-10-22; built on `phase-19`. Becomes ACCEPTED when the owner has checked it on the S24.
**Date:** 2026-10-22
**Phase:** 19 (beta; owner request, not in MASTER-SPEC §31)
**Affects:**
- MASTER-SPEC §6.1 (prohibited: uniform rounded cards, glassmorphism, heavy shadows), §6.2 (radius), §6.4 (hairline sections);
- ADR-028 (the brand themes).

---

## Context

The owner (2026-10-22):
- "a bit of iPhone UI vibe";
- "curves in the blocks, little translucent blocks with a light shadow behind, with the highlight colour";
- "more blocks look in the Progress section";
- "completely redesign the Profile page: all the options are at the bottom, make it more convenient"; "add some translucent elements".

**Owner answers:**
- **scope:** the whole look (buttons, sheets, dialogs, the tab bar) plus Progress, Profile and Home rebuilt in blocks now; Training and Nutrition in a later round;
- **Paper stays flat:** exactly the §6 look;
- **Profile:** laid out like iPhone Settings.

## Decisions

| # | Decision |
|---|---|
| D1 | **A style flag per palette, `glass`:** true for every palette except Paper. On Paper every new widget draws nothing extra, so Paper keeps hairlines, square corners and flat sections. |
| D2 | **Radii:** `FitRadius.small` is 14 and `medium` 20 on glass palettes (2 and 4 on Paper). Blocks use 22; sheets and dialogs 28. |
| D3 | **Blocks (`FitBlock`):** a translucent surface with a sheen from the top left: ink at 8.5%→3.5% on dark palettes, white at 86%→62% on light ones. They have a 1 px light edge and a soft shadow in the palette's **glow** colour (lime on FITOS Dark, green on FITOS Light, the pine of Night and Forest, blue on Ocean), drawn outside the shape only. The one block a screen leads with glows more. |
| D4 | **Backdrop (`FitBackdrop`):** two faint pools of the glow colour behind Home, Progress and Profile, so the translucency reads. |
| D5 | **Grids (`FitTileGrid`):** on the canvas, the tiles are separate blocks with a 10 px gap; inside a block they are recessed rounded tiles; on Paper they keep the hairline grid. Home's metrics, recovery and body and Progress's stats use it. |
| D6 | **Progress:** each section's body is a block under its label; records are a block of their own; the weekly report entry is a gold-edged glowing block. |
| D7 | **Home:** the metric tiles are blocks; the empty recovery state and the week are blocks, and the week's done days are accent dots. |
| D8 | **Profile:** a glowing header block (picture, name, goal, sex and birth year, a Premium badge), then the daily targets with Change goal and "About you" as small tiles (trend weight first, §13.2). Settings follow as grouped lists with icons and chevrons: personal details, mess, food; Appearance (the theme picker); App (notifications, health data, time zone); Account (Premium, privacy, feedback); then Sign out on its own. Nothing is lost from the old page; the long fact list became tiles. |
| D9 | **App-wide:** outlined buttons, the segmented control (accent when selected), sheets, dialogs and the floating tab bar (glow shadow) follow the radii and colours above. |

## Consequences

**Good:**
- The look the owner asked for, with Paper unchanged for anyone who prefers it.
- One set of widgets, so Training and Nutrition can follow cheaply.

**Bad / accepted:**
- **§6.1's bans on rounded cards, glassmorphism and shadows are lifted for the glass palettes.** Meaning still comes only from pine, amber and oxide.
- **Training, Nutrition, AI and the forms** get the new radii and colours, but not blocks yet. They look mixed until the next round.
- **There is no real blur behind blocks** (cost in long lists); the tab bar keeps its blur.
