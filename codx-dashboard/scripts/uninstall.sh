#!/usr/bin/env bash
# Desinstala o CodX Dashboard
set -euo pipefail

PLIST_NAME="com.codx.dashboard"
PLIST_FILE="$HOME/Library/LaunchAgents/${PLIST_NAME}.plist"
APP_BUNDLE="$HOME/Applications/CodX Dashboard.app"

echo "→ Parando e removendo LaunchAgent..."
launchctl stop  "$PLIST_NAME" 2>/dev/null || true
launchctl unload "$PLIST_FILE" 2>/dev/null || true
rm -f "$PLIST_FILE"

echo "→ Removendo .app bundle..."
rm -rf "$APP_BUNDLE"

echo "✓ CodX Dashboard desinstalado."
