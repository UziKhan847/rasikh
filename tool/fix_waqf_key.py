"""Renames one sign's key in a printed muṣḥaf's manifests (both tiers), when
its corrected page (docs/<page>.svg) gives it another āyah or number:

    python3 tool/fix_waqf_key.py old 39:50:qf1 39:51:qf1     (p.464)
    python3 tool/fix_waqf_key.py old 37:30:qf2 37:31:qf1     (p.447)

Then run tool/gen_print_layout.py for the edition, which reads the corrected
SVG and checks that the SVG and the manifest now agree.

A key is <surah>:<verse>:<kind><n>, kind qf (waqf) or w (word) or E (āyah
end). Only the key fields of the records and instances are rewritten; the
old key must be there exactly once per manifest and the new one not at all.
"""
import struct
import sys

ROOTS = {'old': 'assets/quran/old_madani', 'new': 'assets/quran/new_madani'}
KINDS = {'w': 0, 'E': 1, 'qf': 2}


def pack(s, v, t, i):
    return s | v << 7 | t << 16 | i << 20


def parse_key(text):
    try:
        s, v, rest = text.split(':')
        kind = rest.rstrip('0123456789')
        return pack(int(s), int(v), KINDS[kind], int(rest[len(kind):]))
    except (ValueError, KeyError):
        sys.exit(f'not a key: {text!r} (e.g. 39:51:qf1)')


def key_offsets(d):
    """Where every key is: the first u32 of each record and instance."""
    _, _, _, pe, pc, rc, _, sc, se, inst, rec = struct.unpack('<IBBHIIIHHHH', d[:28])
    pt = 32 + sc * se
    rs = pt + pc * pe
    ins = rs + rc * rec
    n_inst = 0
    for i in range(pc):
        _, _, _, _, _, _, _, fi, icn, _ = struct.unpack('<IHHHHHHIHH', d[pt + i * pe:pt + (i + 1) * pe])
        n_inst = max(n_inst, fi + icn)
    return [rs + k * rec for k in range(rc)] + [ins + k * inst for k in range(n_inst)]


def main():
    if len(sys.argv) != 4 or sys.argv[1] not in ROOTS:
        sys.exit(__doc__)
    old, new = parse_key(sys.argv[2]), parse_key(sys.argv[3])
    for tier in ('high', 'low'):
        path = f'{ROOTS[sys.argv[1]]}/{tier}/mushaf_manifest.bin'
        d = bytearray(open(path, 'rb').read())
        at = [o for o in key_offsets(d) if struct.unpack_from('<I', d, o)[0] == old]
        has_new = any(struct.unpack_from('<I', d, o)[0] == new for o in key_offsets(d))
        if has_new and not at:
            print(f'{path}: already {sys.argv[3]}')
            continue
        if len(at) != 1 or has_new:
            sys.exit(f'{path}: {sys.argv[2]} found {len(at)}×, {sys.argv[3]} '
                     f'{"present" if has_new else "absent"}: not changed')
        struct.pack_into('<I', d, at[0], new)
        open(path, 'wb').write(d)
        print(f'{path}: {sys.argv[2]} → {sys.argv[3]} (byte {at[0]})')


main()
