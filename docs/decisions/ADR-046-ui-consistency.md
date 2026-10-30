# ADR-046 — One header, one canvas: the Training tab and the app's UI made consistent; Paper dropped

**Status:** PROPOSED. The owner asked on 2026-10-30 to make Running consistent with the app, make the Gym / Running switch bolder, and review the rest. They chose the bold pill and all four fixes, and dropped the Paper theme. Becomes ACCEPTED with the owner's check on the phone.
**Date:** 2026-10-30
**Phase:** 19 (after beta 4.5)
**Affects:**
- ADR-028 (brand themes, Paper optional);
- ADR-029 (glass);
- ADR-038 (Training's two halves).

---

## Decisions

| # | Decision |
|---|---|
| D1 | **The Gym / Running switch is bold.** It used to be a thin 40 px segmented bar. It is now a 52 px track with the floating tab bar's canvas, edge and glow. The chosen half is a solid accent block that slides across, with a bold label and icon. That block has the buttons' corners (`FitRadius.small`); the owner found a full pill too round, so the track follows the block's corners outward. Keys are unchanged; `training.mode.thumb` is the block. |
| D2 | **One tab header everywhere:** a small capital label, a large title (`displaySmall`) and the page's action on the right, with no app bar above it. |
| | • **Running:** "RUNNING / Your runs" with settings. |
| | • **Gym:** "SOURCE · WEEK n / the programme" with its menu. With no programme, "TRAINING PLAN / How do you want to train?" no longer has an empty band above it. |
| | • **AI:** "AI / FITOS AI" with New chat, replacing a band that held only the F mark. |
| | • **Nutrition:** "NUTRITION", then the day as the large title with ‹ › beside it. It used to say "EAT" with a centred date. |
| | • Home and Progress already used this header. |
| D3 | **One canvas under every page.** The palette's paper and the two glow pools are drawn once under the navigator (`FitCanvas` in app.dart). A route pushed with its own transition gets its own canvas (`FitPageTransitions`). Scaffolds and app bars are see-through, with the title on the left, so a pushed page's bar sits on the glow instead of a solid band. `FitBackdrop` stays as a marker and draws nothing. The canvas keeps the same tree on every palette, so a theme change never rebuilds the navigator. |
| D4 | **Running's details:** |
| | • "Choose a plan" is a solid button, like Check in. |
| | • HISTORY lines up with the blocks. |
| | • Records rows put the time on the right edge, the day under the distance, and hairlines between rows. |
| | • The km / miles and Steps switches lose their tick, like the app's other switches. |
| | • Profile's bar matches the others: see-through, title on the left. |
| D5 | **Paper is dropped (owner).** It is no longer offered on Profile or Streak & rewards. A phone that kept it opens on FITOS Light (`FitPalette.byId('paper')`). The flat (`glass: false`) code paths stay unused for now. |

## Consequences

- **Dart only:** it can ship as a Shorebird patch on 1.0.0-beta.4.5+23.
- **Website copy:** no longer lists Paper (features, pricing, home).
- **Tests:**
  - Running's tests scroll to the history, now below the header (`toHistory`);
  - the canvas tests read `FitCanvas`;
  - the AI tests scope "FITOS AI" to the conversation.
