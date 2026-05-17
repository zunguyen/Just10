#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$ROOT_DIR/.DerivedData/Release}"
DIST_DIR="${DIST_DIR:-$ROOT_DIR/dist}"
PROJECT_PATH="$ROOT_DIR/MenuBard.xcodeproj"
SCHEME="MenuBard"

mkdir -p "$DIST_DIR"

# Resolve the actual built product name (e.g., "Just10.app") from build settings,
# so the script stays correct if PRODUCT_NAME changes in the project.
APP_NAME=$(xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -configuration Release \
  -showBuildSettings 2>/dev/null \
  | awk -F' = ' '$1 ~ /[[:space:]]+FULL_PRODUCT_NAME$/ {print $2; exit}')

if [[ -z "$APP_NAME" ]]; then
  echo "Failed to resolve FULL_PRODUCT_NAME from xcodebuild settings." >&2
  exit 1
fi

APP_SOURCE_PATH="$DERIVED_DATA_PATH/Build/Products/Release/$APP_NAME"

xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -configuration Release \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  build

PACKAGE_DATE=$(date +%d-%m-%y)
APP_BASENAME="${APP_NAME%.app}"
STAMP="$PACKAGE_DATE"
APP_OUTPUT_PATH="$DIST_DIR/${APP_BASENAME}-${STAMP}.app"

rm -rf "$APP_OUTPUT_PATH"
ditto "$APP_SOURCE_PATH" "$APP_OUTPUT_PATH"

# Hand off the stamped artifact path so package-dmg.sh names the .dmg with the same stamp.
printf '%s\n' "$APP_OUTPUT_PATH" > "$DIST_DIR/.last-build"

echo "Built app:"
echo "$APP_OUTPUT_PATH"
