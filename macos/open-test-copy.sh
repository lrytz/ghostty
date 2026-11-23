#!/bin/sh
# Launch a build next to the everyday Ghostty without sharing its session.
# The copy gets its own bundle ID, so window restoration, the workspace
# backup and preferences are kept separate. Config is still shared.
#
# Usage: macos/open-test-copy.sh [path/to/Ghostty.app]   (default: zig-out/Ghostty.app)
set -eu

src="${1:-zig-out/Ghostty.app}"
dst="$(dirname "$src")/Ghostty Test.app"
id=com.mitchellh.ghostty.test

[ -d "$src" ] || { echo "no app at $src" >&2; exit 1; }

# A running copy would just be activated instead of the new build.
pkill -f "$dst/Contents/MacOS/ghostty" && sleep 1 || true

rm -rf "$dst"
ditto "$src" "$dst"
plist="$dst/Contents/Info.plist"
/usr/libexec/PlistBuddy \
  -c "Set :CFBundleIdentifier $id" \
  -c "Set :CFBundleName Ghostty Test" \
  -c "Set :CFBundleDisplayName Ghostty Test" \
  "$plist"
# The local certificate keeps macOS permissions across rebuilds.
"$(dirname "$0")/sign-app.sh" "$dst" 2>/dev/null ||
  codesign --force --deep -s - --preserve-metadata=entitlements "$dst" 2>/dev/null

open "$dst"
