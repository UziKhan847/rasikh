#!/usr/bin/env bash
# Runs the marks server locally: downloads the pinned PocketBase (PB_VERSION)
# into .bin/, applies pb_migrations/, loads pb_hooks/, serves on :8090.
#   ./dev.sh                  serve (data in .dev_data/)
#   ./dev.sh superuser EMAIL PASSWORD   create the dashboard admin
set -euo pipefail
cd "$(dirname "$0")"
VER="$(cat PB_VERSION)"
case "$(uname -s)-$(uname -m)" in
  Linux-x86_64)  PLAT=linux_amd64 ;;
  Linux-aarch64) PLAT=linux_arm64 ;;
  Darwin-arm64)  PLAT=darwin_arm64 ;;
  Darwin-x86_64) PLAT=darwin_amd64 ;;
  *) echo "unsupported platform" >&2; exit 1 ;;
esac
BIN=".bin/pocketbase-$VER"
if [ ! -x "$BIN" ]; then
  mkdir -p .bin
  ZIP=".bin/pb.zip"
  curl -fsSL -o "$ZIP" \
    "https://github.com/pocketbase/pocketbase/releases/download/v$VER/pocketbase_${VER}_${PLAT}.zip"
  unzip -o -q "$ZIP" pocketbase -d .bin
  mv .bin/pocketbase "$BIN"
  rm "$ZIP"
fi
DATA="${PB_DATA:-.dev_data}"
ARGS=(--dir="$DATA" --migrationsDir=pb_migrations --hooksDir=pb_hooks --publicDir=pb_public)
if [ "${1:-}" = "superuser" ]; then
  exec "$BIN" superuser upsert "$2" "$3" "${ARGS[@]}"
fi
exec "$BIN" serve --http="${PB_HTTP:-127.0.0.1:8090}" "${ARGS[@]}"
