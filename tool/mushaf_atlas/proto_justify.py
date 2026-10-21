"""Prototype: DigitalKhatt-style justification for the Madani muṣḥaf.

The app justifies a muṣḥaf line by widening its spaces. digitalkhatt.org
instead stretches the letters themselves (kashīdas). Its V2 font here is
static — no variable stretching — but it carries what a static font can:
`jalt`, 54 widened final and isolated forms (sīn, ṣād, nūn, qāf, yāʾ, bāʾ…),
and a tatweel glyph. This fits each line to the page's measure with those:

1. the line's natural width, words joined by plain spaces;
2. widened forms, one word at a time — longest gain first, at most one per
   word, never past the measure;
3. tatweels inserted before a word's last joined letter (never inside
   lām-alif, nor in the name of Allah), a few per line, again never past the measure;
4. what's left spread over the spaces, as the app does now.

The spaces keep [MIN_SPACE] more than their natural width before any
letter stretches, so words don't run together.

It renders sample pages both ways side by side (left: as now; right:
kashīdas) into tool/mushaf_atlas/out/justify_<page>.png, and prints how much
the spaces stretch either way.

Run (from the repo root, the atlas tool's venv):

    tool/mushaf_atlas/.venv/bin/python tool/mushaf_atlas/proto_justify.py [pages…]
"""

import os
import statistics
import sys

import freetype
import numpy as np
import uharfbuzz as hb
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_atlas import ROOT, load, text_lines, tokenize  # noqa: E402

FONT = os.path.join(ROOT, 'assets', 'fonts', 'DigitalKhattV2.otf')
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'out')
TATWEEL = 'ـ'
# Letters that join to the next one (a tatweel may follow them).
NON_JOINING = set('اأإآٱدذرزوؤءةى')
MAX_TATWEELS = 4
# How much wider than natural the spaces are before any letter stretches.
MIN_SPACE = .6
PX = 34  # px per em in the renders


class Font:
    def __init__(self):
        blob = hb.Blob.from_file_path(FONT)
        self.face = hb.Face(blob)
        self.font = hb.Font(self.face)
        self.upem = self.face.upem
        self.ft = freetype.Face(FONT)
        self.ft.set_char_size(PX * 64)
        self._cache = {}

    def shape(self, text, features=None):
        buf = hb.Buffer()
        buf.add_str(text)
        buf.guess_segment_properties()
        hb.shape(self.font, buf, features or {})
        return [(i.codepoint, p.x_advance, p.x_offset, p.y_offset)
                for i, p in zip(buf.glyph_infos, buf.glyph_positions)]

    def width(self, text, features=None):
        return sum(g[1] for g in self.shape(text, features))

    def bitmap(self, gid):
        if gid not in self._cache:
            self.ft.load_glyph(gid, freetype.FT_LOAD_DEFAULT | freetype.FT_LOAD_NO_HINTING)
            self.ft.glyph.render(freetype.FT_RENDER_MODE_NORMAL)
            b = self.ft.glyph.bitmap
            arr = np.array(b.buffer, dtype=np.uint8).reshape(b.rows, b.width) if b.rows else None
            self._cache[gid] = (arr, self.ft.glyph.bitmap_left, self.ft.glyph.bitmap_top)
        return self._cache[gid]


def with_tatweel(word):
    """[word] with a tatweel before its last letter, if the letter before
    that joins to it; else None. Marks stay with their letters."""
    letters = [i for i, c in enumerate(word) if 'ء' <= c <= 'ي' or c in 'ٱ']
    if len(letters) < 2:
        return None
    prev, last = letters[-2], letters[-1]
    if word[prev] in NON_JOINING:
        return None
    # Lām-alif is one ligature: never split.
    if word[prev] == 'ل' and word[last] in 'اأإآٱ':
        return None
    # Nor the name of Allah.
    if 'لله' in ''.join(word[i] for i in letters):
        return None
    # After the previous letter's marks.
    return word[:last] + TATWEEL + word[last:]


def fit(font, words, target):
    """Words as shaped for [target] units: (word variants, space width)."""
    space = font.width(' ')
    plain = [font.width(w) for w in words]
    shaped = list(words)
    feats = [None] * len(words)
    widths = list(plain)
    natural = sum(widths) + space * (len(words) - 1)
    # The spaces keep some air first: letters stretch only past that.
    room = target - natural - space * MIN_SPACE * (len(words) - 1)
    # Widened forms: biggest gain first, while they fit.
    gains = []
    for k, w in enumerate(words):
        g = font.width(w, {'jalt': True}) - plain[k]
        if g > 0:
            gains.append((g, k))
    for g, k in sorted(gains, reverse=True):
        if g <= room:
            feats[k] = {'jalt': True}
            widths[k] += g
            room -= g
    # Then tatweels, spread from the line's end.
    added = 0
    for k in reversed(range(len(words))):
        if added >= MAX_TATWEELS or feats[k]:
            continue
        t = with_tatweel(words[k])
        if t is None:
            continue
        g = font.width(t) - widths[k]
        if 0 < g <= room:
            shaped[k] = t
            widths[k] += g
            room -= g
            added += 1
    room += space * MIN_SPACE * (len(words) - 1)
    gap = space + (room / (len(words) - 1) if len(words) > 1 else 0)
    return shaped, feats, gap


def render(font, lines, target, kashida):
    w = int(target / font.upem * PX) + 40
    h = int(len(lines) * PX * 1.9) + 30
    img = np.zeros((h, w), dtype=np.uint16)
    stretch = []
    for li, words in enumerate(lines):
        space = font.width(' ')
        natural = sum(font.width(x) for x in words) + space * (len(words) - 1)
        short = natural < target * .75
        if kashida and not short:
            shaped, feats, gap = fit(font, words, target)
        else:
            shaped, feats = words, [None] * len(words)
            gap = space if short or len(words) < 2 else (
                space + (target - natural) / (len(words) - 1))
        stretch.append(gap / space)
        # Right to left: the first word at the right edge.
        pen = target if not short else (target + natural) / 2
        base = int(20 + (li + 1) * PX * 1.9 - PX * .5)
        for k, word in enumerate(shaped):
            glyphs = font.shape(word, feats[k])
            wd = sum(g[1] for g in glyphs)
            x = pen - wd
            for gid, adv, xo, yo in glyphs:
                arr, left, top = font.bitmap(gid)
                if arr is not None:
                    px = int(20 + (x + xo) / font.upem * PX) + left
                    py = base - int(yo / font.upem * PX) - top
                    hh, ww = arr.shape
                    if 0 <= py and py + hh <= h and 0 <= px and px + ww <= w:
                        img[py:py + hh, px:px + ww] += arr
                x += adv
            pen -= wd + gap
    out = 255 - np.clip(img, 0, 255).astype(np.uint8)
    return Image.fromarray(out), [s for s in stretch]


def main():
    pages = [int(a) for a in sys.argv[1:]] or [3, 50, 106, 250, 582]
    font = Font()
    text = load('assets/quran/mushaf_u_text.json')
    layout = load('assets/quran/mushaf_u_layout.json')
    tok, ayah_first, _ = tokenize(text)
    by_page = {}
    for pg, li, st, end in text_lines(layout, ayah_first, len(tok)):
        by_page.setdefault(pg, []).append(tok[st:end])
    em = load('assets/quran/mushaf_line_em_uthmani.json')['pages']
    os.makedirs(OUT, exist_ok=True)
    for pg in pages:
        lines = by_page[pg]
        target = max(17.3, max(em[str(pg)])) * font.upem
        now, s0 = render(font, lines, target, False)
        new, s1 = render(font, lines, target, True)
        sheet = Image.new('L', (now.width * 2 + 20, now.height), 200)
        sheet.paste(now, (0, 0))
        sheet.paste(new, (now.width + 20, 0))
        path = os.path.join(OUT, f'justify_{pg}.png')
        sheet.save(path)
        full0 = [s for s in s0 if s > 1.001]
        full1 = [s for s1_, s in zip(s0, s1) if s1_ > 1.001]
        print(f'page {pg}: spaces stretch ×{statistics.mean(full0):.2f} '
              f'(max ×{max(full0):.2f}) now, ×{statistics.mean(full1):.2f} '
              f'(max ×{max(full1):.2f}) with kashīdas → {path}')


if __name__ == '__main__':
    main()
