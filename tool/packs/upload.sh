#!/usr/bin/env bash
# Publishes build/packs to the download server: the packs first, then the
# signed catalog last, so no app sees a catalog whose packs aren't there yet.
#
#   RASIKH_DL_SSH=deploy@your-server tool/packs/upload.sh
#
# Optional: RASIKH_DL_DIR (default /srv/rasikh-dl), RASIKH_DL_URL (e.g.
# https://dl.example.com, to check the result from outside).
#
# A pack already on the server is never replaced (published packs never
# change: a new build is a new version, a new name). If one there differs
# from the catalog, the script stops before publishing the catalog.
set -euo pipefail

cd "$(dirname "$0")/../.."
SSH="${RASIKH_DL_SSH:?set RASIKH_DL_SSH, e.g. deploy@your-server}"
DIR="${RASIKH_DL_DIR:-/srv/rasikh-dl}"
SRC=build/packs

[ -f "$SRC/catalog.json" ] && [ -f "$SRC/catalog.json.sig" ] ||
  { echo "No signed catalog in $SRC: run build_packs.py, then sign_catalog.dart sign." >&2; exit 1; }

echo "1/4 Checking the signature locally…"
dart run tool/packs/sign_catalog.dart verify "$SRC/catalog.json"

echo "2/4 Uploading new packs (existing ones are left alone)…"
ssh "$SSH" "mkdir -p '$DIR/packs'"
rsync -a --ignore-existing --chmod=D755,F644 --info=progress2 "$SRC/packs/" "$SSH:$DIR/packs/"

echo "3/4 Checking every pack on the server against the catalog…"
python3 - "$SRC/catalog.json" <<'PY' | ssh "$SSH" "cd '$DIR' && sha256sum -c --quiet -"
import json, sys
for p in json.load(open(sys.argv[1]))['packs']:
    print(f"{p['sha256']}  {p['file']}")
PY

echo "4/4 Publishing the catalog…"
scp -q "$SRC/catalog.json" "$SSH:$DIR/.catalog.json.new"
scp -q "$SRC/catalog.json.sig" "$SSH:$DIR/.catalog.json.sig.new"
ssh "$SSH" "cd '$DIR' && chmod 644 .catalog.json.new .catalog.json.sig.new &&
  mv -f .catalog.json.new catalog.json && mv -f .catalog.json.sig.new catalog.json.sig"

if [ -n "${RASIKH_DL_URL:-}" ]; then
  echo "From outside:"
  for f in catalog.json catalog.json.sig; do
    printf '  %s: ' "$f"
    curl -s -o /dev/null -w '%{http_code}\n' "$RASIKH_DL_URL/$f" || echo "unreachable (curl error $?)"
  done
  if curl -s "$RASIKH_DL_URL/catalog.json" 2>/dev/null | cmp -s - "$SRC/catalog.json"; then
    echo "  the server's catalog is this one."
  else
    echo "  the server's catalog differs from this one!" >&2; exit 1
  fi
fi
echo "Done."
