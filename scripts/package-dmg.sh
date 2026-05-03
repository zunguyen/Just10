#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DIST_DIR="${DIST_DIR:-$ROOT_DIR/dist}"
LAST_BUILD_FILE="$DIST_DIR/.last-build"

# Resolve the .app to package: prefer the most recent build-release.sh handoff;
# fall back to running the build if no stamped artifact exists.
APP_PATH=""
if [[ -f "$LAST_BUILD_FILE" ]]; then
  APP_PATH="$(cat "$LAST_BUILD_FILE")"
fi
if [[ ! -d "$APP_PATH" ]]; then
  "$ROOT_DIR/scripts/build-release.sh"
  APP_PATH="$(cat "$LAST_BUILD_FILE")"
fi

# Reuse the .app's stamp (e.g. "Jet10-1.0-20260428-1430") for the .dmg name.
APP_BASENAME="$(basename "$APP_PATH" .app)"
APP_BUNDLE_NAME="${APP_BASENAME%%-*}.app"   # strip "-<version>-<timestamp>" → "Jet10.app"
DMG_NAME="${DMG_NAME:-${APP_BASENAME}.dmg}"
DMG_PATH="$DIST_DIR/$DMG_NAME"

STAGING_DIR="$(mktemp -d "${TMPDIR:-/tmp}/menubard-dmg.XXXXXX")"

cleanup() {
  rm -rf "$STAGING_DIR"
}

trap cleanup EXIT

# Inside the DMG the bundle keeps the canonical name (e.g. "Jet10.app") so it
# installs to /Applications/<name>.app, not /Applications/<name>-<version>.app.
ditto "$APP_PATH" "$STAGING_DIR/$APP_BUNDLE_NAME"
ln -s /Applications "$STAGING_DIR/Applications"

rm -f "$DMG_PATH"
hdiutil create \
  -volname "${APP_BUNDLE_NAME%.app}" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

echo "Built dmg:"
echo "$DMG_PATH"
