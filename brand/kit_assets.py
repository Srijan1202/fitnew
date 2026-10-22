"""Every asset of the FITOS brand kit, built from build_kit's geometry."""
from build_kit import (C, FONT, TAGLINE, WORD_W, asset, defs_gradient, mark, svg, tagline, wordmark)

# The F's visible extent inside its 100-unit box (it leans right): used to centre it.
MARK_X0, MARK_X1 = 16, 98


def mark_centered(fill: str, cx: float, y: float, size: float) -> str:
    s = size / 100
    return mark(fill, cx - (MARK_X0 + MARK_X1) / 2 * s, y, size)


def glow(gid: str, cx: float, cy: float, r: float, color: str = C['green_deep'], opacity: float = 0.9) -> str:
    return (f'<radialGradient id="{gid}" cx="{cx}" cy="{cy}" r="{r}">'
            f'<stop offset="0" stop-color="{color}" stop-opacity="{opacity}"/>'
            f'<stop offset="1" stop-color="{color}" stop-opacity="0"/></radialGradient>')


def shard(points: str, gid: str = 'g', opacity: float = 1) -> str:
    return f'<polygon points="{points}" fill="url(#{gid})" opacity="{opacity}"/>'


def text_width(content: str, size: float, bold: bool = False) -> float:
    """Measured with the real Bahnschrift outlines, so spacing matches the render."""
    try:
        from PIL import ImageFont
        f = ImageFont.truetype(r'C:\Windows\Fonts\bahnschrift.ttf', 100)
        if bold:
            f.set_variation_by_name('SemiBold')
        return f.getlength(content) * size / 100
    except Exception:  # no PIL or no font: a fair estimate
        return len(content) * size * 0.53


def word_width(h: float) -> float:
    return WORD_W * h / 40


# ------------------------------------------------------------ primary logos --
def primary(dark: bool) -> str:
    w, h = 1200, 900
    bg = C['carbon'] if dark else C['paper']
    word = C['white'] if dark else C['ink']
    tag = C['mist'] if dark else '#3A3F3B'
    defs = defs_gradient('g') + glow('glow', 0.92, 0.08, 0.85)
    wh = 82
    body = (f'<rect width="{w}" height="{h}" fill="{bg}"/>'
            + (f'<rect width="{w}" height="{h}" fill="url(#glow)"/>'
               + shard(f'0,{h - 210} 0,{h - 150} 170,{h} 260,{h}', 'g', 0.95)
               + shard(f'0,{h - 120} 0,{h - 96} 70,{h} 104,{h}', 'g', 0.55) if dark else '')
            + mark_centered('url(#g)' if dark else C['ink'], w / 2, 90, 420)
            + wordmark(word, (w - word_width(wh)) / 2, 560, wh)
            + tagline(tag, w / 2, 720, 26, 'middle')
            + f'<rect x="{w / 2 - 30}" y="758" width="60" height="5" rx="2" fill="{C["lime"] if dark else C["green"]}"/>')
    return svg(w, h, body, defs)


asset('logo-primary-dark', 1200, 900, primary(True))
asset('logo-secondary-light', 1200, 900, primary(False))

# ----------------------------------------------------------------- the marks --
for name, fill, bgc in [('logomark-bold', 'url(#g)', None), ('logomark-minimal-black', C['ink'], None),
                        ('logomark-minimal-white', C['white'], None)]:
    asset(name, 512, 512, svg(512, 512, mark_centered(fill, 256, 36, 440), defs_gradient('g')))


# ----------------------------------------------------------------- app icons --
def icon(bg: str, fill: str, stroke: str | None = None, glow_on: bool = False, size: int = 1024) -> str:
    r = size * 0.225
    inset = size * 0.2
    m = size - 2 * inset
    defs = defs_gradient('g') + glow('ig', 0.75, 0.25, 0.9, C['green_deep'], 0.95) + (
        '<linearGradient id="limebg" x1="0" y1="0" x2="1" y2="1">'
        f'<stop offset="0" stop-color="{C["lime_hi"]}"/><stop offset="1" stop-color="{C["lime"]}"/></linearGradient>')
    border = f' stroke="{stroke}" stroke-width="{size * 0.012}"' if stroke else ''
    sw = size * 0.012 if stroke else 0
    body = (f'<rect x="{sw / 2}" y="{sw / 2}" width="{size - sw}" height="{size - sw}" rx="{r}" fill="{bg}"{border}/>'
            + (f'<rect width="{size}" height="{size}" rx="{r}" fill="url(#ig)"/>' if glow_on else '')
            + mark_centered(fill, size / 2, inset, m))
    return svg(size, size, body, defs)


ICONS = {
    'app-icon-bold-1-carbon': icon(C['carbon'], 'url(#g)'),
    'app-icon-bold-2-glow': icon(C['graphite'], 'url(#g)', C['steel'], glow_on=True),
    'app-icon-bold-3-lime': icon('url(#limebg)', C['carbon']),
    'app-icon-bold-4-white': icon(C['white'], 'url(#g)'),
    'app-icon-minimal-1-black': icon(C['ink'], C['white']),
    'app-icon-minimal-2-white': icon(C['white'], C['ink']),
    'app-icon-minimal-3-outline': icon(C['ink'], C['white'], '#E9EAE7'),
    'app-icon-minimal-4-paper': icon(C['paper'], C['ink'], '#D6D9D4'),
}
for name, content in ICONS.items():
    asset(name, 1024, 1024, content)


# ------------------------------------------------------------------ favicons --
def favicon(px: int, bold: bool) -> str:
    bg = C['carbon'] if bold else C['white']
    fill = 'url(#g)' if bold else C['ink']
    r = px * 0.18
    inset = px * 0.12
    stroke = '' if bold else f' stroke="#D6D9D4" stroke-width="{px / 32}"'
    body = (f'<rect width="{px}" height="{px}" rx="{r}" fill="{bg}"{stroke}/>'
            + mark_centered(fill, px / 2, inset, px - 2 * inset))
    return svg(px, px, body, defs_gradient('g'))


for px in (16, 32, 48, 180, 512):
    asset(f'favicon-bold-{px}', px, px, favicon(px, True))
    asset(f'favicon-minimal-{px}', px, px, favicon(px, False))


# ---------------------------------------------------------- horizontal logo --
def horizontal(fill_mark: str, fill_word: str, tag_fill: str, bg: str | None) -> str:
    w, h = 1200, 300
    m = 220
    wh = 64
    x_word = 300
    body = ((f'<rect width="{w}" height="{h}" rx="24" fill="{bg}"/>' if bg else '')
            + mark(fill_mark, 40, 40, m)
            + wordmark(fill_word, x_word, 92, wh)
            + tagline(tag_fill, x_word + 4, 210, 22, 'start', 0.5))
    return svg(w, h, body, defs_gradient('g'))


asset('logo-horizontal-bold', 1200, 300, horizontal('url(#g)', C['white'], C['mist'], None))
asset('logo-horizontal-bold-on-dark', 1200, 300, horizontal('url(#g)', C['white'], C['mist'], C['carbon']))
asset('logo-horizontal-bold-on-light', 1200, 300, horizontal('url(#g)', C['ink'], '#4A504B', None))
asset('logo-horizontal-minimal-white', 1200, 300, horizontal(C['white'], C['white'], C['mist'], None))
asset('logo-horizontal-minimal-black', 1200, 300, horizontal(C['ink'], C['ink'], '#4A504B', None))


# -------------------------------------------------------------- stacked logo --
def stacked(fill_mark: str, fill_word: str, tag_fill: str, bg: str | None) -> str:
    w, h = 800, 800
    wh = 70
    body = ((f'<rect width="{w}" height="{h}" rx="32" fill="{bg}"/>' if bg else '')
            + mark_centered(fill_mark, w / 2, 90, 380)
            + wordmark(fill_word, (w - word_width(wh)) / 2, 520, wh)
            + tagline(tag_fill, w / 2, 660, 17, 'middle', 0.42))
    return svg(w, h, body, defs_gradient('g'))


asset('logo-stacked-bold', 800, 800, stacked('url(#g)', C['white'], C['mist'], None))
asset('logo-stacked-bold-on-dark', 800, 800, stacked('url(#g)', C['white'], C['mist'], C['carbon']))
asset('logo-stacked-bold-on-light', 800, 800, stacked('url(#g)', C['ink'], '#4A504B', None))
asset('logo-stacked-minimal-white', 800, 800, stacked(C['white'], C['white'], C['mist'], None))
asset('logo-stacked-minimal-black', 800, 800, stacked(C['ink'], C['ink'], '#4A504B', None))


# ------------------------------------------------------------ website header --
def header(dark: bool) -> str:
    w, h = 1440, 96
    bg = C['graphite'] if dark else C['white']
    border = C['steel'] if dark else '#E2E5E0'
    text = '#D9DDD8' if dark else '#2B302C'
    active = C['lime'] if dark else C['green']
    btn_bg = C['lime'] if dark else C['ink']
    btn_fg = C['carbon'] if dark else C['white']
    nav = ['Home', 'Features', 'Progress', 'Pricing', 'Blog']
    widths = [text_width(label, 17, bold=(i == 0)) for i, label in enumerate(nav)]
    x = 560
    links = ''
    for i, label in enumerate(nav):
        col = active if i == 0 else text
        links += (f'<text x="{x:.1f}" y="54" font-family="{FONT}" font-size="17" fill="{col}" '
                  f'font-weight="{600 if i == 0 else 400}">{label}</text>')
        if i == 0:
            links += f'<rect x="{x:.1f}" y="68" width="{widths[0] + 6:.1f}" height="3" rx="1.5" fill="{active}"/>'
        x += widths[i] + 48
    body = (f'<rect x="1" y="1" width="{w - 2}" height="{h - 2}" rx="18" fill="{bg}" stroke="{border}" stroke-width="2"/>'
            + mark('url(#g)' if dark else C['ink'], 40, 24, 48)
            + wordmark(C['white'] if dark else C['ink'], 100, 34, 28)
            + links
            + f'<rect x="{w - 210}" y="24" width="170" height="48" rx="12" fill="{btn_bg}"/>'
            + f'<text x="{w - 125}" y="54" font-family="{FONT}" font-size="17" font-weight="600" fill="{btn_fg}" text-anchor="middle">Get Started</text>')
    return svg(w, h, body, defs_gradient('g'))


asset('website-header-dark', 1440, 96, header(True))
asset('website-header-light', 1440, 96, header(False))


# -------------------------------------------------------------------- banners --
def banner(dark: bool) -> str:
    w, h = 1500, 500
    bg = C['carbon'] if dark else C['white']
    word = C['white'] if dark else C['ink']
    tag = C['mist'] if dark else '#4A504B'
    defs = (defs_gradient('g') + glow('bglow', 0.62, 0.3, 0.55, C['green_deep'], 0.85 if dark else 0.0)
            + '<linearGradient id="fade" x1="0" y1="0" x2="1" y2="0">'
            f'<stop offset="0" stop-color="{bg}" stop-opacity="0"/><stop offset="1" stop-color="{bg}" stop-opacity="1"/>'
            '</linearGradient>')
    body = (f'<rect width="{w}" height="{h}" rx="24" fill="{bg}"/>'
            + f'<rect width="{w}" height="{h}" rx="24" fill="url(#bglow)"/>'
            + shard(f'{w * 0.55},{h} {w * 0.74},0 {w * 0.79},0 {w * 0.62},{h}', 'g', 0.95)
            + shard(f'{w * 0.72},{h * 0.55} {w * 0.86},{h * 0.08} {w * 0.88},{h * 0.08} {w * 0.75},{h * 0.55}', 'g', 0.55)
            + mark_centered(C['lime'] if dark else C['ink'], w * 0.66, -40, 600).replace('<g ', f'<g opacity="{0.06 if dark else 0.035}" ', 1)
            # Photo slot: put banner-photo.png (an athlete, transparent or dark
            # background) beside this SVG and it shows here, as in the reference.
            + f'<image href="banner-photo.png" x="{w * 0.5:.0f}" y="0" width="{w * 0.32:.0f}" height="{h}" preserveAspectRatio="xMidYMax meet"/>'
            + f'<rect x="{w * 0.76}" y="0" width="{w * 0.24}" height="{h}" fill="url(#fade)"/>'
            + mark('url(#g)' if dark else C['ink'], 70, 120, 200)
            + wordmark(word, 300, 205, 52)
            + tagline(tag, 304, 300, 18, 'start', 0.5)
            + ''.join(
                f'<text x="{w - 260}" y="{170 + i * 50}" font-family="{FONT}" font-size="34" font-weight="400" '
                f'letter-spacing="7" fill="{(C["lime"] if dark else C["green"]) if t == "YOU" else word}">{t}</text>'
                for i, t in enumerate(['DISCIPLINE', 'BUILDS', 'A BETTER', 'YOU']))
            + f'<rect x="{w - 260}" y="{390}" width="44" height="4" rx="2" fill="{C["lime"] if dark else C["green"]}"/>')
    return svg(w, h, body, defs)


asset('banner-dark', 1500, 500, banner(True))
asset('banner-light', 1500, 500, banner(False))


# -------------------------------------------------------------- colour palette --
PALETTE = [
    ('Volt Lime', 'lime', 'Primary. The mark, actions, highlights'),
    ('Electric Lime', 'lime_hi', 'Gradient top, glows'),
    ('FITOS Green', 'green', 'Gradient bottom, success, accents on light'),
    ('Deep Green', 'green_deep', 'Background glow, shadows'),
    ('Carbon', 'carbon', 'Dark background'),
    ('Graphite', 'graphite', 'Dark surfaces, cards'),
    ('Steel', 'steel', 'Lines and borders on dark'),
    ('Mist', 'mist', 'Secondary text, taglines'),
    ('Paper', 'paper', 'Light background'),
    ('Ink', 'ink', 'Minimal logo, text on light'),
]


def hex_to_rgb(h: str) -> str:
    h = h.lstrip('#')
    return ', '.join(str(int(h[i:i + 2], 16)) for i in (0, 2, 4))


def palette() -> str:
    w, h = 1600, 1000
    body = (f'<rect width="{w}" height="{h}" fill="{C["carbon"]}"/>'
            + f'<text x="80" y="110" font-family="{FONT}" font-size="22" letter-spacing="8" fill="{C["mist"]}">FITOS · COLOUR PALETTE</text>'
            + '<rect x="80" y="150" width="1440" height="120" rx="20" fill="url(#g)"/>'
            + f'<text x="110" y="222" font-family="{FONT}" font-size="22" letter-spacing="3" fill="{C["carbon"]}">BRAND GRADIENT  ·  {C["lime_hi"]} → {C["lime"]} → {C["green"]}</text>')
    for i, (label, key, use) in enumerate(PALETTE):
        col, row = i % 5, i // 5
        x, y = 80 + col * 292, 320 + row * 330
        hexv = C[key]
        light = key in ('lime', 'lime_hi', 'paper', 'mist', 'green')
        border = f' stroke="{C["steel"]}" stroke-width="2"' if key in ('carbon', 'graphite', 'ink') else ''
        body += (f'<rect x="{x}" y="{y}" width="272" height="180" rx="16" fill="{hexv}"{border}/>'
                 + f'<text x="{x + 20}" y="{y + 160}" font-family="{FONT}" font-size="18" fill="{C["carbon"] if light else C["white"]}">{hexv.upper()}</text>'
                 + f'<text x="{x}" y="{y + 220}" font-family="{FONT}" font-size="24" font-weight="600" fill="{C["white"]}">{label}</text>'
                 + f'<text x="{x}" y="{y + 250}" font-family="{FONT}" font-size="16" fill="{C["mist"]}">RGB {hex_to_rgb(hexv)}</text>'
                 + f'<text x="{x}" y="{y + 278}" font-family="{FONT}" font-size="15" fill="{C["mist"]}">{use}</text>')
    return svg(w, h, body, defs_gradient('g'))


asset('color-palette', 1600, 1000, palette())


# ----------------------------------------------------------------- typography --
BODY_FONT = "'Segoe UI', Barlow, Arial, sans-serif"


def text(x, y, size, content, fill=C['white'], weight=400, spacing=0, font=FONT, anchor='start'):
    return (f'<text x="{x}" y="{y}" font-family="{font}" font-size="{size}" font-weight="{weight}" '
            f'letter-spacing="{spacing}" fill="{fill}" text-anchor="{anchor}">{content}</text>')


def typography() -> str:
    w, h = 1600, 1100
    rule = lambda y: f'<line x1="80" y1="{y}" x2="1520" y2="{y}" stroke="{C["steel"]}" stroke-width="2"/>'  # noqa: E731
    body = (f'<rect width="{w}" height="{h}" fill="{C["carbon"]}"/>'
            + text(80, 110, 22, 'FITOS · TYPOGRAPHY', C['mist'], 400, 8)
            + text(80, 190, 18, 'WORDMARK · CUSTOM GEOMETRIC CAPITALS (vector, no font needed)', C['lime'], 400, 3)
            + wordmark(C['white'], 80, 220, 70)
            + rule(350)
            + text(80, 400, 18, 'DISPLAY &amp; HEADINGS · BAHNSCHRIFT SEMIBOLD (web: Barlow SemiBold)', C['lime'], 400, 3)
            + text(80, 480, 64, 'Discipline builds a better you', C['white'], 600)
            + text(80, 540, 40, 'H2 · Track every set, every meal', C['white'], 600)
            + text(80, 590, 28, 'H3 · Weekly volume per muscle', C['white'], 600)
            + rule(640)
            + text(80, 690, 18, 'TAGLINE · BAHNSCHRIFT REGULAR, UPPERCASE, WIDE TRACKING', C['lime'], 400, 3)
            + tagline(C['mist'], 80, 750, 30, 'start', 0.45)
            + rule(800)
            + text(80, 850, 18, 'BODY · SEGOE UI (web: Inter or Barlow)', C['lime'], 400, 3)
            + text(80, 910, 26, 'FITOS turns what you log into what to do next: the next set, the next meal, the next week.', '#D9DDD8', 400, 0, BODY_FONT)
            + text(80, 960, 20, 'Body 20/30 · captions 14 · numbers tabular. Line height 1.5. Never below 14 px on screen.', C['mist'], 400, 0, BODY_FONT)
            + text(80, 1040, 18, 'Scale 64 / 40 / 28 / 20 / 16 / 14   ·   Weights 300 / 400 / 600 / 700', C['mist'], 400, 2))
    return svg(w, h, body)


asset('typography', 1600, 1100, typography())


# ----------------------------------------------------------- design templates --
def social_post() -> str:
    w = h = 1080
    defs = defs_gradient('g') + glow('pg', 0.85, 0.15, 0.8)
    body = (f'<rect width="{w}" height="{h}" fill="{C["carbon"]}"/><rect width="{w}" height="{h}" fill="url(#pg)"/>'
            + shard(f'{w},{h - 360} {w},{h - 250} {w - 300},{h} {w - 440},{h}', 'g', 0.9)
            + mark('url(#g)', 70, 70, 110)
            + wordmark(C['white'], 200, 105, 34)
            + f'<text x="80" y="470" font-family="{FONT}" font-size="30" letter-spacing="10" fill="{C["lime"]}">HEADLINE EYEBROW</text>'
            + f'<text x="80" y="560" font-family="{FONT}" font-size="78" font-weight="600" fill="{C["white"]}">Your headline</text>'
            + f'<text x="80" y="650" font-family="{FONT}" font-size="78" font-weight="600" fill="{C["white"]}">goes here.</text>'
            + f'<text x="80" y="730" font-family="{FONT}" font-size="30" fill="{C["mist"]}">One supporting line, short and plain.</text>'
            + f'<rect x="80" y="800" width="300" height="76" rx="16" fill="{C["lime"]}"/>'
            + f'<text x="230" y="848" font-family="{FONT}" font-size="26" font-weight="600" fill="{C["carbon"]}" text-anchor="middle">Call to action</text>'
            + tagline(C['mist'], 80, h - 60, 18, 'start', 0.45))
    return svg(w, h, body, defs)


def story() -> str:
    w, h = 1080, 1920
    defs = defs_gradient('g') + glow('sg', 0.8, 0.12, 0.7)
    body = (f'<rect width="{w}" height="{h}" fill="{C["carbon"]}"/><rect width="{w}" height="{h}" fill="url(#sg)"/>'
            + shard(f'{w},{h * 0.42} {w},{h * 0.52} {w * 0.45},{h} {w * 0.33},{h}', 'g', 0.9)
            + mark_centered('url(#g)', w / 2, 220, 260)
            + wordmark(C['white'], (w - word_width(54)) / 2, 560, 54)
            + tagline(C['mist'], w / 2, 690, 22, 'middle', 0.45)
            + f'<text x="{w / 2}" y="980" font-family="{FONT}" font-size="84" font-weight="600" fill="{C["white"]}" text-anchor="middle">Week 1 done.</text>'
            + f'<text x="{w / 2}" y="1060" font-family="{FONT}" font-size="34" fill="{C["mist"]}" text-anchor="middle">Replace with your story text</text>'
            + f'<rect x="{w / 2 - 190}" y="1600" width="380" height="90" rx="20" fill="{C["lime"]}"/>'
            + f'<text x="{w / 2}" y="1658" font-family="{FONT}" font-size="30" font-weight="600" fill="{C["carbon"]}" text-anchor="middle">Download FITOS</text>')
    return svg(w, h, body, defs)


def slide() -> str:
    w, h = 1920, 1080
    defs = defs_gradient('g') + glow('lg', 0.9, 0.1, 0.7)
    body = (f'<rect width="{w}" height="{h}" fill="{C["carbon"]}"/><rect width="{w}" height="{h}" fill="url(#lg)"/>'
            + mark('url(#g)', 100, 90, 90)
            + wordmark(C['white'], 210, 120, 30)
            + f'<text x="{w - 100}" y="150" font-family="{FONT}" font-size="20" letter-spacing="6" fill="{C["mist"]}" text-anchor="end">SECTION · 01</text>'
            + f'<text x="100" y="470" font-family="{FONT}" font-size="30" letter-spacing="10" fill="{C["lime"]}">EYEBROW</text>'
            + f'<text x="100" y="580" font-family="{FONT}" font-size="96" font-weight="600" fill="{C["white"]}">Slide title in two words</text>'
            + f'<text x="100" y="660" font-family="{FONT}" font-size="34" fill="{C["mist"]}">A single sentence that says what this slide shows.</text>'
            + f'<rect x="100" y="720" width="80" height="6" rx="3" fill="{C["lime"]}"/>'
            + shard(f'{w},{h * 0.55} {w},{h * 0.7} {w * 0.8},{h} {w * 0.7},{h}', 'g', 0.9)
            + tagline(C['mist'], 100, h - 70, 18, 'start', 0.45))
    return svg(w, h, body, defs)


asset('template-social-post', 1080, 1080, social_post())
asset('template-story', 1080, 1920, story())
asset('template-slide', 1920, 1080, slide())


# ------------------------------------------------------------------ overview --
import re as _re  # noqa: E402

import build_kit as _kit  # noqa: E402


def place(name: str, x: float, y: float, w: float, h: float, view: str = '') -> str:
    """An asset nested in the overview, its ids made unique so gradients never clash."""
    aw, ah, content = _kit.ASSETS[name]
    inner = content[content.index('>') + 1: content.rindex('</svg>')]
    pre = name.replace('-', '_') + '_'
    inner = _re.sub(r'id="([^"]+)"', lambda m: f'id="{pre}{m.group(1)}"', inner)
    inner = _re.sub(r'url\(#([^)]+)\)', lambda m: f'url(#{pre}{m.group(1)})', inner)
    return (f'<svg x="{x:.1f}" y="{y:.1f}" width="{w:.1f}" height="{h:.1f}" '
            f'viewBox="{view or f'0 0 {aw} {ah}'}" preserveAspectRatio="xMidYMid meet">{inner}</svg>')


def label(x, y, t, fill=C['white'], size=13):
    return (f'<text x="{x}" y="{y}" font-family="{FONT}" font-size="{size}" letter-spacing="2.5" '
            f'fill="{fill}">{t}</text>')


def overview() -> str:
    """One sheet with every part of the kit, laid out like the reference board.

    Drawn on a 1280-wide grid and scaled 2x (k)."""
    k = 2
    W, H = 1280 * k, 1080 * k
    rule = lambda x1, y1, x2, y2: (f'<line x1="{x1 * k}" y1="{y1 * k}" x2="{x2 * k}" y2="{y2 * k}" '  # noqa: E731
                                   f'stroke="{C["steel"]}" stroke-width="2"/>')
    put = lambda n, x, y, w, h, view='': place(n, x * k, y * k, w * k, h * k, view)  # noqa: E731
    lab = lambda x, y, t, fill=C['white'], size=10: label(x * k, y * k, t, fill, size * k)  # noqa: E731
    b = f'<rect width="{W}" height="{H}" fill="{C["carbon"]}"/>'
    # row 1 (0-384): primary and secondary logos, cropped to the mark and tagline
    b += put('logo-primary-dark', 0, 0, 640, 384, '0 54 1200 720')
    b += put('logo-secondary-light', 640, 0, 640, 384, '0 54 1200 720')
    b += lab(26, 26, 'PRIMARY LOGO', C['white'], 11) + lab(26, 42, 'BOLD &amp; ATHLETIC', C['mist'], 9)
    b += lab(666, 26, 'SECONDARY LOGO', C['ink'], 11) + lab(666, 42, 'MINIMAL &amp; PREMIUM', '#4A504B', 9)
    # row 2 (384-544): app icons and favicons
    y = 384
    b += rule(0, y, 1280, y) + rule(480, y, 480, y + 160) + rule(980, y, 980, y + 160)
    b += lab(26, y + 24, 'APP ICONS (BOLD)')
    for i, n in enumerate(['app-icon-bold-1-carbon', 'app-icon-bold-2-glow', 'app-icon-bold-3-lime', 'app-icon-bold-4-white']):
        b += put(n, 30 + i * 110, y + 42, 92, 92)
    b += lab(506, y + 24, 'APP ICONS (MINIMAL)')
    for i, n in enumerate(['app-icon-minimal-1-black', 'app-icon-minimal-2-white', 'app-icon-minimal-3-outline', 'app-icon-minimal-4-paper']):
        b += put(n, 510 + i * 116, y + 42, 92, 92)
    b += lab(1004, y + 24, 'FAVICON / SMALL SIZES')
    for x, n, sz, cap in ((1010, 'favicon-bold-512', 48, '32×32'), (1084, 'favicon-minimal-512', 40, '16×16'),
                          (1150, 'favicon-bold-512', 32, ''), (1200, 'favicon-minimal-512', 32, 'ICO / SVG')):
        b += put(n, x, y + 88 - sz / 2, sz, sz)
        if cap:
            b += lab(x - (24 if cap == 'ICO / SVG' else -4), y + 140, cap, C['mist'], 8)
    # row 3 (544-640): website headers
    y = 544
    b += rule(0, y, 1280, y)
    b += lab(22, y + 24, 'WEBSITE HEADER (DARK)') + lab(658, y + 24, 'WEBSITE HEADER (LIGHT)')
    b += put('website-header-dark', 22, y + 38, 600, 40) + put('website-header-light', 658, y + 38, 600, 40)
    # row 4 (640-880): banners
    y = 640
    b += rule(0, y, 1280, y)
    b += lab(22, y + 24, 'BANNER (DARK)') + lab(658, y + 24, 'BANNER (LIGHT)')
    b += put('banner-dark', 22, y + 38, 600, 200) + put('banner-light', 658, y + 38, 600, 200)
    # row 5 (880-1080): lockups and marks
    y = 880
    b += rule(0, y, 1280, y)
    for x in (300, 600, 800, 1000):
        b += rule(x, y, x, 1080)
    b += lab(22, y + 24, 'HORIZONTAL LOGO (BOLD)') + put('logo-horizontal-bold', 10, y + 64, 280, 70)
    b += lab(322, y + 24, 'HORIZONTAL LOGO (MINIMAL)') + put('logo-horizontal-minimal-white', 310, y + 64, 280, 70)
    b += lab(616, y + 24, 'STACKED LOGO (BOLD)') + put('logo-stacked-bold', 630, y + 40, 140, 140)
    b += lab(816, y + 24, 'STACKED LOGO (MINIMAL)') + put('logo-stacked-minimal-white', 830, y + 40, 140, 140)
    b += lab(1022, y + 24, 'LOGO MARK ONLY')
    b += put('logomark-bold', 1030, y + 52, 90, 90) + lab(1044, y + 168, 'BOLD MARK', C['mist'], 8)
    b += put('logomark-minimal-white', 1150, y + 52, 90, 90) + lab(1156, y + 168, 'MINIMAL MARK', C['mist'], 8)
    return svg(W, H, b)


asset('brand-kit-overview', 2560, 2160, overview())
