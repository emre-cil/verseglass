#!/bin/zsh
# Copies Verseglass.app to /Applications and turns on Open at login.
# Uses a neighboring Verseglass.app (release zip), otherwise dist/, otherwise builds.
set -euo pipefail
cd "$(dirname "$0")"

if [[ -d Verseglass.app ]]; then
  SRC="Verseglass.app"
elif [[ -d dist/Verseglass.app ]]; then
  SRC="dist/Verseglass.app"
else
  ./build.sh
  SRC="dist/Verseglass.app"
fi

DEST="/Applications/Verseglass.app"

if pgrep -x Verseglass >/dev/null; then
  killall Verseglass
  for _ in {1..30}; do
    pgrep -x Verseglass >/dev/null || break
    sleep 0.1
  done
fi

rm -rf "$DEST"
ditto "$SRC" "$DEST"
xattr -cr "$DEST" || true
codesign --force --deep --sign - "$DEST"
open "$DEST" --args --open-at-login

echo "installed $DEST"
echo "Opens at login. No Dock icon: use the music-note menu on the right, or Spotlight."
echo "If macOS asks, allow Verseglass under System Settings → General → Login Items."
