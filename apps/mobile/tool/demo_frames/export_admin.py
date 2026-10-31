"""Beta 5.2 (owner): the admin panel's Exercise demos page shows each demo as
the app draws it. This turns the frames rendered by demo_frames_test.dart into
animated WebPs and a manifest in apps/admin/public/demos/.

Run from apps/mobile:
    flutter test --update-goldens tool/demo_frames/demo_frames_test.dart
    python tool/demo_frames/export_admin.py

Needs Pillow. The variants come from exercise_demos.dart's demoVariants.
"""
import json
import os
import re
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
MOBILE = os.path.normpath(os.path.join(HERE, '..', '..'))
ROOT = os.path.normpath(os.path.join(MOBILE, '..', '..'))
FRAMES = os.path.join(HERE, 'out')
OUT = os.path.join(ROOT, 'apps', 'admin', 'public', 'demos')
LIBRARY = os.path.join(ROOT, 'database', 'seeds', 'exercises.json')
DEMOS = os.path.join(MOBILE, 'lib', 'features', 'exercise', 'domain', 'demo', 'exercise_demos.dart')
FPS = 20


def variants_by_demo():
    """{demo slug: [(variant slug, note)]} from the Dart source."""
    src = open(DEMOS, encoding='utf-8').read()
    block = src[src.index('const Map<String, (String, String)> demoVariants'):]
    block = block[:block.index('};')]
    out = {}
    for m in re.finditer(r"'([a-z0-9-]+)':\s*\(\s*'([a-z0-9-]+)',\s*'((?:[^'\\]|\\.)*)',?\s*\)", block):
        out.setdefault(m.group(2), []).append((m.group(1), m.group(3).replace("\\'", "'")))
    return out


def main():
    library = {e['slug']: e for e in json.load(open(LIBRARY, encoding='utf-8'))}
    variants = variants_by_demo()
    os.makedirs(OUT, exist_ok=True)
    slugs = sorted(os.listdir(FRAMES))
    entries = []
    for slug in slugs:
        files = sorted(os.listdir(os.path.join(FRAMES, slug)))
        frames = [Image.open(os.path.join(FRAMES, slug, f)).convert('RGB').resize((288, 320), Image.LANCZOS) for f in files]
        frames[0].save(os.path.join(OUT, f'{slug}.webp'), save_all=True, append_images=frames[1:],
                       duration=1000 // FPS, loop=0, quality=72, method=6)
        e = library[slug]
        entries.append({
            'slug': slug,
            'name': e['name'],
            'pattern': e['movementPattern'],
            'equipment': e['equipment'],
            'cues': e['instructions'],
            'seconds': round(len(files) / FPS, 1),
            'variants': [{'slug': v, 'name': library[v]['name'], 'note': n} for v, n in variants.get(slug, [])],
        })
    for stale in os.listdir(OUT):
        if stale.endswith('.webp') and stale[:-5] not in slugs:
            os.remove(os.path.join(OUT, stale))
    json.dump({'demos': entries}, open(os.path.join(OUT, 'manifest.json'), 'w', encoding='utf-8', newline='\n'), indent=1)
    size = sum(os.path.getsize(os.path.join(OUT, f)) for f in os.listdir(OUT))
    print(f'{len(entries)} demos, {size / 1e6:.1f} MB in {OUT}')


if __name__ == '__main__':
    sys.exit(main())
