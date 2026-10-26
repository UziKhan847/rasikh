"""A sample Nabr page, as a PDF: a legend, a muṣḥaf page coloured by stress,
and the attribution — to see how Nabr colouring looks before the engine
exists.

    tool/mushaf_atlas/.venv/bin/python tool/nabr/sample_pdf.py [page]

The page is set as the justification prototype sets it (DigitalKhatt New
Madina, digitalkhatt.org's kashīdas; tool/mushaf_justify/out/lines.json).
Its stresses are a **demonstration**, not the engine's output:
- the words the book itself answers (Practice set C, Sūrat ʿAbasa) take the
  book's answers, exactly;
- every other word gets a rough first pass of the main rules, from the text
  alone (no morphology): the first root letter or the second (G1), the
  letter after a medial sukūn (G2), and the strong stress on a doubled
  letter after a long vowel / before a doubled wāw or yāʾ (P3) — with the
  rule that no two stressed letters touch.
Writes build/nabr/nabr_sample_p<page>.pdf (and the PNG pages next to it).
"""

import json
import os
import sys

import freetype
import numpy as np
import uharfbuzz as hb
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
OUT = os.path.join(ROOT, 'build', 'nabr')
FONTSIZE = 1000
PX = 64  # px per em on the page (A4 at about 150 dpi)
PAGE_W, PAGE_H = 1240, 1754  # A4 at 150 dpi

# ── text: letters and their marks ──
FATHA, DAMMA, KASRA, SUKUN, SHADDA = 'َ', 'ُ', 'ِ', 'ْ', 'ّ'
TANWIN = set('ًࣰٌࣱٍࣲ')
VOWELS = {FATHA, DAMMA, KASRA} | TANWIN
ZERO = set('۟۠')
HAMZA_MARKS = set('ٕٔ')
LONG = set('ٰۥۦ')  # dagger alif, small wāw / yāʾ: a long vowel
SUN = set('تثدذرزسشصضطظلن')


def is_base(c):
    o = ord(c)
    return 0x0621 <= o <= 0x063A or 0x0641 <= o <= 0x064A or c in 'ٱـ'


def letters(word):
    """The word's written letters: (start, end, base, marks)."""
    out = []
    for i, c in enumerate(word):
        if is_base(c):
            out.append([i, i + 1, c, ''])
        elif out:
            out[-1][1] = i + 1
            out[-1][3] += c
    # A tatweel carrying a hamza is the hamza's seat.
    return [l for l in out if not (l[2] == 'ـ' and not (set(l[3]) & HAMZA_MARKS))]


def units(word, pause):
    """Pronounced units, in reading: dicts with the letter's character range,
    whether it's voweled or silent (sukūn, or a long vowel), a prefix, or
    one half of a doubled letter."""
    ls = letters(word)
    us = []
    for k, (s, e, b, m) in enumerate(ls):
        ms = set(m)
        if ms & ZERO or b == 'ٱ':
            continue  # not pronounced (zero mark, alif waṣla)
        hamza = b == 'ء' or bool(ms & HAMZA_MARKS)
        nxt = ls[k + 1] if k + 1 < len(ls) else None
        # The article's lām before a sun letter is assimilated.
        if b == 'ل' and not (ms & (VOWELS | {SUKUN, SHADDA})) and k > 0 and ls[k - 1][2] == 'ٱ' \
                and nxt and SHADDA in nxt[3]:
            continue
        voweled = bool(ms & VOWELS)
        long_ = not hamza and b in 'اويى' and not voweled and SUKUN not in ms and SHADDA not in ms
        base = dict(s=s, e=e, b='ء' if hamza else b, prefix=False, half=0)
        if SHADDA in ms:
            us.append({**base, 'v': False, 'half': 1})
            us.append({**base, 'v': voweled, 'half': 2})
        elif long_:
            us.append({**base, 'v': False, 'long': True})
        else:
            us.append({**base, 'v': voweled})
        for c in m:
            if c in LONG:
                i = s + m.index(c) + (e - s - len(m))
                us.append(dict(s=i, e=i + 1, b='ā', v=False, long=True, prefix=False, half=0))
        if ms & TANWIN:
            us.append(dict(s=e - 1, e=e, b='n', v=False, prefix=False, half=0, silentN=True))
    # Prefixes: the article (ٱلْ…, its lām or the assimilated half), and a
    # conjunction / preposition letter starting a longer word.
    if word.startswith('ٱل') or word.startswith('ٱل'):
        for u in us:
            if u['b'] == 'ل' and not u['v'] and u['half'] == 0:
                u['prefix'] = True
                break
            if u['half'] == 1:
                u['prefix'] = True
                break
    first = ls[0] if ls else None
    if first and first[2] in 'وفبلك' and set(first[3]) & {FATHA, KASRA} and SHADDA not in first[3] \
            and len(us) >= 4:
        us[0]['prefix'] = True
    if pause and us:
        # At a pause: tanwīn's nūn goes, the final vowel goes.
        while us and us[-1].get('silentN'):
            us.pop()
        if us and us[-1]['v']:
            us[-1]['v'] = False
    return us


def draft(word, pause):
    """A first pass of the main rules: {unit index: level}. Natural
    stresses (before a sukūn) are left out, as the muṣḥaf hides them."""
    U = units(word, pause)
    n = len(U)
    cand = []  # (priority, index, level)
    roots = [i for i, u in enumerate(U) if not u['prefix']]
    if roots:
        R = roots[0]
        if R + 1 < n and not U[R + 1]['v']:
            pass  # natural stress on U[R]: hidden
        elif R + 2 < n - 1 and not U[R + 2]['v']:
            cand.append((3, R + 1, 'medium'))
        else:
            cand.append((3, R, 'medium'))
    for i in range(n - 2):  # G2: after a medial sukūn
        if not U[i]['v'] and not U[i].get('long') and not U[i]['prefix'] and U[i + 1]['v']:
            cand.append((2, i + 1, 'medium'))
    for i in range(n - 2):  # P3
        if U[i].get('long') and U[i + 1]['half'] == 1 and U[i + 1]['b'] not in 'من':
            cand.append((0, i + 2, 'strong'))
        if U[i + 1]['half'] == 1 and U[i + 1]['b'] in 'وي' and U[i]['v']:
            cand.append((0, i, 'strong'))
    chosen = {}
    for _, i, lv in sorted(cand):
        if i in chosen or not U[i]['v'] and U[i]['half'] != 2:
            continue
        if any(abs(i - j) == 1 for j in chosen):
            continue
        chosen[i] = lv
    return {(U[i]['s'], U[i]['e']): lv for i, lv in chosen.items()}


def book_overrides(words):
    """The book's own answers (Practice set C) for the words they cover:
    {word index: {(start, end): 'medium'}}."""
    c = json.load(open(os.path.join(ROOT, 'assets', 'nabr', 'nabr_content.json'), encoding='utf-8'))
    answers = [a for p in c['lessons'] for ch in p['chapters'] for b in ch['blocks']
               if b['type'] == 'practice' and b['set'] == 'C' for a in b['answers']]

    def bases(w):
        return [l for l in letters(w)]

    def skel(w):
        t = ''
        for (_, _, b, m) in bases(w):
            t += 'ء' if b == 'ء' or set(m) & HAMZA_MARKS else ('ا' if b == 'ٱ' else b)
        return t.replace('أ', 'ء').replace('إ', 'ء')

    out = {}
    plain = [skel(w) for w in words]
    for a in answers:
        toks, stressed = a['tokens'], set(a['stressedTokenIndices'])
        parts, cur, idx = [], [], 0
        for k, t in enumerate(toks):
            if t == 'ـ':
                parts.append(cur)
                cur = []
            else:
                cur.append(k)
        parts.append(cur)
        phrase = [''.join(('ء' if ch in 'أإؤئء' else ch) for t in [toks[k] for k in p]
                          for ch in t if is_base(ch) or ch in 'أإؤئ') for p in parts]
        for wi in range(len(words) - len(parts) + 1):
            if all(plain[wi + j] == phrase[j] for j in range(len(parts))):
                for j, p in enumerate(parts):
                    ls = bases(words[wi + j])
                    spans = {}
                    for pos, k in enumerate(p):
                        if k in stressed and pos < len(ls):
                            spans[(ls[pos][0], ls[pos][1])] = 'medium'
                    out[wi + j] = spans
                break
    return out


def book_words():
    """Every word the book answers (examples, drills, tests): its skeleton
    → (tokens, stressed token indices) — single words only."""
    c = json.load(open(os.path.join(ROOT, 'assets', 'nabr', 'nabr_content.json'), encoding='utf-8'))
    g = json.load(open(os.path.join(ROOT, 'tool', 'nabr', 'nabr_golden_tests.json'), encoding='utf-8'))
    found = {}

    def add(word, toks, stressed):
        if 'ـ' not in toks and ' ' not in word.strip():
            found.setdefault(word.strip(), (toks, set(stressed)))
    for p in c['lessons']:
        for ch in p['chapters']:
            for b in ch['blocks']:
                for e in b.get('items', []) + b.get('answers', []):
                    if isinstance(e, dict) and 'tokens' in e:
                        add(e['word'], e['tokens'], e['stressedTokenIndices'])
    for d in c['drills']:
        add(d['word'], d['tokens'], d['correct'])
    for t in g['tests']:
        add(t['text'], t['tokens'], t['expectedStressedTokenIndices'])
    return found


def skeleton(w):
    """[w]'s written letters only (hamza forms as one)."""
    return ''.join('ء' if b == 'ء' or set(m) & HAMZA_MARKS or b in 'أإؤئ' else
                   ('ا' if b == '\u0671' else b) for _, _, b, m in letters(w))


def example_spans(phrase, known):
    """The stressed letters of a guide example: the book's answer for each
    word where it has one (matched by letters), else the draft rules."""
    by_skel = {skeleton(k): v for k, v in known.items()}
    spans, pos = set(), 0
    for w in phrase.split(' '):
        hit = known.get(w) or by_skel.get(skeleton(w))
        if hit:
            ls = letters(w)
            spans |= {(pos + ls[k][0], pos + ls[k][1]) for k in hit[1] if k < len(ls)}
        else:
            spans |= {(pos + s, pos + e) for (s, e) in draft(w, pause=False)}
        pos += len(w) + 1
    return spans


# ── drawing ──
class Font:
    def __init__(self, path, px=PX):
        self.face = hb.Face(hb.Blob.from_file_path(path))
        self.font = hb.Font(self.face)
        self.upem = self.face.upem
        self.ft = freetype.Face(path)
        self.ft.set_char_size(int(px * 64))
        self.px = px
        self.cache = {}

    def shape(self, text, features=None):
        buf = hb.Buffer()
        buf.add_str(text)
        buf.guess_segment_properties()
        buf.cluster_level = hb.BufferClusterLevel.MONOTONE_CHARACTERS
        hb.shape(self.font, buf, features or {})
        return [(i.codepoint, i.cluster, p.x_advance, p.x_offset, p.y_offset)
                for i, p in zip(buf.glyph_infos, buf.glyph_positions)]

    def bitmap(self, gid):
        if gid not in self.cache:
            self.ft.load_glyph(gid, freetype.FT_LOAD_DEFAULT | freetype.FT_LOAD_NO_HINTING)
            self.ft.glyph.render(freetype.FT_RENDER_MODE_NORMAL)
            b = self.ft.glyph.bitmap
            arr = np.array(b.buffer, dtype=np.float32).reshape(b.rows, b.width) / 255 if b.rows else None
            self.cache[gid] = (arr, self.ft.glyph.bitmap_left, self.ft.glyph.bitmap_top)
        return self.cache[gid]

    def width(self, glyphs, sx=1.0):
        return sum(g[2] for g in glyphs) * sx / self.upem * self.px

    def draw(self, canvas, glyphs, x_right, base, colour_of=lambda cl: (0, 0, 0), sx=1.0):
        """Draws [glyphs] ending at x_right, each in colour_of(its cluster)."""
        h, w, _ = canvas.shape
        x = x_right - self.width(glyphs, sx)
        for gid, cl, adv, xo, yo in glyphs:
            arr, left, top = self.bitmap(gid)
            if arr is not None:
                px = int(round(x + xo * sx / self.upem * self.px)) + left
                py = base - int(round(yo / self.upem * self.px)) - top
                hh, ww = arr.shape
                y0, x0, y1, x1 = max(py, 0), max(px, 0), min(py + hh, h), min(px + ww, w)
                if y1 > y0 and x1 > x0:
                    a = arr[y0 - py:y1 - py, x0 - px:x1 - px, None]
                    canvas[y0:y1, x0:x1] = canvas[y0:y1, x0:x1] * (1 - a) + np.array(colour_of(cl)) * a
            x += adv * sx / self.upem * self.px


def hexrgb(h):
    return tuple(int(h[i:i + 2], 16) for i in (1, 3, 5))


def mushaf_page(page, levels):
    data = json.load(open(os.path.join(ROOT, 'tool', 'mushaf_justify', 'out', 'lines.json'), encoding='utf-8'))
    lines = [l for l in data['lines'] if l['page'] == page]
    measure = max(l['measure'] for l in lines)
    scale = (PAGE_W - 220) / (measure / FONTSIZE * PX)  # fit the text block
    font = Font(os.path.join(ROOT, 'tool', 'mushaf_justify', 'fonts', 'madina.otf'), PX * scale)
    px = font.px
    canvas = np.full((PAGE_H, PAGE_W, 3), 255.0)
    ink = (29, 36, 32)
    words_all = [w for l in lines for w in l['text'].split(' ')]
    book = book_overrides(words_all)
    pitch = 1.9 * px
    top = 150
    left = (PAGE_W - measure / FONTSIZE * px) / 2
    right_edge = left + measure / FONTSIZE * px
    counts = {'book': 0, 'draft': 0}
    wi = 0
    for l in lines:
        words = l['text'].split(' ')
        base = int(top + (l['line'] + 0.7) * pitch)
        target = measure * l['ratio'] / FONTSIZE * px
        x = right_edge - (measure / FONTSIZE * px - target) / 2
        pos = 0
        for k, w in enumerate(words):
            f = {}
            for key, v in l['features'].items():
                i = int(key)
                if pos <= i < pos + len(w):
                    for name, val in v:
                        f.setdefault(name, []).append((i - pos, i - pos + 1, val))
            g = font.shape(w, f)
            marker = w.startswith('۝')
            nxt_marker = k + 1 < len(words) and words[k + 1].startswith('۝')
            if marker:
                spans = {}
            elif wi in book:
                spans, counts['book'] = book[wi], counts['book'] + 1
            else:
                spans = draft(w, pause=nxt_marker)
                counts['draft'] += 1 if spans else 0

            def colour_of(cl, spans=spans):
                for (s, e), lv in spans.items():
                    if s <= cl < e:
                        return levels[lv]
                return ink
            font.draw(canvas, g, x, base, colour_of, l['xScale'])
            x -= font.width(g, l['xScale'])
            if k + 1 < len(words):
                aya = marker or nxt_marker
                x -= (l['ayaSpacing'] if aya else l['simpleSpacing']) / FONTSIZE * px
            pos += len(w) + 1
            wi += 1
    img = Image.fromarray(canvas.clip(0, 255).astype(np.uint8))
    d = ImageDraw.Draw(img)
    # The frame and the sūrah header row.
    d.rectangle([left - 30, top - 30, right_edge + 30, top + 15 * pitch + 20], outline=(180, 134, 44), width=3)
    d.rectangle([left - 22, top - 22, right_edge + 22, top + 15 * pitch + 12], outline=(180, 134, 44), width=1)
    header = Font(os.path.join(ROOT, 'tool', 'mushaf_justify', 'fonts', 'madina.otf'), px * .8)
    hdr_y0, hdr_y1 = top + .15 * pitch, top + .95 * pitch
    d.rounded_rectangle([left + 40, hdr_y0, right_edge - 40, hdr_y1], radius=20, outline=(180, 134, 44), width=3)
    arr = np.array(img, dtype=np.float32)
    name = header.shape('سُورَةُ عَبَسَ')
    header.draw(arr, name, PAGE_W / 2 + header.width(name) / 2, int(hdr_y0 + .72 * (hdr_y1 - hdr_y0)), lambda c: (15, 110, 88))
    img = Image.fromarray(arr.clip(0, 255).astype(np.uint8))
    d = ImageDraw.Draw(img)
    d.text((PAGE_W / 2, top + 15 * pitch + 60), str(page), fill=(110, 102, 86), anchor='mm', font=ui_font(26))
    return img, counts


def ui_font(size, bold=False):
    name = 'Inter-Bold.ttf' if bold else 'Inter-Regular.ttf'
    return ImageFont.truetype(os.path.join(ROOT, 'assets', 'fonts', name), size)


def ar_text(img, text, x_right, base, size, colour=(29, 36, 32), font='UthmanicHafs.ttf',
            spans=None, ink=(29, 36, 32)):
    """Arabic [text] ending at x_right; with [spans] ({(start, end)}),
    only those characters in [colour], the rest in [ink]."""
    f = Font(os.path.join(ROOT, 'assets', 'fonts', font), size)
    arr = np.array(img, dtype=np.float32)
    g = f.shape(text)
    f.draw(arr, g, x_right, base, lambda c: colour if spans is None or any(
        s <= c < e for s, e in spans) else ink)
    return Image.fromarray(arr.clip(0, 255).astype(np.uint8)), f.width(g)


def legend_page(content, levels):
    img = Image.new('RGB', (PAGE_W, PAGE_H), 'white')
    d = ImageDraw.Draw(img)
    d.text((90, 90), 'Nabr — stress colouring', fill=(15, 110, 88), font=ui_font(48, True))
    img, _ = ar_text(img, 'النبر في القرآن الكريم', PAGE_W - 90, 160, 44, (15, 110, 88), 'NotoNaskhArabic-Regular.ttf')
    d = ImageDraw.Draw(img)
    d.text((90, 210), 'Colour shows how strongly the letter is stressed; tajwīd colours are off.', fill=(75, 84, 79), font=ui_font(24))
    known = book_words()
    y = 300
    for lv in content['colourGuide']['levels']:
        if lv['id'] not in levels:
            continue
        col = levels[lv['id']]
        d.rounded_rectangle([90, y, 150, y + 60], radius=12, fill=col)
        d.text((180, y + 2), lv['en'], fill=(29, 36, 32), font=ui_font(30, True))
        # The description, wrapped to the left half; the Arabic name right.
        words, line, ly = lv['descEn'].split(' '), '', y + 44
        for w in words + ['']:
            if w and d.textlength(line + ' ' + w, font=ui_font(20)) < 640:
                line = (line + ' ' + w).strip()
                continue
            d.text((180, ly), line, fill=(110, 117, 112), font=ui_font(20))
            line, ly = w, ly + 26
        img, _ = ar_text(img, lv['ar'], PAGE_W - 90, y + 95, 34, col, 'NotoNaskhArabic-Regular.ttf')
        # Examples: the stressed letters in the level's colour, where the
        # book says which they are.
        x = PAGE_W - 90
        for ex in lv.get('examples', [])[:4]:
            img, w = ar_text(img, ex, x, y + 175, 40, col, spans=example_spans(ex, known))
            x -= w + 40
        d = ImageDraw.Draw(img)
        y += 230
    for i, t in enumerate([
            "Examples: the book's stressed letters where it gives them; the others are",
            "this demo's rough draft (and may be wrong).",
            'Natural stresses (a letter before a sukūn) are not coloured on the page,',
            'as the reader makes them without effort.']):
        d.text((90, y + 10 + 30 * i), t, fill=(110, 117, 112), font=ui_font(22))
    return img


def credit_page(counts, page):
    img = Image.new('RGB', (PAGE_W, PAGE_H), 'white')
    d = ImageDraw.Draw(img)
    d.text((90, 120), 'About this sample', fill=(15, 110, 88), font=ui_font(40, True))
    lines = [
        'Stress rules after Ṣawn al-Lisān ʿan al-Laḥn fī al-Qurʾān',
        'by Shaykh ʿAlī ʿAbd al-Tawwāb Aḥmad.',
        '',
        f'Page {page} (Sūrat ʿAbasa), DigitalKhatt New Madina, justified with kashīdas',
        "by digitalkhatt.org's engine.",
        '',
        'THIS IS A DEMONSTRATION OF THE COLOURING, NOT THE ENGINE.',
        f"• {counts['book']} words take the book's own answers (Practice set C).",
        f"• {counts['draft']} other words are coloured by a rough first pass of the",
        '  main rules from the text alone (no morphology), and will have errors.',
        '',
        'Automated annotation, reviewed by: ______________________',
    ]
    y = 220
    for t in lines:
        d.text((90, y), t, fill=(29, 36, 32) if not t.startswith('THIS') else (192, 57, 43), font=ui_font(26, t.startswith('THIS')))
        y += 44
    img, _ = ar_text(img, 'صون اللسان عن اللحن في القرآن — الشيخ علي عبد التواب أحمد', PAGE_W - 90, y + 80, 34,
                     (29, 36, 32), 'NotoNaskhArabic-Regular.ttf')
    return img


def main():
    page = int(sys.argv[1]) if len(sys.argv) > 1 else 585
    content = json.load(open(os.path.join(ROOT, 'assets', 'nabr', 'nabr_content.json'), encoding='utf-8'))
    levels = {lv['id']: hexrgb(lv['light']) for lv in content['colourGuide']['levels'] if lv.get('light')}
    os.makedirs(OUT, exist_ok=True)
    legend = legend_page(content, levels)
    mushaf, counts = mushaf_page(page, levels)
    credit = credit_page(counts, page)
    for n, im in [('legend', legend), (f'p{page}', mushaf), ('about', credit)]:
        im.save(os.path.join(OUT, f'nabr_sample_{n}.png'))
    pdf = os.path.join(OUT, f'nabr_sample_p{page}.pdf')
    legend.save(pdf, save_all=True, append_images=[mushaf, credit], resolution=150)
    print(pdf, counts)


if __name__ == '__main__':
    main()
