#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$ROOT_DIR/.DerivedData/Release}"
DIST_DIR="${DIST_DIR:-$ROOT_DIR/dist}"
PROJECT_PATH="$ROOT_DIR/MenuBard.xcodeproj"
SCHEME="MenuBard"
APP_NAME="Just10.app"
APP_SOURCE_PATH="$DERIVED_DATA_PATH/Build/Products/Release/$APP_NAME"
APP_OUTPUT_PATH="$DIST_DIR/$APP_NAME"

mkdir -p "$DIST_DIR"

xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -configuration Release \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  build

rm -rf "$APP_OUTPUT_PATH"
ditto "$APP_SOURCE_PATH" "$APP_OUTPUT_PATH"

echo "Built app:"
echo "$APP_OUTPUT_PATH"
