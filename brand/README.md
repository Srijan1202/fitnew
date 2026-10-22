# FITOS brand kit

Every asset is in `fitos-kit/` twice: as vector in `svg/` and as image in `png/` (PNG at 2x, favicons at their exact size). The two are generated from the same geometry, so they always match.

`fitos-kit/png/brand-kit-overview.png` shows the whole kit on one sheet.

| Part | Files (`<name>.svg` and `<name>.png`) |
| --- | --- |
| Logo (primary, bold and athletic) | `logo-primary-dark` |
| Logo (secondary, minimal and premium) | `logo-secondary-light` |
| Logo mark only | `logomark-bold`, `logomark-minimal-black`, `logomark-minimal-white` |
| Horizontal logo | `logo-horizontal-bold` (transparent), `-bold-on-dark`, `-bold-on-light`, `-minimal-white`, `-minimal-black` |
| Stacked logo | `logo-stacked-bold` (transparent), `-bold-on-dark`, `-bold-on-light`, `-minimal-white`, `-minimal-black` |
| App icons | `app-icon-bold-1-carbon` … `-4-white`, `app-icon-minimal-1-black` … `-4-paper` (1024 px) |
| Favicons | `favicon-bold-{16,32,48,180,512}`, `favicon-minimal-…`; `png/favicon-bold.ico`, `png/favicon-minimal.ico` (16/32/48) |
| Website header | `website-header-dark`, `website-header-light` (1440 × 96) |
| Banner | `banner-dark`, `banner-light` (1500 × 500) |
| Colour palette | `color-palette` |
| Typography | `typography` |
| Design templates | `template-social-post` (1080²), `template-story` (1080 × 1920), `template-slide` (1920 × 1080) |

## Colours

| Name | Hex | Use |
| --- | --- | --- |
| Volt Lime | `#C6F432` | The brand colour: the mark, actions, highlights |
| Electric Lime | `#E4FF52` | Top of the brand gradient |
| FITOS Green | `#5BC62A` | Bottom of the gradient; accents on light |
| Deep Green | `#1E5A1A` | Background glows and shadows |
| Carbon | `#0A0D0B` | Dark background |
| Graphite | `#131814` | Dark surfaces, cards |
| Steel | `#262D27` | Lines and borders on dark |
| Mist | `#8E978F` | Secondary text, taglines |
| Paper | `#F5F6F3` | Light background |
| Ink | `#0B0B0C` | Minimal logo, text on light |

Brand gradient: `#E4FF52 → #C6F432 → #5BC62A`, from the top right to the bottom left.

## Type

- **Wordmark:** custom geometric capitals, drawn as paths. It needs no font.
- **Headings and tagline:** Bahnschrift, a Windows font. On the web use [Barlow](https://fonts.google.com/specimen/Barlow).
- **Body:** Segoe UI. On the web use Inter or Barlow.
- **Tagline:** TRACK TRAIN FUEL IMPROVE, uppercase, with wide tracking.

The headers, banners, templates and sheets set their text in Bahnschrift. On a machine without it, the SVGs fall back to Barlow, then to Segoe UI or Arial. The PNGs are already rendered, so they always look the same.

## Banner photo

The reference banner shows an athlete. A photograph can't be generated, so the banners have a slot for one. Put `banner-photo.png` (a dark or transparent background works best) next to `banner-dark.svg` or `banner-light.svg` and it appears in the middle of the banner. Without it, the banner shows the ghost mark and the lime streaks.

## Rebuilding

```
cd brand
python build_kit.py                 # every SVG and PNG, and the .ico files
python build_kit.py banner-dark     # just the named assets
python build_kit.py --svg-only
```

You need Python 3, Pillow, and Chrome or Edge for the PNG renders. The geometry and palette are in `build_kit.py`; each asset is in `kit_assets.py`.
