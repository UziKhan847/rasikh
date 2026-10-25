"""Side-by-side pages from the justification run (out/lines.json): the app's
current look (DigitalKhattV2, lines justified by widening the spaces) on the
left, DigitalKhatt New Madina justified by digitalkhatt.org's engine on the
right — to judge before anything changes in the app.

    tool/mushaf_atlas/.venv/bin/python tool/mushaf_justify/render.py [pages…]

Writes tool/mushaf_justify/out/page_<n>.png.
"""

import json
import os
import sys

import freetype
import numpy as np
import uharfbuzz as hb
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))
PX = 40  # px per em
PITCH = 1.8  # line pitch, em (the app's MushafGeometry.pitch)
FONTSIZE = 1000


class Font:
    def __init__(self, path):
        self.face = hb.Face(hb.Blob.from_file_path(path))
        self.font = hb.Font(self.face)
        self.upem = self.face.upem
        self.ft = freetype.Face(path)
        self.ft.set_char_size(PX * 64)
        self.cache = {}

    def shape(self, text, features=None):
        buf = hb.Buffer()
        buf.add_str(text)
        buf.guess_segment_properties()
        buf.cluster_level = hb.BufferClusterLevel.MONOTONE_CHARACTERS
        hb.shape(self.font, buf, features or {})
        return [(i.codepoint, p.x_advance, p.x_offset, p.y_offset)
                for i, p in zip(buf.glyph_infos, buf.glyph_positions)]

    def bitmap(self, gid):
        if gid not in self.cache:
            self.ft.load_glyph(gid, freetype.FT_LOAD_DEFAULT | freetype.FT_LOAD_NO_HINTING)
            self.ft.glyph.render(freetype.FT_RENDER_MODE_NORMAL)
            b = self.ft.glyph.bitmap
            arr = np.array(b.buffer, dtype=np.uint8).reshape(b.rows, b.width) if b.rows else None
            self.cache[gid] = (arr, self.ft.glyph.bitmap_left, self.ft.glyph.bitmap_top)
        return self.cache[gid]


def draw_run(img, font, glyphs, x_right, base, scale_x=1.0):
    """Draws [glyphs] (font units) ending at x_right (px), right to left."""
    h, w = img.shape
    width = sum(g[1] for g in glyphs) * scale_x
    x = x_right - width / font.upem * PX
    for gid, adv, xo, yo in glyphs:
        arr, left, top = font.bitmap(gid)
        if arr is not None:
            px = int(round(x + xo * scale_x / font.upem * PX)) + left
            py = base - int(round(yo / font.upem * PX)) - top
            hh, ww = arr.shape
            y0, x0 = max(py, 0), max(px, 0)
            y1, x1 = min(py + hh, h), min(px + ww, w)
            if y1 > y0 and x1 > x0:
                img[y0:y1, x0:x1] += arr[y0 - py:y1 - py, x0 - px:x1 - px]
        x += adv * scale_x / font.upem * PX
    return width / font.upem * PX


def render_page(lines, font, measure_of, justified):
    """One page's text lines. [justified]: use the engine's features and
    spaces; else widen the spaces to the measure (the app today)."""
    measure_px = max(measure_of(l) for l in lines) / FONTSIZE * PX
    w = int(measure_px) + 40
    h = int((max(l['line'] for l in lines) + 1) * PITCH * PX) + 40
    img = np.zeros((h, w), dtype=np.uint16)
    space = font.shape(' ')[0][1]
    for l in lines:
        words = l['text'].split(' ')
        base = int(20 + (l['line'] + 0.72) * PITCH * PX)
        target = measure_of(l) * l['ratio'] / FONTSIZE * PX
        right = 20 + measure_px - (measure_px - target) / 2
        if justified:
            # Word by word, as the engine measured them: each word with its
            # characters' features, the spaces as the engine set them.
            feats, pos = l['features'], 0
            runs = []
            for word in words:
                f = {}
                for k, v in feats.items():
                    i = int(k)
                    if pos <= i < pos + len(word):
                        for name, val in v:
                            f.setdefault(name, []).append((i - pos, i - pos + 1, val))
                runs.append(font.shape(word, f))
                pos += len(word) + 1
            gaps = []
            for k in range(len(words) - 1):
                aya = words[k][-1:].isdigit() or words[k][-1:] in '٠١٢٣٤٥٦٧٨٩' or words[k + 1].startswith('۝')
                gaps.append((l['ayaSpacing'] if aya else l['simpleSpacing']) / FONTSIZE * PX)
            sx = l['xScale']
        else:
            runs = [font.shape(word) for word in words]
            natural = sum(sum(g[1] for g in r) for r in runs) / font.upem * PX
            n = max(1, len(words) - 1)
            gap = max(space / font.upem * PX, (target - natural) / n) if len(words) > 1 else 0
            gaps = [gap] * (len(words) - 1)
            sx = 1.0
        x = right
        for k, r in enumerate(runs):
            x -= draw_run(img, font, r, x, base, sx)
            if k < len(gaps):
                x -= gaps[k]
    return Image.fromarray(255 - np.clip(img, 0, 255).astype(np.uint8))


def main():
    data = json.load(open(os.path.join(HERE, 'out', 'lines.json'), encoding='utf-8'))
    pages = [int(a) for a in sys.argv[1:]] or [3, 50, 106, 250, 582]
    madina = Font(os.path.join(HERE, 'fonts', 'madina.otf'))
    dk2 = Font(os.path.join(ROOT, 'assets', 'fonts', 'DigitalKhattV2.otf'))
    for pg in pages:
        lines = [l for l in data['lines'] if l['page'] == pg]
        if not lines:
            continue
        # The app today: DigitalKhattV2, its own widest line as the measure.
        def dk2_width(l):
            return sum(g[1] for g in dk2.shape(l['text'].replace('͏', ''))) / dk2.upem * FONTSIZE
        dk2_measure = max(dk2_width(l) / l['ratio'] for l in lines)
        now = render_page([{**l, 'text': l['text'].replace('͏', '')} for l in lines],
                          dk2, lambda l: dk2_measure, False)
        new = render_page(lines, madina, lambda l: l['measure'], True)
        hgt = max(now.height, new.height)
        sheet = Image.new('L', (now.width + new.width + 30, hgt + 30), 200)
        sheet.paste(now, (0, 30))
        sheet.paste(new, (now.width + 30, 30))
        d = ImageDraw.Draw(sheet)
        d.text((10, 8), f'p.{pg} — now: DigitalKhattV2, spaces widened', fill=0)
        d.text((now.width + 40, 8), 'justified: New Madina + kashidas (digitalkhatt.org engine)', fill=0)
        path = os.path.join(HERE, 'out', f'page_{pg}.png')
        sheet.save(path)
        print(path)


if __name__ == '__main__':
    main()
