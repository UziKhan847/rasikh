#!/usr/bin/env python3
"""Packs a printed muṣḥaf for download: one zip per tier, and its entry in
the catalog the app reads (size, SHA-256), ready to sign and upload.

    python3 tool/packs/build_packs.py newmadani 1
    python3 tool/packs/build_packs.py oldmadani 1

    → build/packs/packs/<edition>-<tier>-v<version>.zip
      build/packs/catalog.json   (entries for other packs already in it stay)

Then sign the catalog (tool/packs/sign_catalog.dart sign) and upload
(tool/packs/upload.sh). A pack, once uploaded, never changes: a new build
is a new version, a new file name.

A zip holds only what the app accepts (it refuses anything else):
pages.json, signs.json (Old Madani) and <tier>/{mushaf_manifest.bin,
shared.webp, atlas_info.json, pages/N.webp}. Stored, not compressed (the
page images are WebP already), with fixed dates, so the same files make the
same zip.
"""
import datetime
import hashlib
import json
import os
import sys
import zipfile

SOURCES = {'newmadani': 'assets/quran/new_madani', 'oldmadani': 'assets/quran/old_madani'}
OUT = 'build/packs'
FIXED = (2024, 1, 1, 0, 0, 0)


def files_of(src, tier):
    names = []
    for n in ('pages.json', 'signs.json'):
        if os.path.exists(f'{src}/{n}'):
            names.append(n)
    for n in ('mushaf_manifest.bin', 'shared.webp', 'atlas_info.json'):
        if os.path.exists(f'{src}/{tier}/{n}'):
            names.append(f'{tier}/{n}')
    pages = sorted(os.listdir(f'{src}/{tier}/pages'), key=lambda n: int(n.split('.')[0]))
    for n in pages:
        if not n.endswith('.webp'):
            sys.exit(f'unexpected file {tier}/pages/{n}')
        names.append(f'{tier}/pages/{n}')
    return names


def sha256(path):
    h = hashlib.sha256()
    with open(path, 'rb') as f:
        for block in iter(lambda: f.read(1 << 20), b''):
            h.update(block)
    return h.hexdigest()


def main():
    if len(sys.argv) != 3 or sys.argv[1] not in SOURCES or not sys.argv[2].isdigit():
        sys.exit(__doc__)
    edition, version = sys.argv[1], int(sys.argv[2])
    src = SOURCES[edition]
    pages = json.load(open(f'{src}/pages.json'))
    if pages.get('edition') != edition:
        sys.exit(f'{src}/pages.json says {pages.get("edition")!r}, not {edition!r}')
    os.makedirs(f'{OUT}/packs', exist_ok=True)
    cat_path = f'{OUT}/catalog.json'
    catalog = json.load(open(cat_path)) if os.path.exists(cat_path) else {'format': 1, 'packs': []}
    for tier in ('high', 'low'):
        if not os.path.isdir(f'{src}/{tier}'):
            continue
        name = f'{edition}-{tier}-v{version}.zip'
        path = f'{OUT}/packs/{name}'
        unpacked = 0
        with zipfile.ZipFile(path, 'w', zipfile.ZIP_STORED) as z:
            for n in files_of(src, tier):
                info = zipfile.ZipInfo(n, FIXED)
                info.external_attr = 0o644 << 16
                data = open(f'{src}/{n}', 'rb').read()
                unpacked += len(data)
                z.writestr(info, data)
        entry = {
            'edition': edition,
            'tier': tier,
            'version': version,
            'file': f'packs/{name}',
            'bytes': os.path.getsize(path),
            'sha256': sha256(path),
            'unpacked': unpacked,
        }
        catalog['packs'] = [p for p in catalog['packs']
                            if not (p['edition'] == edition and p['tier'] == tier)] + [entry]
        print(f'{name}: {entry["bytes"] / 1e6:.1f} MB, sha256 {entry["sha256"][:16]}…')
    # A new catalog each time: the app refuses one older than it has seen.
    catalog['issued'] = datetime.datetime.now(datetime.timezone.utc).replace(microsecond=0).isoformat()
    catalog['packs'].sort(key=lambda p: (p['edition'], p['tier']))
    with open(cat_path, 'w') as f:
        json.dump(catalog, f, indent=1, ensure_ascii=False)
        f.write('\n')
    print(f'{cat_path}: {len(catalog["packs"])} packs, issued {catalog["issued"]}')
    print('Now sign it: dart run tool/packs/sign_catalog.dart sign')


main()
