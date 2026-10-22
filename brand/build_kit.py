"""FITOS brand kit generator.

Every asset is written as SVG from the shared geometry below (the F mark,
the FITOS wordmark, the palette), then rendered to PNG by headless Chrome
from that same SVG — so the two formats can never drift apart.

    python brand/build_kit.py            # SVG + PNG into brand/fitos-kit/
    python brand/build_kit.py --svg-only

The mark and the wordmark are drawn as paths: no font is needed to display
them. Supporting text uses Bahnschrift (Windows) with Barlow as the free web
equivalent (see the typography sheet).
"""
from __future__ import annotations

import os
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent
OUT = ROOT / 'fitos-kit'
SVG = OUT / 'svg'
PNG = OUT / 'png'

# ------------------------------------------------------------------ palette --
C = {
    'lime': '#C6F432',        # Volt Lime: the brand colour
    'lime_hi': '#E4FF52',     # Electric Lime: the top of the gradient
    'green': '#5BC62A',       # FITOS Green: the bottom of the gradient
    'green_deep': '#1E5A1A',  # Deep Green: glows and shadows
    'carbon': '#0A0D0B',      # Carbon: dark background
    'graphite': '#131814',    # Graphite: dark surfaces
    'steel': '#262D27',       # Steel: lines on dark
    'mist': '#8E978F',        # Mist: secondary text
    'paper': '#F5F6F3',       # Paper: light background
    'white': '#FFFFFF',
    'ink': '#0B0B0C',         # Ink: the minimal logo, text on light
}

FONT = "Bahnschrift, 'Barlow', 'Segoe UI', Arial, sans-serif"
TAGLINE = 'TRACK   TRAIN   FUEL   IMPROVE'


def defs_gradient(gid: str) -> str:
    """The lime gradient of the bold mark (light top-right, green bottom-left)."""
    return (
        f'<linearGradient id="{gid}" x1="0.85" y1="0.05" x2="0.15" y2="0.95">'
        f'<stop offset="0" stop-color="{C["lime_hi"]}"/>'
        f'<stop offset="0.45" stop-color="{C["lime"]}"/>'
        f'<stop offset="1" stop-color="{C["green"]}"/>'
        '</linearGradient>'
    )


# ------------------------------------------------------------------ the mark --
# The F as two italic blades in a 100 x 100 box: the upper blade (top arm and
# the upper stem) and the lower blade (middle arm and the stem's point).
MARK_PATHS = [
    # upper blade
    'M 34 6 L 98 6 C 95 13 90 19 82 22 L 47 22 C 41 22 37 26 34 31 L 24 52 '
    'C 21 44 22 34 26 24 Z',
    # lower blade
    'M 44 36 L 80 36 C 77 43 72 48 65 50 L 50 50 C 44 50 40 54 37 59 L 20 94 '
    'C 16 84 17 72 22 62 L 33 42 C 36 38 40 36 44 36 Z',
]


def mark(fill: str, x: float = 0, y: float = 0, size: float = 100) -> str:
    s = size / 100
    paths = ''.join(f'<path d="{d}"/>' for d in MARK_PATHS)
    return f'<g transform="translate({x:.2f} {y:.2f}) scale({s:.4f})" fill="{fill}">{paths}</g>'


# --------------------------------------------------------------- wordmark --
# FITOS: wide geometric capitals drawn as filled shapes on a 40-unit cap
# height, stroke 8.5, letter gap 13.
CAP = 40
ST = 8.5
GAP = 13


def _rect(x, y, w, h):
    return f'M {x:.2f} {y:.2f} h {w:.2f} v {h:.2f} h {-w:.2f} Z '


def letter_F(x):
    w = 50
    d = _rect(x, 0, ST, CAP) + _rect(x, 0, w, ST) + _rect(x, CAP / 2 - ST / 2 + 1, w * 0.78, ST)
    return d, w


def letter_I(x):
    return _rect(x, 0, ST, CAP), ST


def letter_T(x):
    w = 54
    return _rect(x, 0, w, ST) + _rect(x + w / 2 - ST / 2, 0, ST, CAP), w


def letter_O(x):
    w, h, r = 62, CAP, 13
    # outer rounded rectangle, inner cut-out (evenodd)
    def rr(x0, y0, ww, hh, rr_):
        return (f'M {x0 + rr_:.2f} {y0:.2f} H {x0 + ww - rr_:.2f} '
                f'A {rr_} {rr_} 0 0 1 {x0 + ww:.2f} {y0 + rr_:.2f} V {y0 + hh - rr_:.2f} '
                f'A {rr_} {rr_} 0 0 1 {x0 + ww - rr_:.2f} {y0 + hh:.2f} H {x0 + rr_:.2f} '
                f'A {rr_} {rr_} 0 0 1 {x0:.2f} {y0 + hh - rr_:.2f} V {y0 + rr_:.2f} '
                f'A {rr_} {rr_} 0 0 1 {x0 + rr_:.2f} {y0:.2f} Z ')
    return rr(x, 0, w, h, r) + rr(x + ST, ST, w - 2 * ST, h - 2 * ST, max(r - ST, 2)), w


def letter_S(x):
    w = 56
    r = (CAP / 2 + ST / 2) / 2  # radius of the two bowls' outer corners
    m = CAP / 2  # centre line
    o = ST / 2
    # The S as a stroked centreline, turned into a filled outline by stroke.
    d = (f'M {x + w:.2f} {o:.2f} H {x + r:.2f} '
         f'A {r - o:.2f} {r - o:.2f} 0 0 0 {x + r:.2f} {m:.2f} '
         f'H {x + w - r:.2f} '
         f'A {r - o:.2f} {r - o:.2f} 0 0 1 {x + w - r:.2f} {CAP - o:.2f} '
         f'H {x:.2f}')
    return d, w


def wordmark(fill: str, x: float = 0, y: float = 0, height: float = 40) -> str:
    s = height / CAP
    cx = 0.0
    solid, ring, strokes = [], [], []
    for fn in (letter_F, letter_I, letter_T, letter_O, letter_S):
        d, w = fn(cx)
        (strokes if fn is letter_S else ring if fn is letter_O else solid).append(d)
        cx += w + GAP
    # Overlapping bars fill as one (nonzero); only the O cuts its counter (evenodd).
    body = (f'<path d="{"".join(solid)}"/>'
            f'<path fill-rule="evenodd" d="{ring[0]}"/>'
            f'<path d="{strokes[0]}" fill="none" stroke="{fill}" stroke-width="{ST}"/>')
    return f'<g transform="translate({x:.2f} {y:.2f}) scale({s:.4f})" fill="{fill}">{body}</g>'


WORD_W = 50 + 8.5 + 54 + 62 + 56 + 4 * GAP  # width at cap height 40


def tagline(fill: str, x: float, y: float, size: float, anchor: str = 'start', spacing: float = 0.42) -> str:
    return (f'<text x="{x:.2f}" y="{y:.2f}" font-family="{FONT}" font-size="{size:.2f}" '
            f'font-weight="400" letter-spacing="{size * spacing:.2f}" fill="{fill}" '
            f'text-anchor="{anchor}" xml:space="preserve">{TAGLINE}</text>')


def svg(w: int, h: int, body: str, defs: str = '') -> str:
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">'
            f'<defs>{defs}</defs>{body}</svg>\n')


# ------------------------------------------------------------------ render --
def chrome() -> str:
    for p in (r'C:\Program Files\Google\Chrome\Application\chrome.exe',
              r'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe'):
        if os.path.exists(p):
            return p
    found = shutil.which('chrome') or shutil.which('google-chrome') or shutil.which('msedge')
    if not found:
        raise SystemExit('No Chrome or Edge found to render PNGs (use --svg-only).')
    return found


def render(name: str, w: int, h: int, scale: int = 2) -> None:
    """The SVG at `scale`x into png/<name>.png, transparent where the SVG is."""
    src = (SVG / f'{name}.svg').resolve()
    html = SVG.parent / f'.render-{name}.html'
    html.write_text(
        '<!doctype html><html><head><style>html,body{margin:0;padding:0;background:transparent}'
        f'img{{display:block;width:{w}px;height:{h}px}}</style></head>'
        f'<body><img src="{src.as_uri()}"></body></html>', encoding='utf-8')
    out = (PNG / f'{name}.png').resolve()
    subprocess.run([chrome(), '--headless=new', '--disable-gpu', '--hide-scrollbars',
                    f'--force-device-scale-factor={scale}', f'--window-size={w},{h}',
                    '--default-background-color=00000000', f'--screenshot={out}', html.resolve().as_uri()],
                   check=True, capture_output=True)
    html.unlink()


ASSETS: dict[str, tuple[int, int, str]] = {}


def asset(name: str, w: int, h: int, content: str) -> None:
    ASSETS[name] = (w, h, content)


if __name__ == '__main__':
    import build_kit as kit  # the importable module: the one kit_assets registers into
    import kit_assets  # noqa: F401  (registers every asset)
    SVG.mkdir(parents=True, exist_ok=True)
    PNG.mkdir(parents=True, exist_ok=True)
    only = [a for a in sys.argv[1:] if not a.startswith('--')]
    for name, (w, h, content) in kit.ASSETS.items():
        if only and name not in only:
            continue
        (SVG / f'{name}.svg').write_text(content, encoding='utf-8')
        if '--svg-only' not in sys.argv:
            # Favicons are drawn for their exact pixel size and the overview is already 2x; everything else renders at 2x.
            render(name, w, h, 1 if name.startswith('favicon-') or name == 'brand-kit-overview' else 2)
        print(name)
    if '--svg-only' not in sys.argv and not only:
        from PIL import Image
        for kind in ('bold', 'minimal'):
            imgs = [Image.open(PNG / f'favicon-{kind}-{px}.png') for px in (16, 32, 48)]
            imgs[2].save(OUT / 'png' / f'favicon-{kind}.ico', sizes=[(16, 16), (32, 32), (48, 48)], append_images=imgs[:2])
        print('favicon-bold.ico, favicon-minimal.ico')
