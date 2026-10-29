# ADR-041 — Beta 4.1.1: six fixes from the owner's field use of 4.1

**Status:** PROPOSED. The owner reported the bugs and chose the colours on 2026-10-29. Built on `phase-19`. Becomes ACCEPTED with the owner's acceptance of beta 4.1.1.
**Date:** 2026-10-29
**Phase:** 19 (beta 4.1.1)
**Affects:**
- §6.2 design tokens (a fourth semantic colour, `sky`);
- ADR-027 amendment (the app icon);
- ADR-038 (the share picture);
- §33 (reads on a slow network).

---

## Context

On 2026-10-29 the owner reported six problems with 4.1:
- the app crashed when the app icon was changed;
- on a slow connection pages, even Profile, would not open;
- the shared run picture had no route and was zoomed out;
- there was no way to enter measurements in inches;
- photos, once shown, could not be hidden again;
- the weekly-volume colours were confusing: very low and very high were both red, and low and high both amber.

The icon and share fixes need native code, so 4.1.1 is a full APK, not a Shorebird patch. Testers install it through **Update now** (ADR-040 D5), which is also that decision's field check.

## Decisions

| # | Decision |
|---|---|
| D1 | **The app icon switches when FITOS is left.** Choosing an icon is remembered (`AppIcons.request`). The launcher alias is switched only when the user leaves with Home or Recents (`onUserLeaveHint`), or when the app finishes. It is never switched while FITOS is in front, because Samsung's launcher closes the app when the entry it was opened from is switched off, even with `DONT_KILL_APP`. FITOS's own starts (share sheet, gallery, settings, installer) are excluded: every such start passes through `startActivityForResult`, which marks it. The picker says "Your new icon appears on the home screen after you leave FITOS." |
| D2 | **Reads do not wait on a slow network** (`core/network/read_cache.dart`, an adapter around Dio's). The last good answer to each screen's read is kept per user in `cached_json`, which sign-out and account deletion wipe. Screens without a copy of their own (Profile, goal, targets, the programme, templates, exercises, premium, rewards, …) get it after **4 s**, or at once with no connection; the request carries on and its late answer is kept for next time. Screens that keep their own labelled copy (Today, Recovery, Progress, Eat, Mess, Running; Phase 12 D9) get the kept answer only while it is under 15 minutes old. Otherwise their read fails as an unretried timeout after 4 s and they show their labelled copy, instead of the up-to-90 s wait (10 s connect + 20 s receive, three tries). A first read with nothing kept waits as before. A successful write forgets the kept answers under its resource, or under all of `/v1/user` for a user write, so a stale copy never hides a change just made. Sign-in, onboarding, the food search, the AI, shared links and config are never kept. |
| D3 | **The share picture is made with the route in it** (`RouteSnapshot.kt`). `maplibre_gl`'s `takeSnapshot` renders the bare style URL: the route layer added at run time was missing, and the size it was asked for zoomed it out. FITOS now builds a MapLibre `MapSnapshotter` itself. The route (and its end dot) is part of the style; the region is the route's bounds with a margin (more below, where the figures sit); the image is 360 × 360 at 3× = 1080 px with no MapLibre logo, and the attribution is kept. It is made when the share screen opens, so the card shown is the picture shared. Offline, the card keeps FITOS's own drawn route. The app depends on `org.maplibre.gl:android-sdk-opengl:13.5.0`, the version `maplibre_gl` 0.27.1 uses; the two must be kept in step. |
| D4 | **Measurements in cm or inches.** A cm \| in switch appears in Progress → Body and in both measurement sheets. It is kept on the phone. Readings are still sent and stored in centimetres, so the switch changes only how they are shown and typed. The plausibility check (10–250 cm) applies after conversion. |
| D5 | **Photos can be hidden again.** "Hide photos" appears on the Progress card and in the photos screen's bar once they are shown. They still hide by themselves when FITOS goes to the background (beta 3.6). |
| D6 | **A fourth semantic colour, `sky`** (owner: "blue low, green ok, warm high"). Weekly volume runs from too little to too much: very low = sky, low = a paler sky, on track = pine, high = amber, very high = oxide. The two ends never share a colour. Each palette defines `sky`: `#5AB4F5` on dark palettes, `#1F6FB8` on light ones. The Volume screen has a legend, and the Progress heatmap legend is in the same order. |

## Consequences

- 4.1.1 is build 19, a full APK delivered through Update now. The Shorebird release for it is a new release (4.1.1+19), so later patches apply to it.
- Pages open on a slow network from the phone's copy, which may be a little out of date. Labelled screens still say how old their copy is.
- **Field check on the S24:**
  1. Update now installs 4.1.1 over 4.1 and keeps the data.
  2. Choosing an icon does not close FITOS; the icon changes after Home.
  3. With mobile data throttled or in airplane mode, Profile and Training open from the phone's copy.
  4. The share picture shows the route, framed.
