# ADR-054 — Beta 5.5: log a meal from a photo ("Snap a meal")

**Status:** PROPOSED. Owner, 2026-11-04: "can we implement food login by image", the answers in `docs/phase-plans/beta-5.5-plan.md`, then "continue". Becomes ACCEPTED with the owner's check on the phone.
**Date:** 2026-11-04
**Phase:** 19 (beta 5.5)
**Affects:** ADR-020 (Describe your meal), ADR-014/015 (the mess table's numbers), ADR-023 (AI consent), ADR-027 (FITOS AI is premium), the privacy policy.

---

| # | Decision |
|---|---|
| D1 | **Snap a meal** sits under Describe your meal on the food log. <br>• It opens the in-app camera first, with Retake and Gallery after. <br>• It is the same screen in photo mode: the draft, the amounts, the include boxes and Add are Describe your meal's. |
| D2 | **A draft first, one tap to log** (owner). Nothing is logged until Add. Portions from a photo are never "high" confidence, so every line says "check this". |
| D3 | **`POST /v1/nutrition/parse-photo`**: a base64 JPEG, PNG or WebP of at most 1.5 MB, the meal slot and the day. <br>• The bytes must be the type they claim, or 422 before anything is spent. <br>• The phone sends the in-app camera's 720p JPEG, or a gallery photo shrunk to 1280 px. |
| D4 | **FITOS's numbers, not the model's.** The model names the foods and the amounts it sees. <br>• Each food goes through Describe your meal's matching: a database food at a portion of its own rows, or the model's estimate within §19.2's bounds. |
| D5 | **The mess menu is the hint** (owner). <br>• When the person has a mess, that meal's menu goes with the photo: numbered dish names and serving labels only. <br>• A dish the model picks is a new **`messDish`** draft line, at the mess table's numbers × the servings (quarters, 0.25–10). The same dish seen twice is one line. <br>• It is logged as one **mess log** for the menu the answer names, so no new entry method and no food-log migration. <br>• A menu number that is not on the menu is no dish. |
| D6 | **The photo is never kept** (owner). <br>• The phone deletes the file as soon as it is read and shows the photo from memory. <br>• The server holds it for the one model call. <br>• Nothing about it is logged or stored; the usage row has the purpose, tokens and model only. |
| D7 | **Premium and consent**, as every FITOS AI feature: premium first, then the AI consent sheet. "Not now" closes Snap a meal without opening the camera. |
| D8 | **Photos are their own AI purpose, `photo`** (migration 0044 adds it to `ai_route`). <br>• 10 an hour (`AI_PHOTO_PER_HOUR`, times the premium multiplier) and at most 20 a day (`AI_PHOTO_PER_DAY`). <br>• The daily token budget still applies. <br>• Down rebuilds the enum without `photo` and drops those usage rows. |
| D9 | **The model:** the parse model (`MODEL_FOOD_PARSE`, else `GEMINI_MODEL`), with 5.4's retries and backup model. Both `gemini-3.6-flash` and `gemini-3.5-flash-lite` read photos. |
| D10 | **Privacy policy `2026-11-04`.** For a meal photo: the photo and, with a mess, its menu's dish names for that meal; FITOS never keeps the photo. <br>• The consent sheet and Privacy & data say the same. <br>• Everyone is asked to agree again. |

## Release

- **API:** migration 0044, the route, images in the provider. Deploy before the app patch, so the server and the phone agree on the policy version.
- **App:** a Shorebird patch to 1.0.0-beta.5.3 (build 33). It is Dart only, because the camera and the gallery picker are already in the APK.
- **Website:** the policy page and a short post.
