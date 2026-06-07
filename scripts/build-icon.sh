#!/usr/bin/env bash
# Genera AppIcon.icns a partir de un PNG maestro de 1024×1024.
# El PNG se renderiza con render-icon.swift usando ImageRenderer + SwiftUI.
# Las densidades requeridas por .iconset se generan con sips.
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="$PROJECT_ROOT/build"
ICONSET="$BUILD/AppIcon.iconset"
PNG_MAESTRO="$BUILD/icon/AppIcon.png"
ICNS="$BUILD/AppIcon.icns"

rm -rf "$ICONSET" "$BUILD/icon"
mkdir -p "$BUILD/icon"

echo "▸ Compilando render-icon..."
RENDER_BIN="$BUILD/render-icon"
swiftc -O \
    "$PROJECT_ROOT/scripts/render-icon.swift" \
    "$PROJECT_ROOT/Resources/IconSource/AppIconView.swift" \
    -o "$RENDER_BIN"

echo "▸ Renderizando PNG maestro (1024×1024)..."
"$RENDER_BIN" "$PNG_MAESTRO"

echo "▸ Generando densidades..."
ICONSET_TMP="$BUILD/icon-tmp"
mkdir -p "$ICONSET_TMP"

sips -z 16 16     "$PNG_MAESTRO" --out "$ICONSET_TMP/icon_16x16.png"         >/dev/null
sips -z 32 32     "$PNG_MAESTRO" --out "$ICONSET_TMP/icon_16x16@2x.png"      >/dev/null
sips -z 32 32     "$PNG_MAESTRO" --out "$ICONSET_TMP/icon_32x32.png"         >/dev/null
sips -z 64 64     "$PNG_MAESTRO" --out "$ICONSET_TMP/icon_32x32@2x.png"      >/dev/null
sips -z 64 64     "$PNG_MAESTRO" --out "$ICONSET_TMP/icon_64x64.png"         >/dev/null
sips -z 128 128   "$PNG_MAESTRO" --out "$ICONSET_TMP/icon_64x64@2x.png"      >/dev/null
sips -z 128 128   "$PNG_MAESTRO" --out "$ICONSET_TMP/icon_128x128.png"       >/dev/null
sips -z 256 256   "$PNG_MAESTRO" --out "$ICONSET_TMP/icon_128x128@2x.png"    >/dev/null
sips -z 256 256   "$PNG_MAESTRO" --out "$ICONSET_TMP/icon_256x256.png"       >/dev/null
sips -z 512 512   "$PNG_MAESTRO" --out "$ICONSET_TMP/icon_256x256@2x.png"    >/dev/null
sips -z 512 512   "$PNG_MAESTRO" --out "$ICONSET_TMP/icon_512x512.png"       >/dev/null
sips -z 1024 1024 "$PNG_MAESTRO" --out "$ICONSET_TMP/icon_512x512@2x.png"    >/dev/null

mkdir -p "$ICONSET"
mv "$ICONSET_TMP"/*.png "$ICONSET/"
rmdir "$ICONSET_TMP"

echo "▸ Empaquetando .icns..."
iconutil -c icns "$ICONSET" -o "$ICNS"

echo "✓ Icono generado: $ICNS"
file "$ICNS"
