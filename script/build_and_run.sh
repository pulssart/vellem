#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="Vellem"
PROJECT_NAME="Vellem.xcodeproj"
SCHEME="Vellem"
CONFIGURATION="Debug"
BUNDLE_ID="com.adriendonot.Vellem"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DERIVED_DATA="$ROOT_DIR/build/DerivedData"
INSTALL_DIR="/Applications"
INSTALLED_APP_BUNDLE="$INSTALL_DIR/$APP_NAME.app"
MAC_GROUP_NOTES="$HOME/Library/Group Containers/MKAFV9VL9V.com.adriendonot.Vellem/notes.json"
LEGACY_GROUP_NOTES="$HOME/Library/Group Containers/group.com.adriendonot.Vellem/notes.json"
APP_SUPPORT_NOTES="$HOME/Library/Application Support/Vellem/notes.json"

cd "$ROOT_DIR"

pkill -x "$APP_NAME" >/dev/null 2>&1 || true

if command -v xcodegen >/dev/null 2>&1; then
  xcodegen generate
fi

xcodebuild \
  -project "$PROJECT_NAME" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -destination "platform=macOS" \
  -derivedDataPath "$DERIVED_DATA" \
  build

TARGET_BUILD_DIR="$(
  xcodebuild \
    -project "$PROJECT_NAME" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -destination "platform=macOS" \
    -derivedDataPath "$DERIVED_DATA" \
    -showBuildSettings 2>/dev/null |
    awk -F' = ' '/TARGET_BUILD_DIR = / { print $2; exit }'
)"
APP_BUNDLE="$TARGET_BUILD_DIR/$APP_NAME.app"
BUILT_WIDGET="$APP_BUNDLE/Contents/PlugIns/${APP_NAME}Widget.appex"
INSTALLED_WIDGET="$INSTALLED_APP_BUNDLE/Contents/PlugIns/${APP_NAME}Widget.appex"

merge_notes() {
  local tmp_file
  local note_files=()
  tmp_file="$(mktemp)"

  for note_file in "$MAC_GROUP_NOTES" "$LEGACY_GROUP_NOTES" "$APP_SUPPORT_NOTES"; do
    if [ -f "$note_file" ]; then
      note_files+=("$note_file")
    fi
  done

  if [ "${#note_files[@]}" -eq 0 ]; then
    rm -f "$tmp_file"
    return
  fi

  /opt/homebrew/bin/jq -s 'add | unique_by(.id) | sort_by(.updatedAt) | reverse' \
    "${note_files[@]}" \
    2>/dev/null > "$tmp_file" || true

  if [ -s "$tmp_file" ]; then
    mkdir -p "$(dirname "$MAC_GROUP_NOTES")"
    mv "$tmp_file" "$MAC_GROUP_NOTES"
  else
    rm -f "$tmp_file"
  fi
}

open_app() {
  mkdir -p "$INSTALL_DIR"
  rm -rf "$INSTALLED_APP_BUNDLE"
  /usr/bin/ditto "$APP_BUNDLE" "$INSTALLED_APP_BUNDLE"
  merge_notes
  if [ -d "$BUILT_WIDGET" ]; then
    /usr/bin/pluginkit -r "$BUILT_WIDGET" >/dev/null 2>&1 || true
  fi
  /System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister -f -R -trusted "$INSTALLED_APP_BUNDLE"
  if [ -d "$INSTALLED_WIDGET" ]; then
    /usr/bin/pluginkit -a "$INSTALLED_WIDGET" >/dev/null 2>&1 || true
  fi
  /usr/bin/open -n "$INSTALLED_APP_BUNDLE"
}

case "$MODE" in
  run)
    open_app
    ;;
  --debug|debug)
    lldb -- "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
    ;;
  --logs|logs)
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry|telemetry)
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify|verify)
    open_app
    sleep 1
    pgrep -x "$APP_NAME" >/dev/null
    echo "$APP_NAME is running from $INSTALLED_APP_BUNDLE"
    ;;
  *)
    echo "usage: $0 [run|--debug|--logs|--telemetry|--verify]" >&2
    exit 2
    ;;
esac
