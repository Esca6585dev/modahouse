#!/usr/bin/env python3
"""Generates the ModaHouse launcher icon PNGs from the brand mark.

The mark (brand/logo-mark.svg, viewBox 0 0 100 100) is a white circle with a
dark #262B2F ring, a dark "d" (round bowl + stem) and a red #D7263D roof:

    ring:  circle cx=50 cy=50 r=48, stroke 4
    bowl:  circle cx=44 cy=62 r=15, stroke 7
    stem:  M59 77 V33, stroke 7
    roof:  M47 25 L59 14 L71 25, stroke 6.5 (red)

No third-party packages: every stroke is rendered as a signed distance field
with 1px anti-aliasing and composited, then written with a zlib PNG writer.

    python3 tool/make_icon.py            # writes assets/icon/*.png
    python3 tool/make_icon.py --mipmaps  # also writes android/app/src/main/res/mipmap-*/ic_launcher.png
    python3 tool/make_icon.py --web      # also writes web/favicon.png and web/icons/*.png

Normally `dart run flutter_launcher_icons` turns assets/icon/*.png into the
Android mipmaps; --mipmaps is a fallback that needs no Dart tooling.
"""
import math
import os
import struct
import sys
import zlib

INK = (0x26, 0x2B, 0x2F)
BRAND = (0xD7, 0x26, 0x3D)
WHITE = (255, 255, 255)
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# The "d" with its roof, in SVG units: (kind, color, params, stroke width).
GLYPH = [
    ('ring', INK, (44, 62, 15), 7.0),
    ('line', INK, [(59, 77), (59, 33)], 7.0),
    ('line', BRAND, [(47, 25), (59, 14), (71, 25)], 6.5),
]
# Visual center of the glyph (so it can be centered without the outer ring).
GLYPH_CENTER = (50, 47.5)
OUTER_RING = ('ring', INK, (50, 50, 48), 4.0)


def seg_dist(px, py, ax, ay, bx, by):
    dx, dy = bx - ax, by - ay
    l2 = dx * dx + dy * dy
    t = 0.0 if l2 == 0 else max(0.0, min(1.0, ((px - ax) * dx + (py - ay) * dy) / l2))
    return math.hypot(px - (ax + t * dx), py - (ay + t * dy))


def shape_coverage(shape, px, py):
    kind, _, params, half = shape
    if kind == 'ring':
        cx, cy, r = params
        d = abs(math.hypot(px - cx, py - cy) - r)
    else:
        d = min(seg_dist(px, py, *a, *b) for a, b in zip(params, params[1:]))
    return max(0.0, min(1.0, half - d + 0.5))


def transform(shapes, unit, ox, oy):
    out = []
    for kind, color, params, width in shapes:
        if kind == 'ring':
            cx, cy, r = params
            p = (ox + cx * unit, oy + cy * unit, r * unit)
        else:
            p = [(ox + x * unit, oy + y * unit) for x, y in params]
        out.append((kind, color, p, width * unit / 2))
    return out


def render(size, background, scale=1.0, ring=True):
    """background: 'circle' (white disc), 'square' (full-bleed white) or None.

    scale: size of the glyph relative to the SVG (1.0 = as in logo-mark.svg).
    ring:  draw the dark outer ring (only with the circle background).
    """
    unit = size / 100.0 * scale
    # Center the glyph's visual center on the canvas.
    gx, gy = GLYPH_CENTER
    ox = size / 2 - gx * unit
    oy = size / 2 - gy * unit
    if background == 'circle' and scale == 1.0:
        ox = oy = 0.0  # exactly the SVG layout
    shapes = transform(GLYPH, unit, ox, oy)
    if background == 'circle' and ring:
        shapes = transform([OUTER_RING], size / 100.0, 0, 0) + shapes
    c = size / 2
    r = size / 2
    pixels = bytearray()
    for y in range(size):
        pixels.append(0)  # PNG filter: none
        py = y + 0.5
        for x in range(size):
            px = x + 0.5
            if background == 'circle':
                a = max(0.0, min(1.0, r - math.hypot(px - c, py - c) + 0.5))
            elif background == 'square':
                a = 1.0
            else:
                a = 0.0
            rgb = [float(v) for v in WHITE]
            for shape in shapes:
                cov = shape_coverage(shape, px, py)
                if cov <= 0:
                    continue
                if background == 'circle':
                    cov = min(cov, a)
                color = shape[1]
                # "over" compositing with premultiplied math
                na = cov + a * (1 - cov)
                if na > 0:
                    rgb = [(color[i] * cov + rgb[i] * a * (1 - cov)) / na for i in range(3)]
                a = na
            if a <= 0:
                pixels += b'\x00\x00\x00\x00'
                continue
            pixels += bytes(round(v) for v in rgb) + bytes([round(a * 255)])
    return png(size, size, bytes(pixels))


def png(w, h, raw):
    def chunk(tag, data):
        return struct.pack('>I', len(data)) + tag + data + struct.pack('>I', zlib.crc32(tag + data) & 0xFFFFFFFF)

    return (b'\x89PNG\r\n\x1a\n'
            + chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 6, 0, 0, 0))
            + chunk(b'IDAT', zlib.compress(raw, 9))
            + chunk(b'IEND', b''))


def write(path, data):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, 'wb') as f:
        f.write(data)
    print('wrote', os.path.relpath(path, ROOT))


def main():
    icon_dir = os.path.join(ROOT, 'assets', 'icon')
    # Legacy icon: the full mark (white disc, dark ring, "d" and red roof).
    write(os.path.join(icon_dir, 'icon.png'), render(512, 'circle'))
    # Adaptive icon foreground: the "d" and roof on transparent, drawn over the
    # white adaptive_icon_background; the launcher mask replaces the ring.
    write(os.path.join(icon_dir, 'icon_foreground.png'), render(432, None, 1.0))

    if '--mipmaps' in sys.argv:
        res = os.path.join(ROOT, 'android', 'app', 'src', 'main', 'res')
        for name, px in [('mdpi', 48), ('hdpi', 72), ('xhdpi', 96), ('xxhdpi', 144), ('xxxhdpi', 192)]:
            write(os.path.join(res, f'mipmap-{name}', 'ic_launcher.png'), render(px, 'circle'))

    if '--web' in sys.argv:
        web = os.path.join(ROOT, 'web')
        write(os.path.join(web, 'favicon.png'), render(32, 'circle'))
        write(os.path.join(web, 'icons', 'Icon-192.png'), render(192, 'circle'))
        write(os.path.join(web, 'icons', 'Icon-512.png'), render(512, 'circle'))
        # Maskable icons: full-bleed white, glyph inside the 80% safe zone.
        write(os.path.join(web, 'icons', 'Icon-maskable-192.png'), render(192, 'square', 0.95))
        write(os.path.join(web, 'icons', 'Icon-maskable-512.png'), render(512, 'square', 0.95))


if __name__ == '__main__':
    main()
