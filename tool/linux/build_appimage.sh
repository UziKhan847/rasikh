#!/bin/sh
# Builds build/Rasikh-x86_64.AppImage from the Linux release bundle.
#
#   flutter build linux --release
#   tool/linux/build_appimage.sh [folder to copy it to]
#
# Needs appimagetool on the PATH. The .desktop's StartupWMClass is the
# window's class (the application id in linux/CMakeLists.txt), so panels and
# docks match the running window to its launcher and show its icon.
set -eu
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUNDLE="$ROOT/build/linux/x64/release/bundle"
APPDIR="$ROOT/build/Rasikh.AppDir"
OUT="$ROOT/build/Rasikh-x86_64.AppImage"

[ -x "$BUNDLE/rasikh" ] || { echo "No bundle: run flutter build linux --release first" >&2; exit 1; }

rm -rf "$APPDIR"
mkdir -p "$APPDIR"
cp -a "$BUNDLE/." "$APPDIR/"
cp "$ROOT/assets/apk_icons/app_launcher_icon.png" "$APPDIR/rasikh.png"
cat > "$APPDIR/AppRun" <<'RUN'
#!/bin/sh
HERE="$(dirname "$(readlink -f "$0")")"
exec "$HERE/rasikh" "$@"
RUN
chmod +x "$APPDIR/AppRun"
cat > "$APPDIR/rasikh.desktop" <<'DESK'
[Desktop Entry]
Type=Application
Name=Rāsikh
Exec=rasikh
Icon=rasikh
Categories=Education;
StartupWMClass=com.uzikhan.rasikh
DESK

ARCH=x86_64 appimagetool --no-appstream "$APPDIR" "$OUT"
echo "Built $OUT"

# A folder given: the AppImage is copied there too (e.g. the synced one).
if [ $# -gt 0 ]; then
  mkdir -p "$1"
  cp "$OUT" "$1/"
  echo "Copied to $1/"
fi
