#!/bin/bash
# Archive, export and upload __APP__ to TestFlight in one shot, no Xcode GUI.
#
# One-time prerequisites (see the skill's references/device-and-release.md):
#   1. An app record in App Store Connect for bundle id __BUNDLE_ID__.
#   2. An App Store Connect API key (App Manager role): .p8 file + Key ID + Issuer ID,
#      in a gitignored .asc.env (template: .asc.env.example) or the environment.
#
# Usage: tools/testflight-upload.sh [build-number]      (or: make testflight BUILD=...)
#
# The build number defaults to a UTC timestamp (YYYYMMDDHHMM) so every upload is unique
# and increasing. MARKETING_VERSION stays in project.yml; bump it by hand per release.
# If tools/release-gate.sh exists it runs against the archived .app before upload
# (e.g. to assert no dev API keys are in the Release Info.plist) and must exit 0.
set -euo pipefail
cd "$(dirname "$0")/.."
APP=__APP__

if [ -f .asc.env ]; then set -a; . ./.asc.env; set +a; fi
: "${ASC_KEY_ID:?Set ASC_KEY_ID (App Store Connect API Key ID), see .asc.env.example}"
: "${ASC_ISSUER_ID:?Set ASC_ISSUER_ID (App Store Connect Issuer ID)}"
: "${ASC_KEY_PATH:?Set ASC_KEY_PATH (path to AuthKey_*.p8)}"
ASC_KEY_PATH="${ASC_KEY_PATH/#\~/$HOME}"
[ -r "$ASC_KEY_PATH" ] || { echo "error: ASC_KEY_PATH not readable: $ASC_KEY_PATH" >&2; exit 1; }
AUTH=(-allowProvisioningUpdates -authenticationKeyID "$ASC_KEY_ID"
      -authenticationKeyIssuerID "$ASC_ISSUER_ID" -authenticationKeyPath "$ASC_KEY_PATH")

BUILD_NUMBER="${1:-$(date -u +%Y%m%d%H%M)}"
ARCHIVE="build/$APP.xcarchive"
EXPORT_DIR="build/export"

echo "==> Build number $BUILD_NUMBER"
/usr/bin/sed -i '' -E "s/^( *CURRENT_PROJECT_VERSION: *)\"[^\"]*\"/\1\"$BUILD_NUMBER\"/" project.yml
grep -E '^ *(MARKETING_VERSION|CURRENT_PROJECT_VERSION):' project.yml
xcodegen generate --quiet

echo "==> Archiving (Release)"
rm -rf "$ARCHIVE"
tools/xcb.sh -project "$APP.xcodeproj" -scheme "$APP" -configuration Release \
  -destination 'generic/platform=iOS' -archivePath "$ARCHIVE" "${AUTH[@]}" archive

if [ -x tools/release-gate.sh ]; then
  echo "==> Release gate"
  tools/release-gate.sh "$ARCHIVE/Products/Applications/$APP.app"
fi

echo "==> Exporting + uploading"
rm -rf "$EXPORT_DIR"
tools/xcb.sh -exportArchive -archivePath "$ARCHIVE" -exportPath "$EXPORT_DIR" \
  -exportOptionsPlist ExportOptions.plist "${AUTH[@]}"

echo "==> Uploaded build $BUILD_NUMBER. It shows in App Store Connect → TestFlight after"
echo "    processing (a few minutes); internal testers get it automatically."
