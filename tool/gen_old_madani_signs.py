"""Adds the clean signs to Old Madani's shared atlases, below what's there
(those pixels stay as they are: the sheet is written losslessly), and writes
where they are:

  docs/verse_circle_2.svg          the classic āyah circle
  docs/hizb_rub_hizb_marker.svg    ۞, in place of each page's own
  docs/sajdah_tilawah_makrer.svg   the sajdah sign, in place of each page's own

  assets/quran/old_madani/{high,low}/shared.webp
  assets/quran/old_madani/signs.json

    tool/mushaf_atlas/.venv/bin/python tool/gen_old_madani_signs.py

Needs skia-python, pillow, numpy and cwebp. Safe to run again: the manifests
say how tall the sheets were before this. The circle is sized so its opening
is as wide as the current frame's, and placed on where the digits really are
inside the frame (measured over every marker), so they sit centred in it. The
two signs are as tall as the print's (the median over all their places); the
app centres them on where the print's stood.
"""
import json
import os
import struct
import subprocess
import tempfile

import numpy as np
import skia
import statistics
from PIL import Image

ROOT = 'assets/quran/old_madani'
SVG = 'docs/verse_circle_2.svg'
SIGNS = {'sajdah': ('docs/sajdah_tilawah_makrer.svg', 3),
         'hizb': ('docs/hizb_rub_hizb_marker.svg', 5)}
KIND_FRAME = 3
GAP = 2


def sign_height(d, kind):
    """The print's sign of this type: its median height, in page pixels."""
    pe, = struct.unpack('<H', d[6:8])
    pc, rc = struct.unpack('<II', d[8:16])
    sc, se = struct.unpack('<HH', d[20:22] + d[22:24])
    rec, = struct.unpack('<H', d[26:28])
    start = 32 + sc * se + pc * pe
    hs = []
    for k in range(rc):
        i, _, _, _, h = struct.unpack('<IHHHH', d[start + k * rec:start + k * rec + 12])
        if (i >> 16) & 0xF == kind:
            hs.append(h)
    return round(statistics.median(hs))


def hole(alpha):
    """The opening's box round the sprite's middle: (left, top, right, bottom)."""
    h, w = alpha.shape
    # The middle of the sprite is inside the opening on both frames.
    cx, cy = w // 2, h // 2
    solid = alpha > 128
    l = cx
    while l > 0 and not solid[cy, l - 1]:
        l -= 1
    r = cx
    while r < w - 1 and not solid[cy, r + 1]:
        r += 1
    t = cy
    while t > 0 and not solid[t - 1, cx]:
        t -= 1
    b = cy
    while b < h - 1 and not solid[b + 1, cx]:
        b += 1
    return l, t, r + 1, b + 1


def digits_centre(d, table, frame_index):
    """Where the digits' middle sits in the frame, in the frame's own pixels:
    the median over every āyah marker in the manifest."""
    _, _, pe, pc, rc, ic, sc, se, inst, rec = struct.unpack('<IBBHIIIHHHH', d[:28])[0:2] + \
        struct.unpack('<HIIIHHHH', d[6:28])
    pt = 32 + sc * se
    ins = pt + pc * pe + rc * rec
    byid = {}
    for k in range(ic):
        i, shared, scale, x, y = struct.unpack('<IHHhh', d[ins + k * inst:ins + (k + 1) * inst])
        byid.setdefault(i, []).append((shared, scale / 32768, x / 4, y / 4))
    xs, ys = [], []
    for parts in byid.values():
        frame = next((p for p in parts if p[0] == frame_index), None)
        digits = [p for p in parts if table[p[0]][4] == 4]
        # (٠ is a small dot, and rare: a marker's other digits place it.)
        if frame is None or not digits:
            continue
        _, fs, fx, fy = frame
        boxes = [(x, y, x + table[n][2] * s, y + table[n][3] * s) for n, s, x, y in digits]
        l, t = min(b[0] for b in boxes), min(b[1] for b in boxes)
        r, b = max(b[2] for b in boxes), max(b[3] for b in boxes)
        xs.append(((l + r) / 2 - fx) / fs)
        ys.append(((t + b) / 2 - fy) / fs)
    return float(np.median(xs)), float(np.median(ys))


def render(svg, width, height):
    """The SVG at this size: coverage as alpha, on nothing."""
    dom = skia.SVGDOM.MakeFromStream(skia.MemoryStream(svg))
    size = dom.containerSize()
    surface = skia.Surface(width, height)
    canvas = surface.getCanvas()
    canvas.clear(skia.ColorTRANSPARENT)
    canvas.scale(width / size.width(), height / size.height())
    dom.render(canvas)
    pixels = surface.makeImageSnapshot().toarray(colorType=skia.kRGBA_8888_ColorType,
                                                 alphaType=skia.kUnpremul_AlphaType)
    return pixels[..., 3]


def main():
    svg = open(SVG, 'rb').read()
    # The SVG's own shape and opening, measured large.
    dom = skia.SVGDOM.MakeFromStream(skia.MemoryStream(svg))
    size = dom.containerSize()
    ratio = size.height() / size.width()
    big = render(svg, 1600, round(1600 * ratio))
    l, _, r, _ = hole(big)
    hole_share = (r - l) / 1600

    out = {}
    for tier in ('high', 'low'):
        d = open(f'{ROOT}/{tier}/mushaf_manifest.bin', 'rb').read()
        sc, se = struct.unpack('<HH', d[20:24])
        sw, sh = struct.unpack('<HH', d[28:32])
        table = [struct.unpack('<HHHHBBH', d[32 + i * se:32 + (i + 1) * se]) for i in range(sc)]
        fx, fy, fw, fh, *_ = next(s for s in table if s[4] == KIND_FRAME)

        sheet = Image.open(f'{ROOT}/{tier}/shared.webp').convert('RGBA')
        was = np.array(sheet)[:sh, :sw]
        fl, ft, fr, fb = hole(was[fy:fy + fh, fx:fx + fw, 3])
        w = round((fr - fl) / hole_share)
        h = round(w * ratio)
        sprite = render(svg, w, h)

        # On one row below the sheet: the circle, then the signs.
        placed, x = {}, w + GAP
        for name, (path, kind) in SIGNS.items():
            raw = open(path, 'rb').read()
            z = skia.SVGDOM.MakeFromStream(skia.MemoryStream(raw)).containerSize()
            sh2 = sign_height(d, kind)
            sw2 = round(sh2 * z.width() / z.height())
            placed[name] = (x, sw2, sh2, render(raw, sw2, sh2))
            x += sw2 + GAP
        tall = max([h] + [p[2] for p in placed.values()])
        canvas = np.zeros((sh + GAP + tall, max(sw, x), 4), dtype=np.uint8)
        canvas[:sh, :sw] = was
        canvas[sh + GAP:sh + GAP + h, 0:w, 3] = sprite
        for px, pw, ph, a in placed.values():
            canvas[sh + GAP:sh + GAP + ph, px:px + pw, 3] = a

        with tempfile.TemporaryDirectory() as tmp:
            png = os.path.join(tmp, 's.png')
            Image.fromarray(canvas, 'RGBA').save(png)
            subprocess.run(['cwebp', '-quiet', '-lossless', '-exact', png,
                            '-o', f'{ROOT}/{tier}/shared.webp'], check=True)
        check = np.array(Image.open(f'{ROOT}/{tier}/shared.webp').convert('RGBA'))
        if not np.array_equal(check[:sh, :sw, 3], was[..., 3]):
            raise SystemExit(f'{tier}: the existing sprites changed')

        cx, cy = digits_centre(d, table, table.index(next(s for s in table if s[4] == KIND_FRAME)))
        out[tier] = {
            'rect': [0, sh + GAP, w, h],
            # The digits' middle, in the current frame's own pixels.
            'frameCentre': [round(cx, 2), round(cy, 2)],
            **{name: [p[0], sh + GAP, p[1], p[2]] for name, p in placed.items()},
        }
        print(f'{tier}: frame opening centre {(fl + fr) / 2},{(ft + fb) / 2}; '
              f'digits centre {cx:.1f},{cy:.1f}')
        print(f'{tier}: frame opening {fr - fl}x{fb - ft}; classic {w}x{h} at y={sh + GAP}; '
              f'sheet {canvas.shape[1]}x{canvas.shape[0]}, '
              f'{os.path.getsize(f"{ROOT}/{tier}/shared.webp") // 1024} KB')
    json.dump(out, open(f'{ROOT}/signs.json', 'w'), separators=(',', ':'))


main()
