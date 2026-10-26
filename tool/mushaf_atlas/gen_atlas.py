"""Builds the muṣḥaf glyph atlases: assets/quran/atlas/{script}.bin plus
{script}_{E}_{n}.png sheets, for the Madani (DigitalKhattV2) and Indo-Pak
(DigitalKhattIndoPak) 15-line muṣḥafs.

The app draws the page text from these with Canvas.drawRawAtlas instead of
shaping and drawing DigitalKhatt text at runtime (see
lib/screens/mushaf/mushaf_atlas.dart). Every glyph the text uses is
rasterised once (FreeType, unhinted) at two sizes; every word is shaped once
(HarfBuzz — the shaper Flutter uses) into glyphs and positions; every token
of the muṣḥaf text points at its word; and every token carries the tajwīd
rule of each glyph, mapped from the reader's tajwīd spans.

Setup and run (from the repo root):

    python3 -m venv tool/mushaf_atlas/.venv
    tool/mushaf_atlas/.venv/bin/pip install -r tool/mushaf_atlas/requirements.txt
    tool/mushaf_atlas/.venv/bin/python tool/mushaf_atlas/gen_atlas.py

It stops with an error if any line's width disagrees with the widths Flutter
measured (assets/quran/mushaf_line_em_{script}.json) — the proof that the
offline shaping matches what the app would have drawn.

The Madani muṣḥaf is the exception: it is set justified, in DigitalKhatt New
Madina, by digitalkhatt.org's engine — run tool/mushaf_justify first
(`node --experimental-transform-types justify.mts` there; see its README).
Its lines' widths are then written to mushaf_line_em_uthmani.json instead
of checked against it; rerun tool/gen_mushaf_page_ratios.py after.

Āyah markers are composed, not baked whole. The fonts shape ۝ + digits into
one ligature per number (endofaya1…286), which used to fill most of every
sheet. Each ligature is the bare circle's outline plus the digit outlines, so
the generator reads where every digit sits (and, in Indo-Pak's squeezed
three-digit numbers, how much it is narrowed) straight from the outlines and
draws the marker as the circle plus digit glyphs. Narrowed digits get their
own sprites, rasterised narrowed, with the factor rounded to MARKER_SX_STEP.
A self-check compares every composed marker with its ligature as the app
would draw it, and writes a contact sheet to tool/mushaf_atlas/out/.
"""
import json
import os
import struct
import sys
import unicodedata
from collections import Counter

import freetype
import numpy as np
import uharfbuzz as hb
from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
OUT = os.path.join(ROOT, 'assets', 'quran', 'atlas')
CHECK_OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'out')
TIERS = (64, 128)  # px per em
SHEET = 2048
PAD = 2
FORMAT_VERSION = 2  # 2: composed āyah markers; 3: justified lines (same bytes)

# Horizontal narrowing of a marker digit is rounded to this step (Indo-Pak
# squeezes three-digit numbers by 135 slightly different factors). 0.02 of a
# digit about 60 px wide at E128 is at most 0.6 px.
MARKER_SX_STEP = 0.02
# The composed-marker self-check fails above this mean difference, as a
# fraction of the ligature's ink.
MARKER_MAX_DIFF = 0.06
ARABIC_DIGITS = '٠١٢٣٤٥٦٧٨٩'

# The Madani muṣḥaf is set justified: DigitalKhatt New Madina, each line
# fitted with kashīdas and widened letters by digitalkhatt.org's engine
# (tool/mushaf_justify: run it first; its lines.json gives each character's
# features and the line's spaces).
JUSTIFIED = os.path.join(ROOT, 'tool', 'mushaf_justify', 'out', 'lines.json')

SCRIPTS = {
    'uthmani': dict(font='DigitalKhattV2.otf', text='mushaf_u_text.json',
                    layout='mushaf_u_layout.json', reader='u', tajwid='t',
                    justified=JUSTIFIED,
                    font_path=os.path.join(ROOT, 'tool', 'mushaf_justify',
                                           'fonts', 'madina.otf')),
    'indopak': dict(font='DigitalKhattIndoPak.otf', text='mushaf_i_text.json',
                    layout='mushaf_i_layout.json', reader='i',
                    tajwid='t_indopak'),
}

# Characters Flutter lays out as their own left-to-right runs inside the
# right-to-left line: the āyah sign ۝ and both digit sets. (The disputed-end
# sign U+08E2 is also a number for bidi, but Flutter's measurements only
# match with it left inside the word — found by comparing every line.)
def is_number(c):
    o = ord(c)
    return o == 0x06DD or 0x0660 <= o <= 0x0669 or 0x06F0 <= o <= 0x06F9


def number_flags(text):
    """Per character, whether it's shaped in a number run. A combining
    mark right after a number run stays in it: Indo-Pak puts waqf signs
    (ۙ ۚ ج …) and the rukūʿ sign ࣖ after an āyah's digits, and only shaped
    together with the ligature does the font seat them above the circle —
    split off into the next run they land on their own, through it."""
    out = []
    for c in text:
        num = is_number(c)
        if not num and out and out[-1] and unicodedata.category(c) == 'Mn':
            num = True
        out.append(num)
    return out


def fnv1a(tokens):
    """FNV-1a over the UTF-16 code units of the tokens joined by '\\n' —
    mirrored in Dart to detect a muṣḥaf text that drifted from the atlas."""
    h = 0x811C9DC5
    data = '\n'.join(tokens).encode('utf-16-le')
    for i in range(0, len(data), 2):
        h ^= data[i] | (data[i + 1] << 8)
        h = (h * 0x01000193) & 0xFFFFFFFF
    return h


def load(path):
    with open(os.path.join(ROOT, path), encoding='utf-8') as f:
        return json.load(f)


def tokenize(text):
    tok, ayah_first, tok_ayah = [], [], []
    for a, s in enumerate(text):
        ayah_first.append(len(tok))
        for t in s.split('‌'):
            if t:
                tok.append(t)
                tok_ayah.append(a)
    ayah_first.append(len(tok))
    return tok, ayah_first, tok_ayah


def text_lines(layout, ayah_first, ntok):
    """[(page 1-based, line index, first token, end token)] for text lines."""
    starts = []
    for pi, p in enumerate(layout):
        for li, (a, w) in enumerate(p):
            if a >= 0:
                starts.append((pi + 1, li, ayah_first[a] + w))
    out = []
    for k, (pg, li, st) in enumerate(starts):
        end = starts[k + 1][2] if k + 1 < len(starts) else ntok
        out.append((pg, li, st, end))
    return out


class Shaper:
    def __init__(self, font_path):
        blob = hb.Blob.from_file_path(font_path)
        self.face = hb.Face(blob)
        self.font = hb.Font(self.face)
        self.upem = self.face.upem

    def _run(self, text, rtl, features=None):
        buf = hb.Buffer()
        buf.add_str(text)
        buf.direction = 'rtl' if rtl else 'ltr'
        buf.script = 'Arab'
        buf.language = 'ar'
        buf.cluster_level = hb.BufferClusterLevel.CHARACTERS
        hb.shape(self.font, buf, features or {})
        return buf.glyph_infos, buf.glyph_positions

    def shape_line(self, text):
        """Glyphs of a whole line, left to right, as (gid, char index,
        x offset, y offset, x advance). Runs of number characters (the āyah
        sign and its digits) are shaped on their own, left to right, the way
        Flutter's bidi splits them; spaces stay with the text around them."""
        runs, start = [], 0
        flags = number_flags(text)
        for i in range(1, len(text) + 1):
            if i == len(text) or flags[i] != flags[start]:
                runs.append((start, text[start:i], not flags[start]))
                start = i
        out = []
        for st, run, rtl in reversed(runs):
            infos, poss = self._run(run, rtl)
            for info, pos in zip(infos, poss):
                out.append((info.codepoint, st + info.cluster, pos.x_offset,
                            pos.y_offset, pos.x_advance))
        return out

    def shape(self, token, features=None):
        """Glyphs of [token] left to right: (gid, x, y, char index), and the
        token's advance — all in font units, origin at its left edge.
        [features]: {tag: [(start, end, value)]} by character of [token]
        (the justification's)."""
        runs, start = [], 0
        flags = number_flags(token)
        for i in range(1, len(token) + 1):
            if i == len(token) or flags[i] != flags[start]:
                runs.append((start, token[start:i], not flags[start]))
                start = i
        glyphs, x = [], 0
        # A right-to-left line shows its runs right to left: the last run is
        # leftmost.
        for st, text, rtl in reversed(runs):
            f = None
            if features:
                f = {tag: [(a - st, b - st, v) for a, b, v in spans
                           if st <= a < st + len(text)]
                     for tag, spans in features.items()}
                f = {tag: v for tag, v in f.items() if v}
            infos, poss = self._run(text, rtl, f)
            for info, pos in zip(infos, poss):
                glyphs.append((info.codepoint, x + pos.x_offset, pos.y_offset,
                               st + info.cluster))
                x += pos.x_advance
        return glyphs, x


def narrowed(gid, sx):
    """Atlas key of glyph [gid] narrowed horizontally by [sx] (a marker
    digit); a plain gid when it isn't narrowed."""
    sx = round(round(sx / MARKER_SX_STEP) * MARKER_SX_STEP, 4)
    return gid if sx >= 1 else ('sx', gid, sx)


def key_gid(key):
    return key if isinstance(key, int) else key[1]


def rasterise(font_path, keys, em, delta=(0, 0)):
    """Bitmap, left and top bearing (px) per atlas key: a glyph id, or a
    narrowed glyph (see [narrowed]). [delta] shifts the pen by a fraction of
    a pixel (in 1/64 px) — only the self-check uses it."""
    face = freetype.Face(font_path)
    face.set_char_size(em * 64, 0, 72, 72)
    out = {}
    flags = freetype.FT_LOAD_NO_HINTING | freetype.FT_LOAD_RENDER
    for k in keys:
        sx = 1.0 if isinstance(k, int) else k[2]
        face.set_transform(freetype.Matrix(int(round(sx * 0x10000)), 0, 0,
                                           0x10000),
                           freetype.Vector(*delta))
        face.load_glyph(key_gid(k), flags)
        bm = face.glyph.bitmap
        if bm.width == 0 or bm.rows == 0:
            out[k] = None
            continue
        a = np.array(bm.buffer, dtype=np.uint8).reshape(bm.rows, bm.pitch)
        out[k] = (a[:, :bm.width].copy(), face.glyph.bitmap_left,
                  face.glyph.bitmap_top)
    return out


def marker_parts(font_path):
    """For every āyah-number ligature glyph (endofaya1…): the circle's gid
    and the digits to draw on it, as (atlas key, dx, dy) in font units from
    the ligature's origin. Read from the outlines: a ligature is the bare
    circle's contours followed by each digit's, each digit placed (and in
    Indo-Pak sometimes narrowed) by an affine map this fits exactly."""
    from fontTools.pens.recordingPen import DecomposingRecordingPen
    from fontTools.ttLib import TTFont
    tt = TTFont(font_path)
    gs = tt.getGlyphSet()
    names = tt.getGlyphOrder()
    gid_of = {n: i for i, n in enumerate(names)}
    shaper = Shaper(font_path)

    def glyph(text):
        """The one glyph [text] shapes to (by name), or None. Found by
        shaping, not by name: DigitalKhattV2 calls the marker of 12
        endofaya12, DigitalKhatt New Madina an anonymous glyph00…"""
        g, _ = shaper.shape(text)
        return names[g[0][0]] if len(g) == 1 else None

    digits = [glyph(d) for d in ARABIC_DIGITS]

    def contours(name):
        pen = DecomposingRecordingPen(gs)
        gs[name].draw(pen)
        cs, cur = [], []
        for op, args in pen.value:
            cur.extend(args)
            if op in ('closePath', 'endPath'):
                cs.append(np.array(cur, float))
                cur = []
        return cs

    def solid(name):
        # Without empty contours (New Madina starts each marker with one).
        return [c for c in contours(name) if len(c) > 1]

    circle_name = glyph('۝')
    circle = solid(circle_name)
    digit = [contours(d) for d in digits]
    out = {}
    worst = 0.0
    n = 1
    while n <= 286:
        lig = glyph('۝' + ''.join(ARABIC_DIGITS[int(c)] for c in str(n)))
        if lig is None or lig == circle_name:
            sys.exit(f'۝{n}: not one ligature glyph')
        cs = solid(lig)
        head = cs[:len(circle)]
        # The circle, perhaps a unit or two off the bare one's place (New
        # Madina): placed like the digits.
        if len(head) != len(circle) or any(
                a.shape != b.shape for a, b in zip(circle, head)):
            sys.exit(f'۝{n} ({lig}): does not start with the bare circle')
        shift = np.vstack(head).mean(0) - np.vstack(circle).mean(0)
        if (np.abs(shift).max() > 3 or any(
                np.abs(b - a - shift).max() > 1 for a, b in zip(circle, head))):
            sys.exit(f'۝{n} ({lig}): does not start with the bare circle')
        circle_part = (gid_of[circle_name], int(round(shift[0])), int(round(shift[1])))
        rest = cs[len(circle):]
        best = None
        # The digits' contours come in reading or in visual order.
        for order in (str(n), str(n)[::-1]):
            parts, k, err = [], 0, 0.0
            for ch in order:
                d = digit[int(ch)]
                c = rest[k:k + len(d)]
                k += len(d)
                if len(c) != len(d) or any(a.shape != b.shape
                                           for a, b in zip(c, d)):
                    parts = None
                    break
                dd, cc = np.vstack(d), np.vstack(c)
                sx, tx = np.polyfit(dd[:, 0], cc[:, 0], 1)
                sy, ty = np.polyfit(dd[:, 1], cc[:, 1], 1)
                if abs(sy - 1) > 1e-3 or sx > 1 + 1e-3:
                    parts = None
                    break
                err = max(err, np.abs(sx * dd[:, 0] + tx - cc[:, 0]).max(),
                          np.abs(dd[:, 1] + ty - cc[:, 1]).max())
                parts.append((narrowed(gid_of[digits[int(ch)]], sx),
                              int(round(tx)), int(round(ty))))
            if parts is not None and k == len(rest) and (
                    best is None or err < best[1]):
                best = (parts, err)
        if best is None:
            sys.exit(f'۝{n} ({lig}): digits not found in its outline')
        out[gid_of[lig]] = [circle_part, *best[0]]
        worst = max(worst, best[1])
        n += 1
    print(f'  markers: {len(out)} ligatures read from the outlines '
          f'(worst fit {worst:.3f} units)')
    return gid_of[circle_name], out


def compose_markers(tok_glyphs, circle, parts):
    """Swaps every āyah-number ligature in the tokens for the circle plus
    its digits, in place. Returns how many it swapped."""
    swapped = 0
    for t, glyphs in enumerate(tok_glyphs):
        if not any(g[0] in parts for g in glyphs):
            continue
        out = []
        for g, x, y, c in glyphs:
            if g in parts:
                # The circle, then its digits.
                out.extend((k, x + dx, y + dy, c) for k, dx, dy in parts[g])
                swapped += 1
            else:
                out.append((g, x, y, c))
        tok_glyphs[t] = out
    return swapped


def check_markers(script, font_path, upem, circle, parts):
    """Draws every composed marker the way the app draws the atlas — each
    sprite at its fractional position, bilinear — and compares it with the
    ligature rasterised directly. Fails if any differs by more than
    MARKER_MAX_DIFF of its ink; writes a contact sheet of the worst."""
    em = TIERS[0]
    k = em / upem
    keys = sorted({circle} | {p[0] for ps in parts.values() for p in ps},
                  key=str)
    sprites = rasterise(font_path, keys, em)
    ligs = rasterise(font_path, list(parts), em)
    results = []
    for lig, ps in parts.items():
        ref, left, top = ligs[lig]
        canvas = np.zeros((ref.shape[0] + 8, ref.shape[1] + 8), float)
        ox, oy = 4 - left, 4 + top  # pen origin in canvas px

        def paste(key, x, y):
            b = sprites[key]
            if b is None:
                return
            a, bl, bt = b
            fx, fy = ox + x * k + bl, oy - y * k - bt
            ix, iy = int(np.floor(fx)), int(np.floor(fy))
            ax, ay = fx - ix, fy - iy
            p = np.pad(a.astype(float), 1)
            # Bilinear: output pixel (r, c) takes the sprite pixels (r, c),
            # (r, c-1), (r-1, c), (r-1, c-1), weighted by the overlap.
            mixed = ((1 - ax) * (1 - ay) * p[1:, 1:] + ax * (1 - ay) * p[1:, :-1]
                     + (1 - ax) * ay * p[:-1, 1:] + ax * ay * p[:-1, :-1])
            h, w = mixed.shape
            region = canvas[iy:iy + h, ix:ix + w]
            if iy < 0 or ix < 0 or region.shape != mixed.shape:
                sys.exit(f'{script}: a marker digit lands outside its circle')
            np.maximum(region, mixed, out=region)

        for key, dx, dy in ps:
            paste(key, dx, dy)
        want = np.zeros_like(canvas)
        want[4:4 + ref.shape[0], 4:4 + ref.shape[1]] = ref
        diff = np.abs(canvas - want).sum() / max(want.sum(), 1)
        results.append((diff, lig, want, canvas))
    results.sort(key=lambda r: -r[0])
    mean = sum(r[0] for r in results) / len(results)
    print(f'  marker check (E{em}): mean difference {mean * 100:.2f}% of '
          f'the ink, worst {results[0][0] * 100:.2f}%')
    os.makedirs(CHECK_OUT, exist_ok=True)
    rows = []
    for _, _, want, got in results[:12]:
        d = np.abs(got - want)
        rows.append(np.hstack([want, got, d]))
    w = max(r.shape[1] for r in rows)
    sheet = np.vstack([np.pad(r, ((2, 2), (0, w - r.shape[1]))) for r in rows])
    Image.fromarray((255 - np.clip(sheet, 0, 255)).astype(np.uint8), 'L').save(
        os.path.join(CHECK_OUT, f'{script}_markers.png'))
    if results[0][0] > MARKER_MAX_DIFF:
        sys.exit(f'{script}: a composed āyah marker differs from its ligature')


def pack(order, bitmaps):
    """Shelf-packs the glyphs into SHEET×SHEET sheets, frequent glyphs first
    (most lines then draw from sheet 0). Returns placement per gid and the
    sheet images."""
    place, sheets = {}, []
    cap = SHEET * SHEET * 0.82
    groups, cur, area = [], [], 0
    for g in order:
        b = bitmaps[g]
        if b is None:
            continue
        a = (b[0].shape[1] + 2 * PAD) * (b[0].shape[0] + 2 * PAD)
        if area + a > cap and cur:
            groups.append(cur)
            cur, area = [], 0
        cur.append(g)
        area += a
    if cur:
        groups.append(cur)
    pending = [g for grp in groups for g in grp]
    si = 0
    while pending:
        group = sorted(pending, key=lambda g: -bitmaps[g][0].shape[0])
        img = np.zeros((SHEET, SHEET), dtype=np.uint8)
        x = y = shelf = 0
        left = []
        used_h = 0
        for g in group:
            a = bitmaps[g][0]
            w, h = a.shape[1] + 2 * PAD, a.shape[0] + 2 * PAD
            if x + w > SHEET:
                y += shelf
                x = shelf = 0
            if y + h > SHEET:
                left.append(g)
                continue
            img[y + PAD:y + PAD + a.shape[0], x + PAD:x + PAD + a.shape[1]] = a
            place[g] = (si, x + PAD, y + PAD, a.shape[1], a.shape[0])
            x += w
            shelf = max(shelf, h)
            used_h = max(used_h, y + h)
        sheets.append(img[:max(used_h, 1)])
        pending = left
        si += 1
    return place, sheets


def reader_word_ranges(ayah):
    """QuranRepo.wordRanges: words of the reader's āyah, annotation-only
    tokens merged into their neighbour."""
    raw, p = [], 0
    for t in ayah.split(' '):
        if t:
            raw.append((p, p + len(t)))
        p += len(t) + 1
    ranges, pending = [], None
    for a, b in raw:
        if all(is_annotation(c) for c in ayah[a:b]):
            if ranges:
                ranges[-1] = (ranges[-1][0], b)
            else:
                pending = (a, b)
        elif pending is not None:
            ranges.append((pending[0], b))
            pending = None
        else:
            ranges.append((a, b))
    return ranges


def is_annotation(c):
    o = ord(c)
    return (0x0610 <= o <= 0x061A or 0x064B <= o <= 0x065F or o == 0x0670
            or 0x06D6 <= o <= 0x06ED or 0x08D3 <= o <= 0x08FF
            or 0x200D <= o <= 0x200F)


def clusters(word):
    """Base letter + its marks, as index lists."""
    out = []
    for i, c in enumerate(word):
        if out and (unicodedata.category(c) in ('Mn', 'Me') or is_annotation(c)):
            out[-1].append(i)
        else:
            out.append([i])
    return out


def char_rules(reader_word, token, rule_of):
    """Rule per character of the muṣḥaf token (None = plain), mapped from
    the reader word's per-character rules; None if they can't be aligned."""
    if len(reader_word) == len(token):
        return list(rule_of)
    rc, tc = clusters(reader_word), clusters(token)
    if len(rc) != len(tc):
        return None
    out = [None] * len(token)
    for r, t in zip(rc, tc):
        if len(r) == len(t):
            for a, b in zip(r, t):
                out[b] = rule_of[a]
        else:
            base = rule_of[r[0]]
            for b in t:
                out[b] = base
    return out


def justified_lines(cfg, tok, ayah_first, layout, shaper, upem):
    """Each token as the justification set it: its glyphs (char indices
    back in our text — the engine's text has U+034F added around hamzas and
    maddas), its advance, and the gap after it (the engine's spaces); and
    every text line's width in em, per page, for the width table."""
    data = load(cfg['justified'])
    by = {(l['page'], l['line']): l for l in data['lines']}
    tok_glyphs = [None] * len(tok)
    tok_adv = [0] * len(tok)
    tok_gap = [0] * len(tok)
    widths = {}
    for pg, li, st, end in text_lines(layout, ayah_first, len(tok)):
        l = by.get((pg, li))
        if l is None or (l['first'], l['end']) != (st, end):
            sys.exit(f'justified lines: page {pg} line {li} is not ours '
                     '(run tool/mushaf_justify/justify.mts again)')
        text = l['text']
        feats = {int(k): v for k, v in l['features'].items()}
        pos = 0
        for t in range(st, end):
            # Our token in the engine's text (a token may hold a space, as
            # «إِلْ يَاسِينَ»), each adjusted character back to ours.
            orig = tok[t]
            back, i, j = [], 0, pos
            while i < len(orig) or (j < len(text) and text[j] == '\u034f'):
                ch = text[j] if j < len(text) else ''
                if ch == '\u034f' and (i >= len(orig) or orig[i] != ch):
                    back.append(max(i - 1, 0))
                elif i < len(orig) and ch == orig[i]:
                    back.append(i)
                    i += 1
                else:
                    sys.exit(f'justified text differs at token {t}: {text[pos:j + 1]!r} / {orig!r}')
                j += 1
            adj = text[pos:j]
            f = {}
            for c in range(len(adj)):
                for name, val in feats.get(pos + c, []):
                    f.setdefault(name, []).append((c, c + 1, val))
            glyphs, adv = shaper.shape(adj, f)
            tok_glyphs[t] = [(g, x, y, back[c]) for g, x, y, c in glyphs]
            tok_adv[t] = adv
            pos = j + 1  # and the space
        # The spaces as the engine set them (wider beside an āyah's
        # number), narrowed where a line had to be squeezed.
        n = end - st
        gaps = []
        for k in range(n - 1):
            aya = tok[st + k].startswith('۝') or tok[st + k + 1].startswith('۝')
            gaps.append(l['ayaSpacing'] if aya else l['simpleSpacing'])
        total = sum(tok_adv[st:end]) + sum(gaps)
        target = l['measure'] * l['ratio']
        if total > target and gaps:
            cut = (total - target) / len(gaps)
            gaps = [max(0.0, g - cut) for g in gaps]
        for k in range(n):
            tok_gap[st + k] = int(round(gaps[k])) if k < n - 1 else 0
        widths.setdefault(pg, {})[li] = (sum(tok_adv[st:end]) + sum(round(g) for g in gaps)) / upem
    return tok_glyphs, tok_adv, tok_gap, widths


def write_width_table(script, widths, font_name):
    """assets/quran/mushaf_line_em_<script>.json from the justified lines:
    each text line's width in em (0 for header and basmala rows)."""
    path = os.path.join(ROOT, 'assets', 'quran', f'mushaf_line_em_{script}.json')
    old = load(f'assets/quran/mushaf_line_em_{script}.json')
    pages = {}
    for pg, rows in old['pages'].items():
        got = widths.get(int(pg), {})
        pages[pg] = [round(got.get(i, 0.0), 3) for i in range(len(rows))]
    with open(path, 'w') as f:
        json.dump({'font': font_name, 'refPx': old.get('refPx', 44), 'pages': pages}, f,
                  separators=(',', ':'))
    print(f'  wrote {path}')


def build(script, cfg):
    font_path = cfg.get('font_path') or os.path.join(ROOT, 'assets', 'fonts', cfg['font'])
    text = load(f"assets/quran/{cfg['text']}")
    layout = load(f"assets/quran/{cfg['layout']}")
    tok, ayah_first, tok_ayah = tokenize(text)
    shaper = Shaper(font_path)
    upem = shaper.upem

    # Each line is shaped whole, as Flutter shapes it: DigitalKhatt adjusts
    # glyphs across the spaces between words (shaping word by word misses a
    # line by up to 5%). The line is then cut back into its tokens — each
    # token's glyphs relative to its own origin, its advance, and the gap to
    # the next token — and tokens that came out the same share one entry.
    table = load(f'assets/quran/mushaf_line_em_{script}.json')['pages']
    _, space = shaper.shape(' ')
    tok_glyphs = [None] * len(tok)  # [(gid, x, y, char index)]
    tok_adv = [0] * len(tok)
    tok_gap = [0] * len(tok)
    worst = (0, (0, 0, 0, 0))
    off_lines = 0
    justified = bool(cfg.get('justified'))
    if justified:
        tok_glyphs, tok_adv, tok_gap, widths = justified_lines(
            cfg, tok, ayah_first, layout, shaper, upem)
        write_width_table(script, widths, 'DigitalKhatt New Madina (justified)')
    for pg, li, st, end in ([] if justified else text_lines(layout, ayah_first, len(tok))):
        offs, line, p = [], [], 0
        for t in range(st, end):
            offs.append(p)
            line.append(tok[t])
            p += len(tok[t]) + 1
        joined = ' '.join(line)
        glyphs = shaper.shape_line(joined)
        owner = []
        for k, o in enumerate(offs):
            owner.extend([k] * len(line[k]))
            owner.append(-1)  # the space after it
        pen = 0
        spans = {}  # token k -> (start pen, end pen, glyphs)
        for gid, cl, xo, yo, xa in glyphs:
            k = owner[cl]
            if k >= 0:
                a, b, gl = spans.get(k, (pen, pen, []))
                gl.append((gid, pen + xo, yo, cl - offs[k]))
                spans[k] = (min(a, pen), max(b, pen + xa), gl)
            pen += xa
        n = end - st
        for k in range(n):
            a, b, gl = spans[k]
            tok_glyphs[st + k] = [(g, x - a, y, c) for g, x, y, c in gl]
            tok_adv[st + k] = b - a
            # Right to left: the next token sits to the left of this one.
            tok_gap[st + k] = (a - spans[k + 1][1]) if k + 1 < n else 0
        em = pen / upem
        ref = table[str(pg)][li]
        dev = abs(em - ref) / ref
        if dev > 0.001:
            off_lines += 1
        if dev > worst[0]:
            worst = (dev, (pg, li, em, ref))
    print(f'  lines off Flutter\'s width by over 0.1%: {off_lines}; widest '
          f'{worst[0] * 100:.3f}% (page {worst[1][0]} line {worst[1][1]})')
    # A stray line or two is harmless (lines are justified to the page with
    # these advances anyway); many mean the shaping went wrong.
    if off_lines > 10 or worst[0] > 0.02:
        sys.exit(f'{script}: shaping disagrees with Flutter')

    circle, parts = marker_parts(font_path)
    check_markers(script, font_path, upem, circle, parts)
    print(f'  markers composed: {compose_markers(tok_glyphs, circle, parts)}')

    variants = {}
    tok_word = []
    for t in range(len(tok)):
        key = (tok_adv[t], tuple((g, x, y) for g, x, y, _ in tok_glyphs[t]))
        tok_word.append(variants.setdefault(key, len(variants)))
    shaped = [None] * len(variants)
    for t, w in enumerate(tok_word):
        if shaped[w] is None:
            shaped[w] = (tok_glyphs[t], tok_adv[t])
    words = shaped
    print(f'{script}: {len(tok)} tokens, {len(words)} distinct shapes, '
          f'space {space}')

    # ── glyphs, most used first ──
    use = Counter()
    for t in range(len(tok)):
        for g in tok_glyphs[t]:
            use[g[0]] += 1
    order = [g for g, _ in use.most_common()]
    atlas_index = {g: i for i, g in enumerate(order)}

    # ── tajwīd: rule per glyph, per token ──
    meta = load('assets/quran/meta.json')
    tj = [[] for _ in tok]
    stats = Counter()
    g = 0
    for s, m in enumerate(meta, start=1):
        reader = load(f"assets/quran/{cfg['reader']}/{s}.json")
        rules = load(f"assets/quran/{cfg['tajwid']}/{s}.json")
        for ai in range(m['ayahs']):
            ayah, spans = reader[ai], rules[ai]
            rule_at = [None] * len(ayah)
            for a, b, r in spans['s']:
                for c in range(a, min(b, len(ayah))):
                    rule_at[c] = r
            wr = reader_word_ranges(ayah)
            dominant = spans.get('w') or []
            toks = [t for t in range(ayah_first[g], ayah_first[g + 1])
                    if not tok[t].startswith('۝')]
            for k, t in enumerate(toks):
                glyphs = tok_glyphs[t]
                if k < len(wr) and len(wr) == len(toks):
                    a, b = wr[k]
                    per = char_rules(ayah[a:b], tok[t], rule_at[a:b])
                else:
                    per = None
                if per is not None:
                    pairs = [(gi, per[gl[3]]) for gi, gl in enumerate(glyphs)
                             if gl[3] < len(per) and per[gl[3]] is not None]
                    stats['letter'] += 1
                elif k < len(dominant) and dominant[k] >= 0:
                    pairs = [(gi, dominant[k]) for gi in range(len(glyphs))]
                    stats['word'] += 1
                else:
                    pairs = []
                    stats['none'] += 1
                tj[t] = [(gi, r) for gi, r in pairs if gi < 256 and r < 255]
            g += 1
    print(f'  tajwīd: {stats["letter"]} words letter by letter, '
          f'{stats["word"]} by word, {stats["none"]} unmapped')

    # ── sheets per tier ── (old sheets go first: a tier that now fits on
    # fewer sheets must not leave its last ones behind in the assets)
    for name in os.listdir(OUT):
        if name.startswith(f'{script}_') and name.endswith('.png'):
            os.remove(os.path.join(OUT, name))
    tiers = []
    for em in TIERS:
        bms = rasterise(font_path, order, em)
        place, sheets = pack(order, bms)
        tiers.append((em, place, sheets, bms))
        total = 0
        for n, img in enumerate(sheets):
            la = np.stack([np.full_like(img, 255), img], axis=-1)
            path = os.path.join(OUT, f'{script}_{em}_{n}.png')
            Image.fromarray(la, 'LA').save(path, optimize=True)
            total += os.path.getsize(path)
        print(f'  E{em}: {len(sheets)} sheets '
              f'{[f"{s.shape[1]}x{s.shape[0]}" for s in sheets]}, '
              f'{total / 1e6:.2f} MB')

    # ── the byte file ──
    hhea_asc, hhea_desc = ascender_descender(font_path)
    out = bytearray()

    def align():
        while len(out) % 4:
            out.append(0)

    out += b'MQA1'
    # Version 3: the lines are justified already (the app only centres them).
    out += struct.pack('<HHhhH', 3 if justified else FORMAT_VERSION, upem,
                       hhea_asc, hhea_desc, space)
    out += struct.pack('<III', len(tok), fnv1a(tok), len(order))
    out += struct.pack('<I', len(words))
    out += struct.pack('<B', len(tiers))
    for em, place, sheets, _ in tiers:
        out += struct.pack('<HB', em, len(sheets))
        for img in sheets:
            out += struct.pack('<HH', img.shape[1], img.shape[0])
    for em, place, sheets, bms in tiers:
        align()
        rows = []
        for key in order:
            if key in place:
                si, x, y, w, h = place[key]
                _, left, top = bms[key]
                rows.append((si, x, y, w, h, left, top))
            else:
                rows.append((255, 0, 0, 0, 0, 0, 0))  # blank (no ink)
        out += np.array([r[0] for r in rows], '<u1').tobytes()
        align()
        for col in range(1, 5):
            out += np.array([r[col] for r in rows], '<u2').tobytes()
            align()
        for col in (5, 6):
            out += np.array([r[col] for r in rows], '<i2').tobytes()
            align()
    # words
    adv = np.array([s[1] for s in shaped], '<u2')
    starts = np.zeros(len(words) + 1, '<u4')
    gids, gx, gy = [], [], []
    for i, (glyphs, _) in enumerate(shaped):
        starts[i] = len(gids)
        for gl in glyphs:
            gids.append(atlas_index[gl[0]])
            gx.append(gl[1])
            gy.append(gl[2])
    starts[-1] = len(gids)
    align()
    out += adv.tobytes()
    align()
    out += starts.tobytes()
    out += struct.pack('<I', len(gids))
    out += np.array(gids, '<u2').tobytes()
    align()
    out += np.array(gx, '<i2').tobytes()
    align()
    out += np.array(gy, '<i2').tobytes()
    align()
    out += np.array(tok_word, '<u2').tobytes()
    align()
    out += np.array(tok_gap, '<i2').tobytes()
    align()
    tj_start = np.zeros(len(tok) + 1, '<u4')
    pairs = []
    for i, p in enumerate(tj):
        tj_start[i] = len(pairs)
        pairs.extend(p)
    tj_start[-1] = len(pairs)
    out += tj_start.tobytes()
    out += np.array([v for p in pairs for v in p], '<u1').tobytes()
    with open(os.path.join(OUT, f'{script}.bin'), 'wb') as f:
        f.write(out)
    print(f'  {script}.bin: {len(out) / 1e6:.2f} MB')


def ascender_descender(font_path):
    from fontTools.ttLib import TTFont
    t = TTFont(font_path)
    return t['hhea'].ascent, t['hhea'].descent


def main():
    os.makedirs(OUT, exist_ok=True)
    for script, cfg in SCRIPTS.items():
        build(script, cfg)


if __name__ == '__main__':
    main()
