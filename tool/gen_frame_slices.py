"""Turns a full-page decorative frame (a PNG of the whole frame) into a
compact nine-slice for the app: its four corners and one repeating edge
tile per side, packed into a small WebP in assets/ornaments/, and prints
the slices for lib/ui/ornaments/page_borders.dart (FrameArt).

The edge motif's period is found by autocorrelation along each band; the
motifs are drawn by hand, so the tile kept is the one (near that period)
that joins onto itself most smoothly, and the run fails if none does.

    python3 tool/gen_frame_slices.py
"""
import numpy as np
from PIL import Image

SRC = 'design_handoff_qiraah_flutter/flutter/assets/ornaments/'
OUT = 'assets/ornaments/'
# The same frame in three colourings: the slices are found on the first and
# used for all.
FRAMES = [('thin_frame_transparent', 'thin_frame_1'),
          ('thin_frame_green_muted', 'thin_frame_2'),
          ('thin_frame_blue_muted', 'thin_frame_3')]


def bbox(a):
    ys, xs = np.nonzero(a[:, :, 3] > 10)
    return xs.min(), ys.min(), xs.max() + 1, ys.max() + 1


def band_width(a):
    """The band's thickness: the opaque run in from the left at mid-height."""
    row = a[a.shape[0] // 2, :, 3] > 10
    return int(np.argmin(row))  # first transparent pixel


def period(strip):
    """The repeat length along a strip (axis 0), by autocorrelation."""
    sig = strip.reshape(strip.shape[0], -1).mean(axis=1)
    sig = sig - sig.mean()
    ac = np.correlate(sig, sig, 'full')[len(sig) - 1:]
    ac /= ac[0]
    peaks = [i for i in range(40, len(sig) // 3)
             if ac[i] > ac[i - 1] and ac[i] > ac[i + 1] and ac[i] > .5]
    return peaks[0]


def diff(a, b):
    return np.abs(a.astype(float) - b.astype(float)).mean()


def cut(edge, p, band):
    """One edge tile to repeat: the motifs are drawn by hand, so not evenly
    spaced; the tile chosen (its start past the corner's band, its length
    near the period) is the one whose end runs on into its own start most
    smoothly — what decides whether the repeat shows a seam. Returns the
    tile's start and length, how many whole tiles the edge held, and the
    seam's mismatch."""
    best = None
    for q in range(p - 3, p + 4):
        for c in range(band, band + 2 * p):
            d = diff(edge[c:c + 3], edge[c + q:c + q + 3])
            if best is None or d < best[2]:
                best = (c, q, d)
    c, q, d = best
    return c, q, (len(edge) - c - band) // q, d


slices = None
for src, name in FRAMES:
    img = np.array(Image.open(SRC + src + '.png').convert('RGBA'))
    x0, y0, x1, y1 = bbox(img)
    a = img[y0:y1, x0:x1]
    h, w = a.shape[:2]
    if slices is None:
        band = band_width(a)
        top = a[:band].transpose(1, 0, 2)          # along x
        left = a[:, :band]                          # along y
        ph, pv = period(top[band:-band]), period(left[band:-band])
        cx, ph, _, wx = cut(top, ph, band)
        cy, pv, _, wy = cut(left, pv, band)
        # The far corners, found the same way from the far end (the motifs'
        # spacing drifts, so the near tile's phase doesn't hold there).
        right, _, _, wr = cut(top[::-1], ph, band)
        bottom, _, _, wb = cut(left[::-1], pv, band)
        wx, wy = max(wx, wr), max(wy, wb)
        slices = (band, ph, pv, cx, cy, right, bottom, wx, wy)
    band, ph, pv, cx, cy, right, bottom, wx, wy = slices
    print(f'{name}: {w}x{h}, band {band}, periods {ph}x{pv}, '
          f'corners L{cx} T{cy} R{right} B{bottom}, '
          f'seams {wx:.1f}/{wy:.1f}')
    if max(wx, wy) > 15:
        raise SystemExit(f'{name}: the edge tiles don\'t repeat cleanly')
    # Pack: the corners with one edge tile between them on each side.
    cw, ch = cx + ph + right, cy + pv + bottom
    out = np.zeros((ch, cw, 4), np.uint8)
    xs = [(0, 0, cx), (cx, cx, ph), (cx + ph, w - right, right)]
    ys = [(0, 0, cy), (cy, cy, pv), (cy + pv, h - bottom, bottom)]
    for dy, sy, hh in ys:
        for dx, sx, ww in xs:
            out[dy:dy + hh, dx:dx + ww] = a[sy:sy + hh, sx:sx + ww]
    out[cy:cy + pv, cx:cx + ph] = 0  # the inside stays clear
    Image.fromarray(out).save(OUT + name + '.webp', quality=92, method=6)
    print(f"  FrameArt('{name}', EdgeInsets.fromLTRB({cx}, {cy}, {right}, "
          f'{bottom}), {band}),  // {cw}x{ch}')
