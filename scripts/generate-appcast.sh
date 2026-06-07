#!/usr/bin/env bash
# Genera docs/appcast.json a partir de un release de GitHub.
# Uso: ./scripts/generate-appcast.sh <version> <download_url> [notas]
# Ejemplo: ./scripts/generate-appcast.sh "0.2.0" "https://github.com/whosmayk/TransactApp/releases/download/v0.2.0/TransactApp.zip" "Novedades: ..."
set -euo pipefail

if [ $# -lt 2 ]; then
    echo "Uso: $0 <version> <download_url> [notas]"
    exit 1
fi

VERSION="$1"
DOWNLOAD_URL="$2"
NOTAS="${3:-}"
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APPCAST="$PROJECT_ROOT/docs/appcast.json"

cat > "$APPCAST" <<EOF
{
  "latestVersion": "$VERSION",
  "downloadUrl": "$DOWNLOAD_URL",
  "releaseNotes": $(printf '%s' "$NOTAS" | jq -Rs .),
  "minimumOSVersion": "14.0",
  "pubDate": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF

echo "✓ appcast.json generado: $APPCAST"
echo "  Version: $VERSION"
echo "  URL: $DOWNLOAD_URL"
