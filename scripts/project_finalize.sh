#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${1:-}"

if [[ -z "$VERSION" ]]; then
  VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$ROOT_DIR/Info.plist")"
fi

APP_DIR="$("$ROOT_DIR/scripts/package_app.sh")"
OUTPUT_DIR="$(dirname "$APP_DIR")"
ZIP_PATH="$OUTPUT_DIR/DesktopCatPet-$VERSION-universal.zip"
CHECK_BIN="$ROOT_DIR/.build/objc-release/DesktopCatPetWarningsCheck"

clang \
  -fobjc-arc \
  -Wall \
  -Wextra \
  -Wpedantic \
  -Werror \
  -mmacosx-version-min=13.0 \
  -arch x86_64 \
  -arch arm64 \
  -framework Cocoa \
  -framework ServiceManagement \
  "$ROOT_DIR/ObjC/main.m" \
  -o "$CHECK_BIN"

plutil -lint "$APP_DIR/Contents/Info.plist" >/dev/null
lipo -archs "$APP_DIR/Contents/MacOS/DesktopCatPet" | grep -q "x86_64"
lipo -archs "$APP_DIR/Contents/MacOS/DesktopCatPet" | grep -q "arm64"
codesign --verify --deep --strict "$APP_DIR"
python3 -m json.tool "$ROOT_DIR/Sources/DesktopCatPet/Resources/cat_desktop_pet_sprite_sheet.json" >/dev/null
cmp \
  "$ROOT_DIR/Sources/DesktopCatPet/Resources/cat_desktop_pet_sprite_sheet.png" \
  "$APP_DIR/Contents/Resources/cat_desktop_pet_sprite_sheet.png" >/dev/null
cmp \
  "$ROOT_DIR/Sources/DesktopCatPet/Resources/cat_desktop_pet_sprite_sheet.json" \
  "$APP_DIR/Contents/Resources/cat_desktop_pet_sprite_sheet.json" >/dev/null

ditto -c -k --keepParent "$APP_DIR" "$ZIP_PATH"

echo "PASS"
echo "App: $APP_DIR"
echo "Zip: $ZIP_PATH"
echo "Version: $VERSION"

if git -C "$ROOT_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo ""
  git -C "$ROOT_DIR" status --short
fi
