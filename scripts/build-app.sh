#!/usr/bin/env bash
# Construye un .app bundle a partir del binario SPM.
# Uso: ./scripts/build-app.sh [debug|release]
set -euo pipefail

CONFIG="${1:-debug}"
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_ROOT"

echo "▸ Compilando ($CONFIG)..."
swift build -c "$CONFIG"

BIN_DIR=$(swift build -c "$CONFIG" --show-bin-path)
BINARY="$BIN_DIR/TransactApp"

if [ ! -f "$BINARY" ]; then
    echo "✗ No se encontró el binario en $BINARY"
    exit 1
fi

APP_DIR="$PROJECT_ROOT/build/TransactApp.app"
echo "▸ Ensamblando bundle en $APP_DIR..."

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

cp "$BINARY" "$APP_DIR/Contents/MacOS/TransactApp"
cp "$PROJECT_ROOT/Resources/Info.plist" "$APP_DIR/Contents/Info.plist"

# Permisos correctos
chmod +x "$APP_DIR/Contents/MacOS/TransactApp"

# Generar y copiar el icono
"$PROJECT_ROOT/scripts/build-icon.sh"
cp "$PROJECT_ROOT/build/AppIcon.icns" "$APP_DIR/Contents/Resources/AppIcon.icns"

# Copiar el bundle de recursos del módulo Models (Localizable.strings)
# Buscar en posibles rutas (varía según versión de Swift/SPM)
for candidate in \
    "$BIN_DIR/TransactApp_Models.bundle" \
    "$PROJECT_ROOT/.build/plugins/outputs/TransactApp_Models/TransactApp_Models.bundle" \
    "$PROJECT_ROOT/.build/arm64-apple-macosx/$CONFIG/TransactApp_Models.bundle" \
    "$PROJECT_ROOT/.build/x86_64-apple-macosx/$CONFIG/TransactApp_Models.bundle"; do
    if [ -d "$candidate" ]; then
        cp -R "$candidate" "$APP_DIR/Contents/Resources/"
        echo "✓ Bundle de recursos i18n copiado desde $candidate"
        break
    fi
done
if [ ! -d "$APP_DIR/Contents/Resources/TransactApp_Models.bundle" ]; then
    echo "⚠ No se encontró TransactApp_Models.bundle (Localizable.strings se leerán del main bundle)"
fi

echo "✓ Bundle creado: $APP_DIR"
echo "  Ejecuta: open '$APP_DIR'"
