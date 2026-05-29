#!/usr/bin/env bash
# Build, sign, notarize and staple a distributable Vellem.dmg.
#
# Prerequisites (one-time):
#   1. Active Apple Developer Program ($99/yr)
#   2. Developer ID Application certificate installed in your Keychain
#      (Xcode → Settings → Accounts → Manage Certificates → + → "Developer ID Application")
#   3. Notary credentials stored in Keychain:
#        xcrun notarytool store-credentials vellem-notary \
#          --apple-id "your.apple.id@example.com" \
#          --team-id MKAFV9VL9V \
#          --password "xxxx-xxxx-xxxx-xxxx"  # app-specific password from appleid.apple.com
#
# Then run: ./script/release.sh
#
# Output: dist/Vellem-<version>.dmg (notarized, stapled, ready to upload to GitHub Releases)

set -euo pipefail

# ---------- Config ----------
APP_NAME="Vellem"
SCHEME="Vellem"
PROJECT="Vellem.xcodeproj"
TEAM_ID="MKAFV9VL9V"
SIGN_IDENTITY="Developer ID Application: Adrien DONOT (${TEAM_ID})"
NOTARY_PROFILE="vellem-notary"

DIST_DIR="dist"
DERIVED_DIR="build/release-derived"
EXPORT_DIR="${DIST_DIR}/export"

# Version: read from Vellem/Info.plist (CFBundleShortVersionString) or override with $VERSION
VERSION="${VERSION:-$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Vellem/Info.plist 2>/dev/null || echo '1.0.0')}"
DMG_NAME="${APP_NAME}-${VERSION}.dmg"
DMG_PATH="${DIST_DIR}/${DMG_NAME}"

# ---------- Pre-flight ----------
echo "▶ Vellem release pipeline v${VERSION}"
echo ""

if ! security find-identity -v -p codesigning | grep -q "${SIGN_IDENTITY}"; then
  echo "❌ Missing signing identity: ${SIGN_IDENTITY}"
  echo "   Create one in Xcode → Settings → Accounts → Manage Certificates → + → 'Developer ID Application'"
  exit 1
fi

if ! xcrun notarytool history --keychain-profile "${NOTARY_PROFILE}" >/dev/null 2>&1; then
  echo "❌ Notary profile '${NOTARY_PROFILE}' not found in Keychain."
  echo "   Run: xcrun notarytool store-credentials ${NOTARY_PROFILE} --apple-id <email> --team-id ${TEAM_ID} --password <app-specific-password>"
  exit 1
fi

mkdir -p "${DIST_DIR}" "${EXPORT_DIR}"
rm -rf "${DERIVED_DIR}"

# ---------- Build with Developer ID ----------
# We pin SYMROOT to force xcodebuild's output into our local DERIVED_DIR even when
# the user has a custom DerivedData location set in Xcode Preferences.
echo "▶ Building Release with Developer ID signing…"
xcodebuild \
  -project "${PROJECT}" \
  -scheme "${SCHEME}" \
  -configuration Release \
  -destination 'platform=macOS' \
  -derivedDataPath "${DERIVED_DIR}" \
  -allowProvisioningUpdates \
  SYMROOT="${PWD}/${DERIVED_DIR}/Build/Products" \
  OBJROOT="${PWD}/${DERIVED_DIR}/Build/Intermediates.noindex" \
  CODE_SIGN_STYLE=Automatic \
  DEVELOPMENT_TEAM="${TEAM_ID}" \
  OTHER_CODE_SIGN_FLAGS="--timestamp --options=runtime" \
  build 2>&1 | tail -10

# Resolve the actual built app via showBuildSettings (handles custom DerivedData).
BUILT_PRODUCTS_DIR=$(xcodebuild -project "${PROJECT}" -scheme "${SCHEME}" -configuration Release \
  -derivedDataPath "${DERIVED_DIR}" \
  SYMROOT="${PWD}/${DERIVED_DIR}/Build/Products" \
  OBJROOT="${PWD}/${DERIVED_DIR}/Build/Intermediates.noindex" \
  -showBuildSettings 2>/dev/null \
  | awk -F' = ' '/^[[:space:]]*BUILT_PRODUCTS_DIR =/ {print $2; exit}')

BUILT_APP="${BUILT_PRODUCTS_DIR}/${APP_NAME}.app"
if [ ! -d "${BUILT_APP}" ]; then
  echo "❌ Build failed: ${BUILT_APP} not found"
  echo "   BUILT_PRODUCTS_DIR=${BUILT_PRODUCTS_DIR}"
  exit 1
fi
echo "  → built: ${BUILT_APP}"

# ---------- Sign nested binaries inside-out with Developer ID + hardened runtime ----------
# We do NOT use --deep on the outer bundle because that would overwrite Sparkle's
# XPC service entitlements with the host app's sandbox entitlements, breaking
# the installer. Instead, sign each component individually with the right options.

SPARKLE_FW="${BUILT_APP}/Contents/Frameworks/Sparkle.framework"

# Sparkle XPC services: preserve their original entitlements, re-sign with Developer ID + timestamp
for xpc in "${SPARKLE_FW}/Versions/B/XPCServices/Downloader.xpc" \
           "${SPARKLE_FW}/Versions/B/XPCServices/Installer.xpc"; do
  if [ -d "$xpc" ]; then
    echo "▶ Signing $(basename "$xpc")…"
    codesign --force --sign "${SIGN_IDENTITY}" \
      --options runtime --timestamp \
      --preserve-metadata=entitlements \
      "$xpc"
  fi
done

# Sparkle Updater.app and Autoupdate helper
if [ -d "${SPARKLE_FW}/Versions/B/Updater.app" ]; then
  echo "▶ Signing Sparkle Updater.app…"
  codesign --force --sign "${SIGN_IDENTITY}" \
    --options runtime --timestamp \
    "${SPARKLE_FW}/Versions/B/Updater.app"
fi

if [ -f "${SPARKLE_FW}/Versions/B/Autoupdate" ]; then
  echo "▶ Signing Sparkle Autoupdate helper…"
  codesign --force --sign "${SIGN_IDENTITY}" \
    --options runtime --timestamp \
    "${SPARKLE_FW}/Versions/B/Autoupdate"
fi

# Re-seal the Sparkle framework itself
echo "▶ Re-sealing Sparkle.framework…"
codesign --force --sign "${SIGN_IDENTITY}" \
  --options runtime --timestamp \
  "${SPARKLE_FW}/Versions/B"

# Embedded MCP CLI binary
EMBEDDED_MCP="${BUILT_APP}/Contents/Resources/vellem-mcp"
if [ -f "${EMBEDDED_MCP}" ]; then
  echo "▶ Signing vellem-mcp…"
  codesign --force --sign "${SIGN_IDENTITY}" \
    --options runtime --timestamp \
    "${EMBEDDED_MCP}"
fi

# Widget extension - sign with its own entitlements (strips any stray get-task-allow)
WIDGET_EXT="${BUILT_APP}/Contents/PlugIns/VellemWidget.appex"
if [ -d "${WIDGET_EXT}" ]; then
  echo "▶ Signing VellemWidget.appex…"
  codesign --force --sign "${SIGN_IDENTITY}" \
    --options runtime --timestamp \
    --entitlements VellemWidget/VellemWidget.entitlements \
    "${WIDGET_EXT}"
fi

# Finally, re-seal the outer .app with the host entitlements (no --deep)
echo "▶ Re-sealing outer .app bundle…"
codesign --force --sign "${SIGN_IDENTITY}" \
  --options runtime --timestamp \
  --entitlements Vellem/Vellem.entitlements \
  "${BUILT_APP}"

codesign --verify --deep --strict --verbose=2 "${BUILT_APP}"

# ---------- Stage app into a clean folder for the DMG ----------
echo "▶ Staging for DMG…"
STAGING="${DIST_DIR}/staging"
rm -rf "${STAGING}"
mkdir -p "${STAGING}"
cp -R "${BUILT_APP}" "${STAGING}/"
ln -s /Applications "${STAGING}/Applications"

# ---------- Create DMG ----------
echo "▶ Creating ${DMG_PATH}…"
rm -f "${DMG_PATH}"
hdiutil create \
  -volname "${APP_NAME}" \
  -srcfolder "${STAGING}" \
  -ov -format UDZO \
  "${DMG_PATH}"

# ---------- Sign the DMG ----------
echo "▶ Signing DMG…"
codesign --force --sign "${SIGN_IDENTITY}" --timestamp "${DMG_PATH}"

# ---------- Notarize ----------
echo "▶ Submitting to Apple notary service (this can take 1–10 min)…"
xcrun notarytool submit "${DMG_PATH}" \
  --keychain-profile "${NOTARY_PROFILE}" \
  --wait

# ---------- Staple ----------
echo "▶ Stapling notarization ticket to DMG…"
xcrun stapler staple "${DMG_PATH}"
xcrun stapler validate "${DMG_PATH}"

# ---------- Sparkle: sign DMG + update appcast.xml ----------
SPARKLE_BIN="$(find "$HOME/Library/Developer/Xcode/DerivedData" \
  -path '*sparkle/Sparkle/bin/sign_update' -type f 2>/dev/null | head -1)"
APPCAST="appcast.xml"
BUILD_NUMBER="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' Vellem/Info.plist)"
DMG_URL="https://github.com/pulssart/vellem/releases/download/v${VERSION}/${DMG_NAME}"

if [ -n "${SPARKLE_BIN}" ] && [ -f "${APPCAST}" ]; then
  echo "▶ Signing DMG with Sparkle Ed25519 key…"
  SIG_LINE="$("${SPARKLE_BIN}" "${DMG_PATH}")"
  echo "   ${SIG_LINE}"
  PUB_DATE="$(LC_TIME=en_US.UTF-8 date '+%a, %d %b %Y %H:%M:%S %z')"

  ITEM=$(cat <<EOF
        <item>
            <title>Version ${VERSION}</title>
            <sparkle:version>${BUILD_NUMBER}</sparkle:version>
            <sparkle:shortVersionString>${VERSION}</sparkle:shortVersionString>
            <sparkle:minimumSystemVersion>26.0</sparkle:minimumSystemVersion>
            <pubDate>${PUB_DATE}</pubDate>
            <enclosure url="${DMG_URL}" ${SIG_LINE} type="application/octet-stream" />
        </item>
EOF
)

  echo "▶ Inserting <item> into ${APPCAST}…"
  python3 -c "
import sys, re
path = '${APPCAST}'
item = '''${ITEM}
'''
with open(path) as f:
    src = f.read()
if 'sparkle:shortVersionString>${VERSION}<' in src:
    print('   already in appcast, skipping')
    sys.exit(0)
src = re.sub(r'(<language>[^<]*</language>)', r'\1\n' + item, src, count=1)
with open(path, 'w') as f:
    f.write(src)
print('   inserted')
"
fi

# ---------- Cleanup ----------
rm -rf "${STAGING}" "${EXPORT_DIR}"

echo ""
echo "✅ Done: ${DMG_PATH}"
echo "   SHA-256: $(shasum -a 256 "${DMG_PATH}" | awk '{print $1}')"
echo ""
echo "Next steps:"
echo "  1. git add appcast.xml && git commit -m 'Release v${VERSION}' && git push"
echo "  2. gh release create v${VERSION} ${DMG_PATH} --title \"Vellem ${VERSION}\" --notes-file CHANGELOG.md"
