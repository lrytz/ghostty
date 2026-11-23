#!/bin/sh
# Build, sign and zip the app for a GitHub release. Refuses to produce a zip
# from an ad-hoc signed build: installs from it would lose their permissions.
#
# Usage: macos/make-release-zip.sh <tag>   e.g. v1.4.0-workspaces-3
# Writes sandbox/Ghostty-<tag>-macos.zip.
set -eu

tag="${1:?usage: $0 <tag>}"
app=zig-out/Ghostty.app
zip="sandbox/Ghostty-$tag-macos.zip"

# Explicit version: on a tagged commit the build otherwise insists on a
# plain vX.Y.Z tag.
zig build -Doptimize=ReleaseFast -Dversion-string="${tag#v}"
"$(dirname "$0")/sign-app.sh" "$app"

mkdir -p sandbox
rm -f "$zip"
ditto -c -k --keepParent "$app" "$zip"
echo "$zip"
