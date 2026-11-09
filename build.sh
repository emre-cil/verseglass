#!/bin/zsh
# Builds a universal dist/Verseglass.app (no Dock icon) and ad-hoc signs it.
# Requires Xcode or the Swift toolchain. No Apple Developer account.
set -euo pipefail
cd "$(dirname "$0")"

build_arch() {
  local arch="$1"
  local triple="${arch}-apple-macosx15.0"
  swift build -c release --triple "$triple" >&2
  local built=".build/out/Products/Release/Verseglass"
  if [[ ! -f "$built" ]]; then
    built="$(find .build -type f -name Verseglass ! -path '*.dSYM/*' ! -name "Verseglass-*" | head -1)"
  fi
  if [[ -z "$built" || ! -f "$built" ]]; then
    echo "missing ${arch} binary" >&2
    exit 1
  fi
  local staged=".build/Verseglass-${arch}"
  cp "$built" "$staged"
  local info
  info="$(lipo -info "$staged")"
  echo "$info" >&2
  if [[ "$info" != *"$arch"* ]]; then
    echo "expected ${arch}, got: ${info}" >&2
    exit 1
  fi
  echo "$staged"
}

arm="$(build_arch arm64)"
intel="$(build_arch x86_64)"

APP="dist/Verseglass.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
lipo -create "$arm" "$intel" -output "$APP/Contents/MacOS/Verseglass"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp -R Resources/en.lproj Resources/tr.lproj "$APP/Contents/Resources/"
cp Sources/VerseglassApp/Resources/now_playing_helper.swift "$APP/Contents/Resources/now_playing_helper.swift"
codesign --force --deep --sign - "$APP"
echo "built $APP"
