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
| D10 | **Training, Nutrition and AI (owner, second round):** Training's day strip is a floating pill bar with the selected day in the accent; the day's header is a glowing block; each exercise is a block, in the plan and in the live session. Nutrition's day total is a glowing block and each meal is a block. AI's prompts are a grouped list, its turns are bubbles (yours tinted on the right, FITOS AI's a block on the left) and its input is a floating rounded field with a round accent send button. Paper keeps hairlines throughout. |
| D11 | **Forms and the remaining pages (owner, third round):** text fields are rounded and filled, with an accent edge when focused. Choice lists (goal, sex, activity…) are one rounded group with an accent check on the chosen row (a square check for multi-select). Chips and segment bars mark the selected item with an accent pill. A hairline section becomes an eyebrow over a block. The goal editor shows its new targets in a glowing block; history shows each session as a block; volume shows each muscle as a block with its status strip inside; food search and the log-food lists (recent, results, saved meals) are one rounded group; "Describe your meal" is a glowing block. |
| D12 | **Onboarding progress (owner):** a 3 px line across the very top of every onboarding step fills to step ÷ 7 in the palette's glow colour (neon lime on FITOS Dark), animating from the previous step. This lifts §6.1's "no progress ring" only for this line; the "STEP n OF 7" eyebrow stays. |
| D9 | **App-wide:** outlined buttons, the segmented control (accent when selected), sheets, dialogs and the floating tab bar (glow shadow) follow the radii and colours above. |

## Consequences

**Good:**
- The look the owner asked for, with Paper unchanged for anyone who prefers it.
- One set of widgets, so Training and Nutrition can follow cheaply.

**Bad / accepted:**
- **§6.1's bans on rounded cards, glassmorphism and shadows are lifted for the glass palettes.** Meaning still comes only from pine, amber and oxide.
- **A few rarely seen pages** (custom food form, exercise browser, health data, privacy, notification settings) get the shared fields, lists and sections, but no layout of their own yet.
- **There is no real blur behind blocks** (cost in long lists); the tab bar keeps its blur.
