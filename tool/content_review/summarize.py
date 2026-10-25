"""Turns an exported content review (the zip, or review.json, from
tools/content_review/index.html) into a markdown change list: per item, its
status, the reviewers' comments, each corrected field next to the current
text, and the attached files (extracted next to the list).

    python3 tool/content_review/summarize.py <review.zip|review.json> [out_dir]

Items whose content changed since they were reviewed are marked, so a stale
correction isn't applied blindly. Writes <out_dir>/REVIEW.md (default:
build/content_review/applied/<zip name>/).
"""

import json
import os
import sys
import zipfile

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
CONTENT = os.path.join(ROOT, 'tools', 'content_review', 'content.js')
ORDER = {'change': 0, 'question': 1, 'ok': 2, 'unreviewed': 3}


def load_content():
    with open(CONTENT, encoding='utf-8') as f:
        s = f.read()
    return json.loads(s[s.index('{'):s.rindex('}') + 1])


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    src = sys.argv[1]
    name = os.path.splitext(os.path.basename(src))[0]
    out = sys.argv[2] if len(sys.argv) > 2 else os.path.join(
        ROOT, 'build', 'content_review', 'applied', name)
    os.makedirs(out, exist_ok=True)
    if src.endswith('.zip'):
        with zipfile.ZipFile(src) as z:
            review = json.loads(z.read('review.json'))
            for n in z.namelist():
                if n.startswith('attachments/') and not n.endswith('/'):
                    z.extract(n, out)
    else:
        with open(src, encoding='utf-8') as f:
            review = json.load(f)
    content = load_content()
    items = content['items']

    lines = [f"# Content review — {review.get('reviewer') or '?'}",
             f"Exported {review.get('exportedAt', '?')}; content generated "
             f"{review.get('contentGeneratedAt', '?')} (now {content.get('generatedAt')}).", '']
    counts = {}
    for id_, r in sorted(review.get('items', {}).items(),
                         key=lambda e: (ORDER.get(e[1].get('status'), 9), e[0])):
        counts[r.get('status')] = counts.get(r.get('status'), 0) + 1
        it = items.get(id_)
        stale = it is not None and r.get('reviewedHash') and r['reviewedHash'] != it['hash']
        lines.append(f"## `{id_}` — {r.get('status')}"
                     + (' ⚠ content changed since this review' if stale else '')
                     + (' ⚠ item no longer exists' if it is None else ''))
        if it:
            where = ' › '.join([it['section'], *it.get('path', [])])
            lines.append(f"*{it['kind']}* in {where}")
        for c in r.get('comments', []):
            lines.append(f"- **{c.get('by', '?')}** ({c.get('at', '')[:16]}): "
                         + c.get('text', '').replace('\n', '\n  '))
        fields = {f['key']: f['text'] for f in (it or {}).get('fields', [])}
        for key, langs in (r.get('corrections') or {}).items():
            for lang, text in langs.items():
                lines.append(f"- correct **{key}** [{lang}]:")
                if key in fields and lang in fields[key]:
                    lines.append(f"  - now: {fields[key][lang]}")
                lines.append(f"  - to:  {text}")
        for f in r.get('files', []):
            path = f.get('path') or f"attachments/{id_}/{f['name']}"
            lines.append(f"- attachment: `{path}` ({f.get('type') or '?'}, "
                         f"{f.get('size', '?')} bytes)")
        lines.append('')
    lines.insert(2, 'Counts: ' + ', '.join(f'{k}: {v}' for k, v in sorted(counts.items())))
    with open(os.path.join(out, 'REVIEW.md'), 'w', encoding='utf-8') as f:
        f.write('\n'.join(lines) + '\n')
    print(f"{sum(counts.values())} reviewed items → {os.path.join(out, 'REVIEW.md')}")


if __name__ == '__main__':
    main()
