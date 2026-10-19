"""Writes assets/quran/mushaf_page_ratio_uthmani.json: each Madani page's
text block as width / height, starting from the snug-cropped scans in
assets/new_madani_mushaf_svgs/ (one SVG per page, sized to its ink).

DigitalKhatt is not a line-for-line replica of the scanned print: a page's
widest line runs from 13.6 to 21 em. Held to the scan's shape, a page whose
lines are wide gets a small font and loose lines, and one whose lines are
narrow gets its font capped and its gaps stretched. So each page keeps its
scanned shape only as far as its own text sits well in it: the ratio is
clamped so the widest line, filling the width, leaves lines 1.7–1.95 em
apart (assets/quran/mushaf_line_em_uthmani.json gives the widths).

A guard against scans that carry more than the text block (margin leftovers
such as a running head or a hizb note): a page whose width strays more than
3% from the median takes the median of its six neighbours instead, and is
reported.

    python3 tool/gen_mushaf_page_ratios.py
"""
import json
import os
import re
import statistics

SRC = 'assets/new_madani_mushaf_svgs'
OUT = 'assets/quran/mushaf_page_ratio_uthmani.json'

def from_scans():
    size = {}
    for f in os.listdir(SRC):
        if not f.endswith('.svg'):
            continue
        with open(os.path.join(SRC, f), 'rb') as fh:
            head = fh.read(2000).decode('utf8', 'ignore')
        w = float(re.search(r'\swidth="([\d.]+)', head)[1])
        h = float(re.search(r'\sheight="([\d.]+)', head)[1])
        size[int(f[:-4])] = (w, h)
    mw = statistics.median(w for w, _ in size.values())
    ratio = {}
    for p in sorted(size):
        w, h = size[p]
        if abs(w - mw) / mw > .03:
            near = [size[q][0] / size[q][1] for q in range(p - 3, p + 4)
                    if q != p and q in size and abs(size[q][0] - mw) / mw <= .03]
            ratio[p] = statistics.median(near)
            print(f'page {p}: {w:.1f} x {h:.1f} is off the text block; '
                  f'using {ratio[p]:.4f}')
        else:
            ratio[p] = w / h
    return ratio


# The scans are large and live outside the repo; without them, the scanned
# shapes saved in the output's "scan" field are used again.
if os.path.isdir(SRC):
    scan = from_scans()
else:
    prev = json.load(open(OUT))
    scan = {int(k): v for k, v in prev.get('scan', prev['pages']).items()}
    print(f'{SRC} not found: using the scanned shapes saved in {OUT}')
pages = sorted(scan)
ratio = dict(scan)

# Keep DigitalKhatt's lines at a print-like pitch (pages of 15 lines; the
# short opening pages keep their scan shape).
LO, HI = 1.7, 1.95
em = json.load(open('assets/quran/mushaf_line_em_uthmani.json'))['pages']
moved = 0
for p in pages:
    lines = em[str(p)]
    if len(lines) < 15:
        continue
    widest = max(lines)
    lo, hi = widest / (len(lines) * HI), widest / (len(lines) * LO)
    r = min(max(ratio[p], lo), hi)
    if abs(r - ratio[p]) > 1e-4:
        moved += 1
    ratio[p] = r
print(f'{moved} pages reshaped to fit their DigitalKhatt lines')

with open(OUT, 'w') as fh:
    json.dump({'source': SRC,
               'pages': {str(p): round(ratio[p], 4) for p in pages},
               'scan': {str(p): round(scan[p], 4) for p in pages}}, fh,
              separators=(',', ':'))
print(f'wrote {len(pages)} pages to {OUT}')
