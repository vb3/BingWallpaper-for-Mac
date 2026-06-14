#!/bin/sh
#
# Build BingWallpaper and produce versioned release artifacts:
#   BingWallpaper_v<VERSION>.zip   (consumed by the Homebrew cask)
#   BingWallpaper_v<VERSION>.pkg   (optional direct-download installer)
#
# The build is ad-hoc / unsigned (notarization intentionally skipped for now).
# Prints VERSION / ZIP / PKG / SHA256 at the end for the cask bump.
#
set -eu

# Always run from the repo root, regardless of where this is invoked from.
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
cd "$SCRIPT_DIR/.."

# Version comes from the Xcode project (single source of truth).
VERSION=$(awk -F '=' '/MARKETING_VERSION/ {
    gsub(/[ \t;]/, "", $2)
    if ($2 ~ /^[0-9]+\.[0-9]+/) { print $2; exit }
}' BingWallpaper.xcodeproj/project.pbxproj)

if [ -z "${VERSION}" ]; then
    echo "error: could not determine MARKETING_VERSION from project.pbxproj" >&2
    exit 1
fi
echo "Building BingWallpaper ${VERSION}"

DERIVED="./build"
APP="${DERIVED}/Build/Products/Release/BingWallpaper.app"
ZIP="BingWallpaper_v${VERSION}.zip"
PKG="BingWallpaper_v${VERSION}.pkg"

# Build
xcodebuild clean build \
    -project BingWallpaper.xcodeproj \
    -scheme BingWallpaper \
    -configuration Release \
    -derivedDataPath "${DERIVED}" \
    CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO

if [ ! -d "${APP}" ]; then
    echo "error: build did not produce ${APP}" >&2
    exit 1
fi

# ZIP (ditto preserves bundle symlinks/metadata better than `zip -r`)
rm -f "${ZIP}"
ditto -c -k --sequesterRsrc --keepParent "${APP}" "${ZIP}"

# PKG
rm -f "${PKG}"
pkgbuild --component "${APP}" \
         --scripts ./ReleaseUtils/pkg-scripts \
         --install-location /Applications \
         "${PKG}"

SHA=$(shasum -a 256 "${ZIP}" | awk '{print $1}')

echo ""
echo "Done"
echo "VERSION=${VERSION}"
echo "ZIP=${ZIP}"
echo "PKG=${PKG}"
echo "SHA256=${SHA}"
