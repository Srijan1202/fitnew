"""Beta 3.2 (ADR-027 amendment): FITOS's alternative app icons.

Five icons from the brand kit's own designs (brand/kit_assets.py), the F
sized exactly as the standard launcher icon (tool/brand.py):

    standard  lime F on carbon        free (the launcher icon itself)
    white     ink F on white          free
    gold      gold F on carbon        Premium (the premium rim's gold)
    glow      lime F with its glow    Premium (the kit's bold-2-glow)
    lime      carbon F on lime        Premium (the kit's bold-3-lime)
    blaze     ember F on carbon       Streak reward, 30 days (beta 3.4)
    finisher  lime F in a lime ring   Running badge: first 10K (beta 4.2)
    fortyTwo  gold "42" on carbon     Running badge: first marathon (beta 4.2)
    bolt      lime F, amber lightning Running badge: a 5K under 20 min (beta 4.5)

Resource names are the icon's name in lower case (fortyTwo: ic_launcher_fortytwo).
Writes, for every icon but standard (which tool/brand.py already makes):
  android/app/src/main/res/drawable-nodpi/ic_launcher_<name>_background.png
  android/app/src/main/res/drawable-nodpi/ic_launcher_<name>_foreground.png
  android/app/src/main/res/mipmap-anydpi-v26/ic_launcher_<name>.xml
and, for all five, the picker's previews assets/brand/app_icons/<name>.png.
Needs Chrome or Edge, like the kit.

    python tool/app_icons.py                      # all of them
    python tool/app_icons.py finisher fortyTwo    # only these
"""
import sys
import tempfile
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / 'brand'))

import build_kit as kit  # noqa: E402
import kit_assets  # noqa: E402

C = kit.C
MOBILE = Path(__file__).resolve().parent.parent
RES = MOBILE / 'android' / 'app' / 'src' / 'main' / 'res'
PREVIEWS = MOBILE / 'assets' / 'brand' / 'app_icons'
LAYER = 432  # 108 dp at xxxhdpi
GOLD = ('#F1D77A', '#C9A227', '#8A6A12')  # kGoldLight, kGold, kGoldDeep (premium/domain/avatars.dart)


def gold_gradient(gid: str) -> str:
    return (f'<linearGradient id="{gid}" x1="0.85" y1="0.05" x2="0.15" y2="0.95">'
            f'<stop offset="0" stop-color="{GOLD[0]}"/><stop offset="0.45" stop-color="{GOLD[1]}"/>'
            f'<stop offset="1" stop-color="{GOLD[2]}"/></linearGradient>')


EMBER = ('#FFC08A', '#FF7A2F', '#B8400F')  # kEmberLight, kEmber, kEmberDeep (premium/domain/avatars.dart)


def ember_gradient(gid: str) -> str:
    return (f'<linearGradient id="{gid}" x1="0.85" y1="0.05" x2="0.15" y2="0.95">'
            f'<stop offset="0" stop-color="{EMBER[0]}"/><stop offset="0.45" stop-color="{EMBER[1]}"/>'
            f'<stop offset="1" stop-color="{EMBER[2]}"/></linearGradient>')


def lime_bg(gid: str) -> str:
    return (f'<linearGradient id="{gid}" x1="0" y1="0" x2="1" y2="1">'
            f'<stop offset="0" stop-color="{C["lime_hi"]}"/><stop offset="1" stop-color="{C["lime"]}"/></linearGradient>')


# name: (background fill, F fill, extra defs, glow behind the F)
ICONS = {
    'standard': (C['carbon'], 'url(#g)', kit.defs_gradient('g'), False),
    'white': (C['white'], C['ink'], '', False),
    'gold': (C['carbon'], 'url(#gold)', gold_gradient('gold'), False),
    'glow': (C['graphite'], 'url(#g)', kit.defs_gradient('g'), True),
    'lime': ('url(#limebg)', C['carbon'], lime_bg('limebg'), False),
    'blaze': (C['carbon'], 'url(#ember)', ember_gradient('ember'), False),
    'finisher': (C['carbon'], 'url(#g)', kit.defs_gradient('g'), False),
    'fortyTwo': (C['carbon'], 'url(#gold)', gold_gradient('gold'), False),
    'bolt': (C['carbon'], 'url(#g)', kit.defs_gradient('g'), False),
}

# Beta 4.5: a lightning streak behind the F (on the back layer).
BOLT = {'bolt'}
BOLT_COLOUR = '#F5B342'


def lightning(cx: float, cy: float, h: float) -> str:
    # A zig-zag bolt, h tall, centred on (cx, cy), leaning right.
    w = h * 0.55
    pts = [(0.62, 0.0), (0.18, 0.56), (0.47, 0.56), (0.32, 1.0), (0.84, 0.38), (0.53, 0.38), (0.78, 0.0)]
    path = ' '.join(f'{cx - w / 2 + x * w:.1f},{cy - h / 2 + y * h:.1f}' for x, y in pts)
    return f'<polygon points="{path}" fill="{BOLT_COLOUR}" opacity="0.9"/>'


# Beta 4.2: the running badges' icons. A finisher's medal ring around the F
# (on the back layer, inside the launcher's mask), and the marathon's 42 in
# place of the F.
RING = {'finisher'}
NUMBER = {'fortyTwo': '42'}


def ring(cx: float, cy: float, r: float, width: float) -> str:
    return f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="none" stroke="url(#g)" stroke-width="{width}"/>'


def number(text: str, fill: str, cx: float, cy: float, size: float) -> str:
    return (f'<text x="{cx}" y="{cy}" text-anchor="middle" dominant-baseline="central" font-family="{kit.FONT}" '
            f'font-size="{size}" font-weight="700" fill="{fill}">{text}</text>')


def background(fill: str, defs: str, glow: bool, name: str = '') -> str:
    """A full square: the adaptive icon's back layer (the launcher masks it)."""
    s = LAYER
    halo = ''
    if glow:
        defs = defs + kit_assets.glow('ig', 0.75, 0.25, 0.9, C['green_deep'], 0.95)
        halo = f'<rect width="{s}" height="{s}" fill="url(#ig)"/>'
    if name in RING:
        # Inside the 66 dp the launcher always shows (radius 0.305 of the side).
        halo += ring(s / 2, s / 2, s * 0.27, s * 0.022)
    if name in BOLT:
        halo += lightning(s * 0.64, s * 0.52, s * 0.5)
    return kit.svg(s, s, f'<rect width="{s}" height="{s}" fill="{fill}"/>{halo}', defs)


def foreground(fill: str, defs: str, name: str = '') -> str:
    """The F on clear, as tool/brand.py's icon_foreground (50 % of the side)."""
    s = LAYER
    m = s * 0.50
    if name in NUMBER:
        return kit.svg(s, s, number(NUMBER[name], fill, s / 2, s / 2, s * 0.40), defs)
    return kit.svg(s, s, kit_assets.mark_centered(fill, s / 2, s / 2 - 50 * m / 100, m), defs)


def preview(bg: str, fill: str, defs: str, glow: bool, name: str = '') -> str:
    """A whole rounded icon, as the picker shows it."""
    size = 1024
    r = size * 0.225
    inset = size * 0.2
    m = size - 2 * inset
    halo = ''
    if glow:
        defs = defs + kit_assets.glow('ig', 0.75, 0.25, 0.9, C['green_deep'], 0.95)
        halo = f'<rect width="{size}" height="{size}" rx="{r}" fill="url(#ig)"/>'
    border = f' stroke="{C["steel"]}" stroke-width="{size * 0.012}"' if glow else ''
    if name in RING:
        halo += ring(size / 2, size / 2, size * 0.42, size * 0.035)
    if name in BOLT:
        halo += lightning(size * 0.66, size * 0.52, size * 0.72)
    mark = (number(NUMBER[name], fill, size / 2, size / 2, size * 0.5) if name in NUMBER
            else kit_assets.mark_centered(fill, size / 2, inset, m))
    body = f'<rect width="{size}" height="{size}" rx="{r}" fill="{bg}"{border}/>{halo}' + mark
    return kit.svg(size, size, body, defs)


ADAPTIVE = """<?xml version="1.0" encoding="utf-8"?>
<!-- Beta 3.2: the {name} app icon (tool/app_icons.py). Same layout as ic_launcher. -->
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
  <background android:drawable="@drawable/ic_launcher_{name}_background"/>
  <foreground>
      <inset
          android:drawable="@drawable/ic_launcher_{name}_foreground"
          android:inset="16%" />
  </foreground>
  <monochrome>
      <inset
          android:drawable="@drawable/ic_launcher_monochrome"
          android:inset="16%" />
  </monochrome>
</adaptive-icon>
"""


def main() -> None:
    nodpi = RES / 'drawable-nodpi'
    anydpi = RES / 'mipmap-anydpi-v26'
    for d in (nodpi, anydpi, PREVIEWS):
        d.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        def render(svg: str, out: Path, px: int) -> None:
            src = Path(tmp) / (out.stem + '.svg')
            src.write_text(svg, encoding='utf-8')
            kit.render_file(src, out, px, px, 1)

        only = set(sys.argv[1:])
        for name, (bg, fill, defs, glow) in ICONS.items():
            if only and name not in only:
                continue
            res = name.lower()
            render(preview(bg, fill, defs, glow, name), PREVIEWS / f'{name}.png', 192)
            if name == 'standard':
                continue
            render(background(bg, defs, glow, name), nodpi / f'ic_launcher_{res}_background.png', LAYER)
            render(foreground(fill, defs, name), nodpi / f'ic_launcher_{res}_foreground.png', LAYER)
            (anydpi / f'ic_launcher_{res}.xml').write_text(ADAPTIVE.format(name=res), encoding='utf-8', newline='\n')
            print(name)
    print('wrote', nodpi, anydpi, PREVIEWS)


if __name__ == '__main__':
    main()
