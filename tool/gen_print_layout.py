"""Writes a printed muṣḥaf's layout, from its atlas and its source SVGs:

  assets/quran/mushaf_<o|n>_layout.json  pages and lines, the format of
                                         mushaf_u_layout.json (same text and tokens)
  assets/quran/<old|new>_madani/pages.json  what drawing a page needs beyond
                                         the manifest (see OriginalPages in
                                         lib/data/original/original_atlas.dart),
                                         and the edition it is, so one print's
                                         folder can't be taken for the other's

    python3 tool/gen_print_layout.py old
    python3 tool/gen_print_layout.py new

Old Madani needs assets/quran/old_madani/high/ and
docs/old_madani_svgs_with_fixed_ids.zip (docs/<page>.svg, a corrected page
over the zip's: 158, where 7:58 had lost its لَا; 404, where a waqf of 29:66
was labelled 29:65). New Madani (QPC V2) needs assets/quran/new_madani/high/
and docs/new_madani/new_madani_vector.zip.
Stops if a word is missing, lines run out of reading order, or the SVG and
the manifest disagree.

SVG ids: s surah · v verse · w word · E āyah end · qf waqf · rH…P rubʿ-ḥizb
point (۞) · d…P / d…LN sajdah point and line · BR border · NM name · BM basmala;
rH and j name the word's rubʿ and juzʼ.
"""
import json
import os
import re
import statistics
import sys
import struct
import zipfile
from collections import defaultdict

# Per edition: its id in the app, files, the high tier's scale and the
# distance between lines there (from the āyah frames: the median over pages
# of first-to-last frame ÷ lines between).
EDITIONS = {
    'old': dict(id='oldmadani', root='assets/quran/old_madani',
                svgs='docs/old_madani_svgs_with_fixed_ids.zip',
                prefix='old_madani_svgs_with_fixed_ids/', fixed='docs',
                layout='assets/quran/mushaf_o_layout.json', px=16, pitch=212.08),
    'new': dict(id='newmadani', root='assets/quran/new_madani',
                svgs='docs/new_madani/new_madani_vector.zip',
                prefix='new_madani_vector/pages/', fixed=None,
                layout='assets/quran/mushaf_n_layout.json', px=13.6, pitch=205.875),
}
ED = EDITIONS[sys.argv[1] if len(sys.argv) > 1 else 'old']
HIGH = f"{ED['root']}/high/mushaf_manifest.bin"
SVGS = ED['svgs']
PX_PER_MM = ED['px']
PITCH_PX = ED['pitch']
WORD, END, WAQF, S_POINT, S_LINE, HIZB, BORDER, NAME, BASMALA = range(9)
KIND_FRAME = 3


def pack(s, v, t, i):
    return s | v << 7 | t << 16 | i << 20


def unpack(c):
    return c & 0x7F, (c >> 7) & 0x1FF, (c >> 16) & 0xF, (c >> 20) & 0x7FF


# Where the print's words differ from the app's tokens (surah, verse) → each
# print word's token words, first and last, 0-based.
#  - 13:37: بعدما is one word in the print, two tokens.
#  - 37:130: إل ياسين is two words in the print, one token.
#  (New Madani's words are the app's tokens, one for one.)
WORD_MAP = {
    (13, 37): [[i, i] for i in range(7)] + [[7, 8]] + [[i, i] for i in range(9, 20)],
    (37, 130): [[0, 0], [1, 1], [2, 2], [2, 2]],
} if ED['id'] == 'oldmadani' else {}

def read_manifest(path):
    d = open(path, 'rb').read()
    _, _, _, pe, pc, rc, _, sc, se, inst, rec = struct.unpack('<IBBHIIIHHHH', d[:28])
    shared = [struct.unpack('<HHHHBBH', d[32 + i * se:32 + (i + 1) * se]) for i in range(sc)]
    pt = 32 + sc * se
    rs = pt + pc * pe
    ins = rs + rc * rec
    pages = {}
    for i in range(pc):
        fr, rcn, num, _, _, pw, ph, fi, icn, _ = struct.unpack('<IHHHHHHIHH', d[pt + i * pe:pt + (i + 1) * pe])
        recs = [struct.unpack('<IHHHHHH', d[rs + (fr + k) * rec:rs + (fr + k + 1) * rec]) for k in range(rcn)]
        insts = [struct.unpack('<IHHhh', d[ins + (fi + k) * inst:ins + (fi + k + 1) * inst]) for k in range(icn)]
        pages[num] = (pw, ph, recs, insts)
    return shared, pages


def svg_text(z, page):
    """The page's SVG: a corrected page (Old Madani's docs/<page>.svg) over the zip's."""
    fixed = ED['fixed'] and f"{ED['fixed']}/{page}.svg"
    if fixed and os.path.exists(fixed):
        return open(fixed, encoding='utf8', errors='ignore').read()
    return z.read(f"{ED['prefix']}{page}.svg").decode('utf8', 'ignore')


def svg_order(z, page):
    """The page's elements in reading order: (surah, verse, type, index)."""
    s = svg_text(z, page)
    out = []
    for i in re.findall(r'<path[^>]*?\bid="([^"]+)"', s):
        m = re.match(r's(\d+)(?:v(\d+))?(.*)$', i)
        su, ve, rest = int(m[1]), int(m[2] or 0), m[3]
        if rest.startswith('BR'):
            out.append((su, 0, BORDER, 0))
        elif rest.startswith('NM'):
            out.append((su, 0, NAME, 0))
        elif rest.startswith('BM'):
            out.append((su, 0, BASMALA, 0))
        elif rest.startswith('E_'):
            out.append((su, ve, END, 0))
        elif (w := re.match(r'w(\d+)_', rest)):
            out.append((su, ve, WORD, int(w[1])))
        elif (q := re.match(r'qf(\d+)_', rest)):
            out.append((su, ve, WAQF, int(q[1])))
        elif re.match(r'd\d+LN_', rest):
            out.append((su, ve, S_LINE, 0))
        elif re.match(r'd\d+P_', rest):
            out.append((su, ve, S_POINT, 0))
        elif re.match(r'_rH\d+Pj', rest):
            out.append((su, ve, HIZB, 0))
        else:
            raise SystemExit(f'p.{page}: unknown id {i}')
    return out


def main():
    meta = json.load(open('assets/quran/meta.json'))
    text = json.load(open('assets/quran/mushaf_u_text.json'))
    tokens = [[t for t in a.split('‌') if t] for a in text]
    first_ayah = {}
    g = 0
    for m in meta:
        for a in range(1, m['ayahs'] + 1):
            first_ayah[(m['n'], a)] = g
            g += 1
    # Each āyah's words that carry a waqf sign in the text (token indices).
    waqf_re = re.compile('[\u06D6-\u06DC]')
    text_waqf = {}
    for (su, ve), g in first_ayah.items():
        signed = [i for i, w in enumerate(tokens[g][:-1]) if waqf_re.search(w)]
        if signed:
            text_waqf[(su, ve)] = signed
    checked = agreed = by_geometry = 0
    shared, pages = read_manifest(HIGH)
    frame = next(s for s in shared if s[4] == KIND_FRAME)
    z = zipfile.ZipFile(SVGS)
    # How many waqf signs the print has in each āyah.
    print_waqf = defaultdict(int)
    for p in range(1, len(pages) + 1):
        for su, ve, t, i in svg_order(z, p):
            if t == WAQF:
                print_waqf[(su, ve)] += 1

    def words_of(su, ve, idx):
        return WORD_MAP[(su, ve)][idx - 1] if (su, ve) in WORD_MAP else [idx - 1, idx - 1]

    layout, page_geo, attach = [], {}, {}
    open_rows = {}
    block_w = 0.0
    fixes = 0
    for p in range(1, len(pages) + 1):
        pw, ph, recs, insts = pages[p]
        sprites = {}
        for r in recs:
            sprites[unpack(r[0])] = (r[1], r[2], r[3], r[4])
        for i in insts:
            s = shared[i[1]]
            k = i[2] / 32768
            key = unpack(i[0])
            box = (i[3] / 4, i[4] / 4, s[2] * k, s[3] * k)
            old = sprites.get(key)
            if old is None:
                sprites[key] = box
            else:  # a marker: its frame and digits
                x0, y0 = min(old[0], box[0]), min(old[1], box[1])
                x1 = max(old[0] + old[2], box[0] + box[2])
                y1 = max(old[1] + old[3], box[1] + box[3])
                sprites[key] = (x0, y0, x1 - x0, y1 - y0)
        order = svg_order(z, p)
        seen = set(order)
        if seen != set(sprites):
            raise SystemExit(f'p.{p}: SVG and manifest differ: {sorted(seen ^ set(sprites))[:8]}')

        cy = lambda k: sprites[k][1] + sprites[k][3] / 2
        word_keys = [k for k in order if k[2] == WORD]
        x0 = min(sprites[k][0] for k in word_keys)
        x1 = max(sprites[k][0] + sprites[k][2] for k in word_keys)
        block_w = max(block_w, x1 - x0)
        cx = (x0 + x1) / 2

        if p <= 2:
            # The opening pages: their own rows.
            ys = sorted(cy(k) for k in word_keys)
            groups = [[ys[0]]]
            for y in ys[1:]:
                (groups.append([y]) if y - groups[-1][-1] > 5 * PX_PER_MM else groups[-1].append(y))
            centres = [statistics.median(g) for g in groups]
            head = [k for k in order if k[2] in (BORDER, BASMALA)]
            centres = sorted(centres + [cy(k) for k in head])
            open_rows[str(p)] = [round(c / PX_PER_MM, 3) for c in centres]
            row_of = lambda k: min(range(len(centres)), key=lambda i: abs(centres[i] - cy(k)))
            y0 = centres[0]
        else:
            ends = [(i[4] / 4 + frame[3] * i[2] / 32768 / 2) for i in insts if shared[i[1]][4] == KIND_FRAME]
            y0 = statistics.median(y % PITCH_PX for y in ends)
            row_of = lambda k: round((cy(k) - y0) / PITCH_PX)
        page_geo[str(p)] = [round(cx / PX_PER_MM, 3), round(y0 / PX_PER_MM, 3)]

        # Lines from reading order, kept in order: a tall word's centre can
        # stray toward the next line; the āyah frames can't.
        seq = [k for k in order if k[2] in (WORD, END)]
        rows = [row_of(k) for k in seq]
        for i in range(len(seq)):
            before = max(rows[:i], default=0)
            if rows[i] < before:
                rows[i] = before
                fixes += 1
        # A stray up: its neighbours after it say so.
        for i in range(len(seq) - 2, -1, -1):
            if rows[i] > rows[i + 1]:
                rows[i] = rows[i + 1]
                fixes += 1
        first_on = {}
        for k, r in zip(seq, rows):
            first_on.setdefault(r, k)
        row_items = {}
        for r, (su, ve, t, i) in first_on.items():
            a = first_ayah[(su, ve)]
            w = len(tokens[a]) - 1 if t == END else words_of(su, ve, i)[0]
            row_items[r] = [a, w]
        for k in order:
            if k[2] == BORDER:
                r = row_of(k)
                if r in row_items:
                    raise SystemExit(f'p.{p}: header on line {r} with text')
                row_items[r] = [-1, 1 - k[0]]
            elif k[2] == BASMALA:
                r = row_of(k)
                if r in row_items:
                    raise SystemExit(f'p.{p}: basmala on line {r} with text')
                row_items[r] = [-1, -999]
        layout.append([row_items[r] for r in sorted(row_items)])

        # Each sign's word. ۞ the āyah's first; a sajdah's, the word before it
        # in reading order; a waqf sign, the word it stands over or nearest it
        # (where one sits on the page: 8% come out of order in the SVG).
        last = {}
        for k in order:
            su, ve, t, i = k
            if t == WORD:
                last[(su, ve)] = words_of(su, ve, i)[1]
            elif t == HIZB:
                attach[pack(*k)] = 0
            elif t in (S_POINT, S_LINE):
                attach[pack(*k)] = last[(su, ve)]
            elif t == WAQF:
                # The text carries each waqf sign on its word: the print's
                # n-th sign of an āyah is on the text's n-th signed word,
                # where they have as many. Else (the old print has signs of
                # its own) by where it stands: over its word's end — its
                # left edge, right to left — on its own line.
                mid = sprites[k][0] + sprites[k][2] / 2

                def away(q):
                    x = sprites[q][0]
                    dy = abs(cy(q) - cy(k))
                    return (dy > PITCH_PX * .6, abs(mid - x), dy)

                near = min((q for q in word_keys if q[:2] == (su, ve)), key=away)
                by_place = words_of(su, ve, near[3])[0]
                signed = text_waqf.get((su, ve), [])
                if len(signed) == print_waqf[(su, ve)]:
                    attach[pack(*k)] = signed[i - 1]
                    checked += 1
                    agreed += by_place == signed[i - 1]
                else:
                    attach[pack(*k)] = by_place
                    by_geometry += 1

    # Every token on exactly one line: starts only ever move forward.
    ayah_first = []
    n = 0
    for t in tokens:
        ayah_first.append(n)
        n += len(t)
    starts = [ayah_first[a] + w for pg in layout for a, w in pg if a >= 0]
    bad = [i for i in range(1, len(starts)) if starts[i] <= starts[i - 1]]
    if starts[0] != 0 or bad:
        raise SystemExit(f'lines out of order at {bad[:8]}')

    json.dump(layout, open(ED['layout'], 'w'), separators=(',', ':'))
    json.dump({
        'edition': ED['id'],
        'pitch': PITCH_PX / PX_PER_MM,
        'blockW': round(block_w / PX_PER_MM, 3),
        'pages': page_geo,
        'rows': open_rows,
        'attach': {str(k): v for k, v in attach.items()},
        'words': {str(first_ayah[k]): v for k, v in WORD_MAP.items()},
    }, open(f"{ED['root']}/pages.json", 'w'), separators=(',', ':'))
    print(f'waqf signs: {checked} by the text ({agreed} where they stand agrees), '
          f'{by_geometry} by where they stand')
    lines = defaultdict(int)
    for pg in layout:
        lines[len(pg)] += 1
    print(f'{len(layout)} pages; lines per page {dict(sorted(lines.items()))}; '
          f'{fixes} rows kept in order; {len(attach)} signs; block {block_w:.0f} px')

    # The ids name each word's rubʿ: does the app's table agree?
    rubs = {}
    for p in range(1, len(pages) + 1):
        s = svg_text(z, p)
        for su, ve, q in re.findall(r'id="s(\d+)v(\d+)w\d+_rH(\d+)j', s):
            rubs.setdefault(int(q), (int(su), int(ve)))
    table = open('lib/data/divisions_data.dart', encoding='utf8').read()
    m = re.search(r'rubStarts[^=]*=\s*(?:<[^>]*>)?\[(.*?)\];', table, re.S)
    if m:
        ours = [(int(a), int(b)) for a, b in re.findall(r'\((\d+),\s*(\d+)\)', m[1])]
        diff = [(i + 1, ours[i], rubs.get(i + 1)) for i in range(len(ours)) if ours[i] != rubs.get(i + 1)]
        print(f'rubʿ starts differing from divisions_data.dart: {len(diff)} {diff[:10]}')


main()
