# ADR-047 — Dark and Light as the main themes, following the phone; Cobalt; the green themes optional

**Status:** PROPOSED. Owner, 2026-10-30. Chosen:
- the neutral main themes;
- Cobalt free;
- everyone moved once.

Becomes ACCEPTED with the owner's check on the phone.
**Date:** 2026-10-30
**Phase:** 19 (after beta 4.6)
**Affects:**
- ADR-027 (themes);
- ADR-028 (FITOS Dark as the default);
- ADR-046 (Paper dropped).

---

## Decisions

| # | Decision |
|---|---|
| D1 | **Two main themes, neutral.** |
| | • **Dark:** near-black `#0B0B0C`, white actions, zinc greys. |
| | • **Light:** near-white `#FAFAFA`, black actions. |
| | • Green, amber and red keep their meanings (good, warning, bad). The logo's mark is in ink, not lime. |
| D2 | **Automatic is the default.** With no theme chosen, Dark in the phone's dark mode and Light in its light mode. It follows a switch of the phone while FITOS is open (`didChangePlatformBrightness`). Profile → Theme shows **Automatic** first; choosing any theme pins it, and choosing Automatic again unpins it. |
| D3 | **Cobalt, free:** true black, cobalt blue actions (`#2E6BF0`, white text), blue glow. |
| D4 | **The green themes are optional:** FITOS Dark (lime) and FITOS Light stay for everyone, after Dark, Light and Cobalt. |
| D5 | **Everyone moved once (owner):** the old saved theme (`theme_id`) is removed and the new one lives under `theme.v2`, so each phone opens on Automatic after the update. A premium or reward theme someone loses goes back to Automatic, not to a green theme. |

## Consequences

- **Dart only:** it can ship as a Shorebird patch on 4.6+24, or with the next release.
- **Website copy** names the new themes; the screenshots stay FITOS Dark until new ones are taken.
- **The admin panel** stays FITOS Dark (ADR-046 follow-up, owner's choice).
