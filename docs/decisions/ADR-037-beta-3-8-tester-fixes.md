# ADR-037 — Beta 3.8: seven fixes from tester feedback

**Status:** PROPOSED. Owner decisions 2026-10-26; built on `phase-19`. Becomes ACCEPTED when the owner accepts beta 3.8.
**Date:** 2026-10-26
**Phase:** 19 (beta)
**Affects:**
- ADR-018 (the streak rule: amended);
- ADR-020 (FITOS AI: a streamed chat);
- ADR-035 (progress photos: the camera);
- ADR-006 (a discarded empty session is deleted);
- `packages/contracts` (`StreakSummary.todayRest`, `POST /v1/ai/chat/stream`);
- the exercise seed (172 exercises).

---

## Context

After beta 3.7 the owner passed on seven items from testers (2026-10-26) and chose how four of them work.

## Decisions

| # | Feedback | Cause | Decision |
|---|---|---|---|
| 1 | "Edit this day" made the set weights disappear until the app was reopened | The day editor saved every exercise without its id, so the server made new rows. Last time's weights are matched to the plan by row id, and the screen kept the old server day | The editor sends each row's id, so the server keeps the row (as the Training screen's own edits already did). After saving, the server's day and TODAY are read again |
| 2 | Cable high-to-low fly missing | Only Low-to-High Cable Fly was seeded | **High-to-Low Cable Fly** (chest-isolation, cable, lower-chest emphasis), linked both ways as an alternative to Cable Fly and Low-to-High (preference), Dumbbell and Band Fly (equipment). Seed: 172 exercises |
| 3 | Logging weight opened Profile | Home's "Log weight" pushed Personal details | A popup: today's weight, then **Add measurements (optional)** (waist, chest, arm, thigh, hip). The weight is saved as Personal details saved it, so the targets follow as before; the measurements go to Progress. If a measurement fails, the weight stays saved and a retry sends only what is missing |
| 4 | The camera closed FITOS ("app closed, continue adding") | FITOS handed off to the phone's camera app, and Android closed FITOS for memory. Beta 3.6 only recovered the photo afterwards | Owner: **a camera inside FITOS** (the official `camera` plugin, 0.12.1). Progress photos and feedback pictures use it; the gallery still uses the picker. The photo is the camera's own JPEG at the high preset (720p on Android), within FITOS's 1600 px. CAMERA is declared; the plugin's microphone and old storage permissions are removed from the manifest. Camera hardware is not required to install |
| 5 | A workout started by mistake could only be resumed | Discard existed only in the session's ⋯ menu | **Discard** beside every Resume (Home's card, Training, TODAY), always after a confirm. Owner: **an empty session vanishes**: with no set logged, the server deletes it (`POST …/abandon` deletes instead of marking it abandoned), so it is in no History or export. One with sets stays in History as abandoned, as before. The phone treats a resend that finds no session (404) as done |
| 6 | "How do I keep the streak on a rest day when there is nothing to do?" | Rest days were excused (no break, no count), but Home said "log today to keep it going" and the evening reminder said the streak was at risk | Owner: **a planned rest day counts by itself.** It counts only when it continues a run, so a rest day never starts one and every streak has something logged in it. Skip today stays excused. `todayRest` is added to `GET /progress/streak`. Home says "Rest day. It counts toward your streak, nothing to log." The "streak at risk" reminder is not planned on a rest or skipped day, and its number counts rest days |
| 7 | FITOS AI answered in one block | The server waited for Gemini's whole answer | Owner: **real streaming.** `POST /v1/ai/chat/stream` answers as server-sent events (see below). `POST /ai/chat` stays for older builds, and the app falls back to it when the stream route is missing (404) |

## The streamed chat (item 7)

- **Same chat, same rules.** It goes through the same loop, tools, premium check, consent, hourly limit and token ledger as `/ai/chat`.
  - A failure before the first event is an ordinary error response.
  - A failure after it is `event: error` with the §10 envelope.
- **Events:**
  - `text` carries the answer so far, as plain text and in full each time.
  - `tool` means a lookup is running, so the text shown so far is cleared.
  - `done` carries the final `AiChatResponse`. This is the answer kept, with its actions.
- **Off-topic answers.** Nothing is shown before 24 characters or while the text carries the `OFF_TOPIC` marker.
  - The model is told to answer an out-of-scope message with the marker alone, so such an answer never shows.
  - If the marker comes later in a longer answer, `done` replaces whatever was shown with the scope reply.
- **Gemini.** It uses `streamGenerateContent?alt=sse`.
  - The timeout runs per chunk: a long answer may take longer in total than one answer took whole.
  - The one 5xx retry happens before any text, since a 5xx is a status code.
- **Proxy.** The response is `text/event-stream` with `Content-Encoding: identity`, so Caddy's `encode` does not hold the events back to compress them. A live check after deploy confirms this.
- **On the phone.** The answer shows in a FITOS AI bubble as it grows, in place of "Thinking…", and the composer stays off until `done`.
  - A connection cut before `done` is a failure with Retry, never a half answer kept.

## Consequences

**Good:**
- Every item the testers raised has a fix.
- Rest days are no longer a source of guilt.
- A camera photo can no longer be lost to Android closing FITOS.
- The first words of an answer show in about a second.

**Bad / accepted:**
- **Streaks are longer by design.** A rest day inside a run adds a day, and a run's best grows with it. Streak rewards (ADR-027) are reached sooner.
- **The in-app camera is simpler than the phone's** (no zoom, flash or HDR controls). Progress photos are 720p.
- **New camera permission.** Android asks for it the first time a photo is taken in FITOS.
- **No sound or video.** The microphone permission the plugin brings is removed.
- **A word can flash.** An off-topic answer that puts the marker after the 24th character can show a few words before `done` replaces them.
