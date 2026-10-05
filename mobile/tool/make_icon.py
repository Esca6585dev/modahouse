#!/usr/bin/env python3
"""Generates the ModaHouse launcher icon PNGs (accent #d6336c, white "M").

No third-party packages: a tiny scanline rasterizer + zlib PNG writer.

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

ACCENT = (0xD6, 0x33, 0x6C)
WHITE = (255, 255, 255)
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# Bold "M" outline in a unit box (x right, y down).
M_SHAPE = [
    (0.00, 1.00), (0.00, 0.00), (0.22, 0.00), (0.50, 0.42), (0.78, 0.00),
    (1.00, 0.00), (1.00, 1.00), (0.79, 1.00), (0.79, 0.36), (0.57, 0.68),
    (0.43, 0.68), (0.21, 0.36), (0.21, 1.00),
]


def polygon_coverage(size, poly, sub=4):
    """Anti-aliased coverage (0..1) of a polygon given in pixel coordinates."""
    cov = [[0.0] * size for _ in range(size)]
    n = len(poly)
    for py in range(size):
        row = cov[py]
        for s in range(sub):
            y = py + (s + 0.5) / sub
            xs = []
            for i in range(n):
                x1, y1 = poly[i]
                x2, y2 = poly[(i + 1) % n]
                if (y1 <= y < y2) or (y2 <= y < y1):
                    xs.append(x1 + (y - y1) * (x2 - x1) / (y2 - y1))
            xs.sort()
            for a, b in zip(xs[0::2], xs[1::2]):
                a = max(0.0, a)
                b = min(float(size), b)
                if b <= a:
                    continue
                ia, ib = int(a), int(math.ceil(b))
                for px in range(ia, min(ib, size)):
                    left = max(a, px)
                    right = min(b, px + 1)
                    if right > left:
                        row[px] += (right - left) / sub
    return cov


def m_polygon(size, box):
    """The M scaled into box=(x0, y0, w, h) of a size x size canvas."""
    x0, y0, w, h = box
    return [(x0 + x * w, y0 + y * h) for x, y in M_SHAPE]


def render(size, background, m_scale):
    """background: 'circle', 'square' (full bleed) or None (transparent)."""
    m_w = size * m_scale
    m_h = m_w * 0.86
    poly = m_polygon(size, ((size - m_w) / 2, (size - m_h) / 2, m_w, m_h))
    m_cov = polygon_coverage(size, poly)
    c = size / 2
    r = size / 2 - 0.5
    pixels = bytearray()
    for y in range(size):
        pixels.append(0)  # filter: none
        for x in range(size):
            if background == 'circle':
                d = math.hypot(x + 0.5 - c, y + 0.5 - c)
                bg_a = max(0.0, min(1.0, r - d + 0.5))
            elif background == 'square':
                bg_a = 1.0
            else:
                bg_a = 0.0
            m = min(1.0, m_cov[y][x])
            # white M over the background
            a = m + bg_a * (1 - m)
            if a <= 0:
                pixels += b'\x00\x00\x00\x00'
                continue
            rgb = [
                round((WHITE[i] * m + ACCENT[i] * bg_a * (1 - m)) / a)
                for i in range(3)
            ]
            pixels += bytes(rgb) + bytes([round(a * 255)])
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
    # Legacy icon: accent circle with a white M (same as the in-app logo).
    write(os.path.join(icon_dir, 'icon.png'), render(512, 'circle', 0.50))
    # Adaptive icon foreground: M only, inside the 66% safe zone.
    write(os.path.join(icon_dir, 'icon_foreground.png'), render(432, None, 0.50))

    if '--mipmaps' in sys.argv:
        res = os.path.join(ROOT, 'android', 'app', 'src', 'main', 'res')
        for name, px in [('mdpi', 48), ('hdpi', 72), ('xhdpi', 96), ('xxhdpi', 144), ('xxxhdpi', 192)]:
            write(os.path.join(res, f'mipmap-{name}', 'ic_launcher.png'), render(px, 'circle', 0.50))

    if '--web' in sys.argv:
        web = os.path.join(ROOT, 'web')
        write(os.path.join(web, 'favicon.png'), render(32, 'circle', 0.50))
        write(os.path.join(web, 'icons', 'Icon-192.png'), render(192, 'circle', 0.50))
        write(os.path.join(web, 'icons', 'Icon-512.png'), render(512, 'circle', 0.50))
        write(os.path.join(web, 'icons', 'Icon-maskable-192.png'), render(192, 'square', 0.40))
        write(os.path.join(web, 'icons', 'Icon-maskable-512.png'), render(512, 'square', 0.40))


if __name__ == '__main__':
    main()
