#!/usr/bin/env python3
"""Reads per-letter ink bounds straight out of a bundled TTF's glyf table.

Why this exists: Flutter's FittedBox centres a Text widget's LINE BOX, not
its ink. UthmanicHafs' natural line (ascent 1.172em + descent 0.586em, from
its own hhea table) leaves headroom for tashkil that a bare isolated letter
never fills, and how much ink sits above vs. below the baseline varies wildly
per letter (kaf reaches +0.68em above it, jim/ha/kha/ayn/ghayn/mim reach
-0.44em below it). No single line box centres all of them — see
kids_letter_flow.dart's _GlyphHero, the only place this table is used.

Usage: python3 tool/glyph_ink_bounds.py assets/fonts/UthmanicHafs.ttf
Prints a Dart map literal for lib/data/glyph_ink.dart. Re-run this and paste
the output over kUthmanicInk if the bundled font is ever replaced.
"""
import struct
import sys

LETTERS = list("ابتثجحخدذرزسشصضطظعغفقكلمنهوي")


def read_tables(f):
    n = struct.unpack('>H', f[4:6])[0]
    tabs = {}
    for i in range(n):
        off = 12 + 16 * i
        tag = f[off:off + 4].decode('latin1')
        o, length = struct.unpack('>II', f[off + 8:off + 16])
        tabs[tag] = (o, length)
    return tabs


def read_cmap(f, tabs):
    co, _ = tabs['cmap']
    ntab = struct.unpack('>H', f[co + 2:co + 4])[0]
    sub = None
    for i in range(ntab):
        _pid, _eid, off = struct.unpack('>HHI', f[co + 4 + 8 * i:co + 12 + 8 * i])
        fmt = struct.unpack('>H', f[co + off:co + off + 2])[0]
        if fmt == 4:
            sub = co + off
    cmap = {}
    if sub is None:
        return cmap
    seg_x2 = struct.unpack('>H', f[sub + 6:sub + 8])[0]
    seg = seg_x2 // 2
    end = struct.unpack('>%dH' % seg, f[sub + 14:sub + 14 + seg_x2])
    st = sub + 16 + seg_x2
    start = struct.unpack('>%dH' % seg, f[st:st + seg_x2])
    dl = st + seg_x2
    delta = struct.unpack('>%dh' % seg, f[dl:dl + seg_x2])
    rl = dl + seg_x2
    rng = struct.unpack('>%dH' % seg, f[rl:rl + seg_x2])
    for i in range(seg):
        for c in range(start[i], min(end[i], 0xFFFF) + 1):
            if rng[i] == 0:
                g = (c + delta[i]) & 0xFFFF
            else:
                gi = rl + 2 * i + rng[i] + 2 * (c - start[i])
                g = struct.unpack('>H', f[gi:gi + 2])[0]
                if g:
                    g = (g + delta[i]) & 0xFFFF
            if g:
                cmap[c] = g
    return cmap


def main():
    path = sys.argv[1] if len(sys.argv) > 1 else 'assets/fonts/UthmanicHafs.ttf'
    f = open(path, 'rb').read()
    tabs = read_tables(f)
    upem = struct.unpack('>H', f[tabs['head'][0] + 18:tabs['head'][0] + 20])[0]

    ho, _ = tabs['head']
    index_to_loc = struct.unpack('>h', f[ho + 50:ho + 52])[0]
    mo, _ = tabs['maxp']
    num_glyphs = struct.unpack('>H', f[mo + 4:mo + 6])[0]
    lo, _ = tabs['loca']
    if index_to_loc == 0:
        loca = [2 * x for x in struct.unpack('>%dH' % (num_glyphs + 1),
                                              f[lo:lo + 2 * (num_glyphs + 1)])]
    else:
        loca = list(struct.unpack('>%dI' % (num_glyphs + 1),
                                   f[lo:lo + 4 * (num_glyphs + 1)]))
    go, _ = tabs['glyf']
    cmap = read_cmap(f, tabs)

    def bbox(gid):
        a, b = loca[gid], loca[gid + 1]
        if a == b:
            return None
        o = go + a
        _nc, xmin, ymin, xmax, ymax = struct.unpack('>hhhhh', f[o:o + 10])
        return xmin, ymin, xmax, ymax

    print("const kUthmanicInk = <String, (double top, double bottom)>{")
    for ch in LETTERS:
        gid = cmap.get(ord(ch))
        bb = bbox(gid) if gid else None
        if not bb:
            print(f"  # WARNING: no outline for {ch!r}", file=sys.stderr)
            continue
        _xmin, ymin, _xmax, ymax = bb
        top = ymax / upem
        bottom = ymin / upem
        print(f"  '{ch}': ({top:.4f}, {bottom:.4f}),")
    print("};")


if __name__ == '__main__':
    main()
