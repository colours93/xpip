#!/bin/bash
set -euo pipefail

# Fast dev rebuild: compile + restart. Skips icons, signing, launchd setup.
# Usage: bash dev.sh

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DAEMON_DIR="$SCRIPT_DIR/daemon"
EXTENSION_DIR="$SCRIPT_DIR/extension"
SAFARI_DIR="$SCRIPT_DIR/safari"
APP_BUNDLE="$HOME/.xpip/xpip.app"
BINARY="$HOME/.xpip/xpip.app/Contents/MacOS/xpip"
LABEL="com.xpip.daemon"

SWIFT_FILES=("$DAEMON_DIR"/*.swift "$DAEMON_DIR"/Games/*.swift "$DAEMON_DIR"/Games/Arcade/*.swift "$DAEMON_DIR"/Games/Emulators/*.swift "$DAEMON_DIR"/Games/Sprites/*.swift)
mkdir -p "$APP_BUNDLE/Contents/MacOS"

# Ensure host Info.plist has Safari extension key
if [ -f "$APP_BUNDLE/Contents/Info.plist" ] && ! grep -q SFSafariWebExtensionBundleIdentifier "$APP_BUNDLE/Contents/Info.plist" 2>/dev/null; then
    /usr/libexec/PlistBuddy -c "Add :SFSafariWebExtensionBundleIdentifier array" "$APP_BUNDLE/Contents/Info.plist" 2>/dev/null || true
    /usr/libexec/PlistBuddy -c "Add :SFSafariWebExtensionBundleIdentifier:0 string com.xpip.daemon.safari" "$APP_BUNDLE/Contents/Info.plist" 2>/dev/null || true
fi

printf "Compiling %d files..." "${#SWIFT_FILES[@]}"
swiftc "${SWIFT_FILES[@]}" \
    -o "$BINARY" \
    -framework Cocoa \
    -framework ApplicationServices \
    -framework QuartzCore \
    -O

# Build Safari appex if safari/ exists
APPEX_BUNDLE="$APP_BUNDLE/Contents/PlugIns/XPipSafari.appex"
if [ -d "$SAFARI_DIR" ]; then
    APPEX_BINARY="$APPEX_BUNDLE/Contents/MacOS/XPipSafari"
    APPEX_RESOURCES="$APPEX_BUNDLE/Contents/Resources"
    mkdir -p "$APPEX_BUNDLE/Contents/MacOS" "$APPEX_RESOURCES/icons"

    swiftc "$SAFARI_DIR/SafariWebExtensionHandler.swift" \
        -parse-as-library \
        -module-name XPipSafari \
        -framework Foundation \
        -framework SafariServices \
        -Xlinker -e -Xlinker _NSExtensionMain \
        -o "$APPEX_BINARY" \
        -O

    chmod +x "$APPEX_BINARY"
    cp "$SAFARI_DIR/Info.plist" "$APPEX_BUNDLE/Contents/Info.plist"
    cp "$SAFARI_DIR/manifest.json" "$APPEX_RESOURCES/manifest.json"

    for f in popup.html popup.js background.js content.js autopip.js icons.js; do
        [ -f "$EXTENSION_DIR/$f" ] && cp "$EXTENSION_DIR/$f" "$APPEX_RESOURCES/$f"
    done
    if [ -d "$EXTENSION_DIR/shared" ]; then
        mkdir -p "$APPEX_RESOURCES/shared"
        cp "$EXTENSION_DIR/shared/"*.js "$APPEX_RESOURCES/shared/" 2>/dev/null || true
    fi
    if [ -d "$EXTENSION_DIR/icons" ]; then
        cp "$EXTENSION_DIR/icons/"*.png "$APPEX_RESOURCES/icons/" 2>/dev/null || true
    fi
fi

# Sign inside-out: appex first, then host app
SIGN_ID=$(security find-identity -v -p codesigning | grep -E "XPip Dev|xpip Dev|pipbounce Dev" | head -1 | awk -F'"' '{print $2}' || true)

if [ -d "$APPEX_BUNDLE" ]; then
    SAFARI_ENTITLEMENTS="$SAFARI_DIR/safari.entitlements"
    if [ -n "$SIGN_ID" ]; then
        codesign --force --entitlements "$SAFARI_ENTITLEMENTS" --sign "$SIGN_ID" "$APPEX_BUNDLE" 2>/dev/null
    else
        codesign --force --entitlements "$SAFARI_ENTITLEMENTS" --sign - "$APPEX_BUNDLE" 2>/dev/null
    fi
fi

if [ -n "$SIGN_ID" ]; then
    codesign --force --sign "$SIGN_ID" "$APP_BUNDLE" 2>/dev/null
else
    codesign --force --sign - "$APP_BUNDLE" 2>/dev/null
fi

printf " done.\n"

# KeepAlive restarts it automatically after kill
launchctl kickstart -k "gui/$(id -u)/$LABEL" 2>/dev/null || {
    # Fallback if not bootstrapped yet
    echo "Not bootstrapped — run install.sh first"
    exit 1
}

echo "Restarted. tail -f ~/.xpip/xpip.log"
