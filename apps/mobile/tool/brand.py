"""FITOS launcher icon and splash, from the brand kit (ADR-028).

The geometry and colours are the kit's own (brand/build_kit.py), so the
icon on the phone is the kit's app icon. Outputs feed
flutter_launcher_icons and flutter_native_splash (see pubspec.yaml).
Needs Chrome or Edge, like the kit.

    python tool/brand.py
"""
import sys
import tempfile
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / 'brand'))

import build_kit as kit  # noqa: E402
import kit_assets  # noqa: E402

OUT = Path(__file__).resolve().parent.parent / 'assets' / 'brand'


def centred_mark(fill: str, size: int, share: float) -> str:
    """The F centred in a transparent square, its box `share` of the side."""
    m = size * share
    # The visible F spans y 6-94 of its 100-unit box: centre that span.
    return kit.svg(size, size, kit_assets.mark_centered(fill, size / 2, size / 2 - 50 * m / 100, m),
                   kit.defs_gradient('g'))


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    files = {
        # Legacy launcher icon: the kit's bold app icon on carbon.
        'icon.png': (kit_assets.ICONS['app-icon-bold-1-carbon'], 1024),
        # Adaptive foreground: transparent, the F inside the 66% safe zone.
        'icon_foreground.png': (centred_mark('url(#g)', 1024, 0.50), 1024),
        # Themed icons (Android 13+) take only the shape: white on clear.
        'icon_monochrome.png': (centred_mark('#FFFFFF', 1024, 0.50), 1024),
        # Splash mark, centred on carbon by flutter_native_splash.
        'splash.png': (centred_mark('url(#g)', 1152, 0.40), 1152),
        # Android 12+ splash icon: the OS masks a circle, keep the F inside it.
        'splash_android12.png': (centred_mark('url(#g)', 1152, 0.44), 1152),
    }
    with tempfile.TemporaryDirectory() as tmp:
        for name, (content, px) in files.items():
            src = Path(tmp) / name.replace('.png', '.svg')
            src.write_text(content, encoding='utf-8')
            kit.render_file(src, OUT / name, px, px, 1)
            print(name)
    print('wrote', OUT)


if __name__ == '__main__':
    main()
