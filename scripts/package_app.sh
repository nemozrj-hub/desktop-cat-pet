#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/.build/objc-release"

if [[ -n "${DESKTOP_CAT_OUTPUT_DIR:-}" ]]; then
  OUTPUT_DIR="$DESKTOP_CAT_OUTPUT_DIR"
elif [[ "$(basename "$(dirname "$ROOT_DIR")")" == "work" ]]; then
  OUTPUT_DIR="$(cd "$ROOT_DIR/../.." && pwd)/outputs"
else
  OUTPUT_DIR="$ROOT_DIR/releases/build"
fi

APP_DIR="$OUTPUT_DIR/DesktopCatPet.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

mkdir -p "$BUILD_DIR" "$MACOS_DIR" "$RESOURCES_DIR"

clang \
  -fobjc-arc \
  -mmacosx-version-min=13.0 \
  -arch x86_64 \
  -arch arm64 \
  -framework Cocoa \
  -framework ServiceManagement \
  "$ROOT_DIR/ObjC/main.m" \
  -o "$BUILD_DIR/DesktopCatPet"

cp "$BUILD_DIR/DesktopCatPet" "$MACOS_DIR/DesktopCatPet"
cp "$ROOT_DIR/Info.plist" "$CONTENTS_DIR/Info.plist"
cp "$ROOT_DIR/Sources/DesktopCatPet/Resources/cat_desktop_pet_sprite_sheet.png" "$RESOURCES_DIR/cat_desktop_pet_sprite_sheet.png"
cp "$ROOT_DIR/Sources/DesktopCatPet/Resources/cat_desktop_pet_sprite_sheet.json" "$RESOURCES_DIR/cat_desktop_pet_sprite_sheet.json"
chmod +x "$MACOS_DIR/DesktopCatPet"
codesign --force --deep --sign - "$APP_DIR" >/dev/null 2>&1 || true

echo "$APP_DIR"
