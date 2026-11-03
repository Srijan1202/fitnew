# Beta 5.5 plan — log a meal from a photo

**Status:** owner: "continue" (2026-11-04), taken as go.
**Date:** 2026-11-04
**Owner, 2026-11-04:** "can we implement food login by image — the user can take a photo and the meal will be logged". Answers:
- **A draft first, logged with one tap.** The user can change an amount or remove a food before logging.
- **Premium only**, like the other FITOS AI features.
- **The photo is never kept**: not on the phone, not on the server.
- **The mess menu is a hint** when the user eats in a mess.

---

## 1. The flow

| # | Step | Detail |
|---|---|---|
| F1 | **Snap a meal** | A new button on the food log, next to Describe your meal. It opens the in-app camera (beta 3.8), with "Choose from gallery". The meal slot is the one the user is logging into. |
| F2 | **Reading your plate…** | The photo is sent to the server, which retries a busy model and then asks the backup (5.4). The phone shows "Reading your plate…" throughout; the "trying again" line is chat's only, as only chat streams. |
| F3 | **The draft** | The same screen as Describe your meal: <br>• each food with its portion and its kcal and protein; <br>• low-confidence foods marked "check the amount"; <br>• the meal's total. <br>The user can change a portion, swap a food through search, remove one or add one. |
| F4 | **Log meal** | One tap logs it through the ordinary food-log routes, as Describe your meal does. Database foods go as one search log, mess dishes as one mess log for today's menu, and estimates as quick adds. Offline queue, totals, streaks and the AI context all work as they do now. No new entry method, so no food-log migration. |
| F5 | **Nothing recognised** | "Couldn't see any food in that photo", with Retake and Describe it instead. |

## 2. The server

| # | Change | Detail |
|---|---|---|
| S1 | **`POST /v1/nutrition/parse-photo`** | <br>• The JPEG (or PNG or WebP), the meal slot and the local date. <br>• At most 1.5 MB. The phone shrinks it to 1280 px on the long side first. <br>• Premium and AI consent are required, as for `/nutrition/parse`. |
| S2 | **The model reads foods only** | <br>• The photo goes to Gemini with a photo version of the parse prompt. It returns the foods, the amount each looks like ("1 katori", "2 pieces"), grams if it can tell, and its confidence. <br>• It also returns its own nutrition estimate, used only as the fallback. |
| S3 | **FITOS's numbers, not the model's** | The same pipeline as Describe your meal (ADR-020): <br>• each food is matched to the FITOS database, and its portion is taken from that food's own rows; <br>• a food the database lacks keeps the model's estimate only within §19.2's bounds. <br>Returned as a draft. **Nothing is stored.** |
| S4 | **The mess hint** (owner) | <br>• When the user has a mess, the dish names on that day's menu for that meal go with the photo, numbered, with each dish's serving. <br>• A dish the model picks from the menu becomes a **mess dish** line in the draft (a new `messDish` beside `match` and `estimate`), with the mess table's numbers × the servings. <br>• Only dish names and serving labels are sent; no profile or history. |
| S5 | **The photo is never kept** (owner) | It is held in memory for the one request, then dropped. <br>• It is not logged or saved. <br>• It is not put in the usage row, which keeps only the purpose `photo-parse`, the tokens and the model. |
| S6 | **Limits** | <br>• Photos are their own AI purpose, `photo`: 10 an hour (`AI_PHOTO_PER_HOUR`) and at most 20 a day (`AI_PHOTO_PER_DAY`), times the premium multiplier for the hourly one. <br>• The daily token budget applies as it does now. <br>• Migration 0044 adds `photo` to the `ai_route` enum. Down rebuilds the enum without it, dropping those usage rows. |
| S7 | **The provider** | <br>• `AiRequest` gains `images` (MIME type and bytes), sent to Gemini as inline data. <br>• The 5.4 retry and backup model apply. <br>• `gemini-3.5-flash-lite` also reads photos. |

## 3. Privacy

| # | Change |
|---|---|
| P1 | **A new privacy policy version.** With FITOS AI on, a meal photo goes to Google's Gemini to read the foods, with the mess menu's dish names when you have a mess. FITOS never keeps the photo. |
| P2 | **The AI consent sheet** and Privacy & data say the same thing in one line. |
| P3 | **AI consent off:** Snap a meal asks first, like the other AI features (Phase 17). |

## 4. Tests

- **Provider:** an image becomes an inline-data part; retries and the backup model still apply.
- **Route:**
  - premium, consent and the size limit;
  - a photo with known foods gives a draft with the database's numbers;
  - the mess hint matches a mess dish;
  - "no food" gives an empty draft;
  - nothing is stored (no food log, and the photo bytes appear in no table or log);
  - the photo limits.
- **App:** the button, the camera or gallery, the reading state, the draft and Log meal (`photo` entry method), Retake, and the consent prompt.
- **Live:** on the server after deploy, a real mess plate and a home plate.

## 5. Release

- **API:** the route, the provider's images, migration 0044 (`ai_route` gains `photo`).
- **App:** a Shorebird patch to 5.3 if it stays Dart only (the camera plugin is already in the APK). Otherwise APK 1.0.0-beta.5.5 (34).
- **Website:** the policy page (new version) and a short post.
- **ADR-054:** photo logging, the photo never kept, and the mess hint.

## 6. Limits to say plainly

- **Portions from a photo are rough.** A katori of dal could be 150 or 250 ml. That is why the draft is always shown and amounts are easy to change.
- **Mixed dishes** (a thali, biryani with raita) may show as one or two foods; the user can split them.
