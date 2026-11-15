"""Adds strings to every .arb (those not there yet), from a JSON file of
{lang: {key: value}}:  python3 tool/l10n_add.py strings.json
then run `flutter gen-l10n`."""
import json, sys
tr = json.load(open(sys.argv[1], encoding='utf-8'))
for lang, kv in tr.items():
    p = f'lib/l10n/app_{lang}.arb'
    t = open(p, encoding='utf-8').read().rstrip()
    assert t.endswith('}')
    body = t[:-1].rstrip()
    add = ''.join(f',\n  {json.dumps(k)}: {json.dumps(v, ensure_ascii=False)}'
                  for k, v in kv.items() if f'"{k}"' not in t)
    open(p, 'w', encoding='utf-8').write(body + add + '\n}\n')
