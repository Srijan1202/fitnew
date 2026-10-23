# ADR-034 — Share your programme

**Status** Accepted by the owner on 2026-10-23 (beta 3.3 plan, part R) · **Date** 2026-10-24

## Context

The owner asked for "share your programme". The owner answered two questions: a **code plus a link**, and **structure only**.

## Decisions

| # | Decision |
|---|---|
| D1 | **A snapshot, not a live link.** Sharing stores the programme's structure at that moment: days, rest days, session names, focus, exercises in order, sets, rep ranges and target RIR per set. It **never** stores weights, logs, notes, the mesocycle or who shared it (only `user_id`, for "your codes" and deletion). Later edits are not in it; sharing again makes a new code. |
| D2 | **The code** is 6 characters from `23456789ABCDEFGHJKMNPQRSTUVWXYZ`, with no 0/O or 1/I/L (31⁶ ≈ 890 million). It is shown as **FIT-K7Q2XM**. The database checks the format. The app accepts it typed any way, or the whole link. |
| D3 | **The data:** `shared_programmes` (code PK, user, name, snapshot JSON, created, stopped). Migration 0029 and its down migration. Rows cascade with the account. Stopping a code sets `stopped_at`, and it then answers 404. |
| D4 | **The API:** <br>• `POST /v1/training/program/share`, 10 a day; <br>• `GET /v1/training/program/shares`; <br>• `DELETE /v1/training/program/shares/:code`; <br>• `GET /v1/training/shared/:code`, a preview that also lists, per exercise, the equipment *your* setting lacks; <br>• `POST /v1/training/shared/:code/use`; <br>• public `GET /v1/shared-programmes/:code` for the website: no sign-in, 30 an hour per address, `Access-Control-Allow-Origin: https://tryfitos.me` only. A plain GET needs no preflight. <br>Every one of them sits behind the `share-programme` switch (ADR-033). |
| D5 | **Using a code** makes a copy the user's active programme, through the same path as a custom programme (`putCustom`). The old programme is kept, inactive. Weights start empty, and 3.1's "last time" prefill fills them from the user's own history. **Change from the plan:** the copy's source is `custom`, not a new `shared` value. The beta 3.2 app decodes `source` strictly and would fail on an unknown value, and the copy *is* the user's own from then on. |
| D6 | **The app:** <br>• Training ⋯ → **Share programme**: a sheet with FIT-code, the link, **Share** (the phone's share sheet) and **Copy the code**; <br>• Training ⋯ → **Use a shared programme**, and a fourth way on "How do you want to train?" (**Shared**): enter or paste the code, see the days, exercises and "Needs barbell", then **Use this programme** after a confirmation that says the old programme is kept and the history stays. <br>All of it is hidden when the switch is off. |
| D7 | **The website:** `tryfitos.me/p/<code>` is one static page. Caddy rewrites every valid code path to it, and the browser reads the public endpoint. The page shows the programme read-only with "Open FITOS → Training → ⋯ → Use a shared programme → FIT-…" and the download button. It is not indexed. |
| D8 | **Privacy:** the policy says what a code shows and that codes go with the account. The sharer is never shown. Their codes are in their export. |

## Consequences

- Sharing works from the website before the 3.3 APK is public: the page and the API are independent of the app build.
- A code lives until stopped. There is no expiry; the owner can add one later if codes are abused.
