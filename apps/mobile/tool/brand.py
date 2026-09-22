"""FITOS mark — generated, not drawn by hand, so it can be regenerated.

Paper / ink, athletic editorial (§6). The mark is a geometric F whose
middle bar runs on as a thin rule — the hairline that structures every
FITOS screen. No gradients, no clip art. Outputs feed
flutter_launcher_icons and flutter_native_splash (see pubspec.yaml).

    python tool/brand.py
"""
from pathlib import Path

from PIL import Image, ImageDraw

PAPER = (0xED, 0xEB, 0xE4, 255)
INK = (0x17, 0x17, 0x1A, 255)
PINE = (0x1E, 0x6B, 0x47, 255)
CLEAR = (0, 0, 0, 0)

OUT = Path(__file__).resolve().parent.parent / "assets" / "brand"


def mark(draw: ImageDraw.ImageDraw, size: int, scale: float, ink=INK, rule=INK) -> None:
    """The F at `scale` of the canvas, centred. Proportions in a 100-unit box."""
    u = size * scale / 100
    ox = (size - 100 * u) / 2
    oy = (size - 100 * u) / 2

    def box(x0, y0, x1, y1, fill):
        draw.rectangle([ox + x0 * u, oy + y0 * u, ox + x1 * u, oy + y1 * u], fill=fill)

    stem = 18
    box(14, 8, 14 + stem, 92, ink)          # stem
    box(14, 8, 86, 8 + stem, ink)           # top bar
    box(14, 44, 68, 44 + 14, ink)           # middle bar, shorter
    box(68, 49, 100, 49 + 4, rule)          # …runs on as the rule


def icon(size: int, background, scale: float, out: Path) -> None:
    im = Image.new("RGBA", (size, size), background)
    mark(ImageDraw.Draw(im), size, scale)
    im.save(out)


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    # Legacy square launcher icon: paper background, F filling ~62%.
    icon(1024, PAPER, 0.62, OUT / "icon.png")
    # Adaptive foreground: transparent, F inside the 66% safe zone.
    icon(1024, CLEAR, 0.46, OUT / "icon_foreground.png")
    # Splash mark (shown centred on paper by flutter_native_splash).
    icon(1152, CLEAR, 0.42, OUT / "splash.png")
    # Android 12+ splash icon: the OS masks a circle, keep the F small.
    icon(1152, CLEAR, 0.34, OUT / "splash_android12.png")
    # A monochrome variant for themed icons (Android 13+): ink only.
    icon(1024, CLEAR, 0.46, OUT / "icon_monochrome.png")
    print("wrote", OUT)


if __name__ == "__main__":
    main()
