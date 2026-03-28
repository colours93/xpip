#!/usr/bin/env bash
# Download Freedoom IWADs (free Doom-compatible game data) into ~/.xpip/wads/
# Use: bash scripts/get-freedoom.sh

set -euo pipefail

VERSION="0.13.0"
URL="https://github.com/freedoom/freedoom/releases/download/v${VERSION}/freedoom-${VERSION}.zip"
WAD_DIR="${HOME}/.xpip/wads"
TMP_DIR="${TMPDIR:-/tmp}/xpip-freedoom-$$"

mkdir -p "$WAD_DIR"
mkdir -p "$TMP_DIR"
trap 'rm -rf "$TMP_DIR"' EXIT

echo "[get-freedoom] Downloading Freedoom v${VERSION}..."
curl -sSL -o "$TMP_DIR/freedoom.zip" "$URL"

echo "[get-freedoom] Extracting..."
unzip -q -o "$TMP_DIR/freedoom.zip" -d "$TMP_DIR"

# Copy .wad files into ~/.xpip/wads (zip may have a top-level dir like freedoom-0.13.0/)
find "$TMP_DIR" -maxdepth 2 -name "*.wad" -exec cp -v {} "$WAD_DIR/" \;

echo "[get-freedoom] Done. IWADs in $WAD_DIR:"
ls -la "$WAD_DIR"/*.wad 2>/dev/null || true
