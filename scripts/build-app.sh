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
MODELS_BUNDLE="$BIN_DIR/TransactApp_Models.bundle"
if [ -d "$MODELS_BUNDLE" ]; then
    cp -R "$MODELS_BUNDLE" "$APP_DIR/Contents/Resources/"
    echo "✓ Bundle de recursos i18n copiado"
else
    echo "⚠ No se encontró $MODELS_BUNDLE (Localizable.strings no estarán disponibles)"
fi

echo "✓ Bundle creado: $APP_DIR"
echo "  Ejecuta: open '$APP_DIR'"
