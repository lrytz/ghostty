#!/bin/sh
# Re-sign an app bundle with a fixed certificate, so macOS keeps its
# permissions (folder access, automation, ...) across builds; ad-hoc signed
# builds are a new app to macOS every time. Fails unless the result is tied to
# the certificate rather than to the exact binary.
#
# Usage: macos/sign-app.sh [path/to/Ghostty.app]   (default: zig-out/Ghostty.app)
# GHOSTTY_SIGN_IDENTITY overrides the certificate name.
set -eu

app="${1:-zig-out/Ghostty.app}"
name="${GHOSTTY_SIGN_IDENTITY:-lrytz Code Signing}"

security find-certificate -c "$name" >/dev/null 2>&1 || {
  echo "no certificate \"$name\" in the keychain; create or import it with" >&2
  echo "signing-cert from the dotfiles, or set GHOSTTY_SIGN_IDENTITY" >&2
  exit 1
}
codesign --force --deep -s "$name" --preserve-metadata=entitlements,flags "$app"

requirement=$(codesign -d -r- "$app" 2>&1)
case "$requirement" in
  *"certificate leaf"*) ;;
  *) echo "signed $app is not tied to the certificate:" >&2
     echo "$requirement" >&2
     exit 1 ;;
esac
