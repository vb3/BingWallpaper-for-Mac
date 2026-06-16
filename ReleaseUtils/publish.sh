#!/bin/sh
#
# One-command release: build, publish a GitHub release, and bump the Homebrew tap.
#
# Runs locally on macOS using your existing git/gh credentials — no tokens or CI
# secrets. The version is read from the Xcode project (MARKETING_VERSION).
#
# Usage:
#   ReleaseUtils/publish.sh
#
# Environment overrides:
#   TAP_DIR   path to the cloned homebrew-tap (default: ../homebrew-tap)
#   REPO      GitHub repo to release into (default: vb3/BingWallpaper-for-Mac)
#
set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)
cd "$REPO_ROOT"

TAP_DIR=${TAP_DIR:-"$REPO_ROOT/../homebrew-tap"}
REPO=${REPO:-"vb3/BingWallpaper-for-Mac"}
CASK="$TAP_DIR/Casks/bingwallpaper.rb"

command -v gh >/dev/null 2>&1     || { echo "error: gh CLI not found" >&2; exit 1; }
command -v shasum >/dev/null 2>&1 || { echo "error: shasum not found" >&2; exit 1; }
[ -f "$CASK" ] || { echo "error: cask not found at $CASK (set TAP_DIR)" >&2; exit 1; }

# Resolve the version and its release notes up front so we fail fast — before a
# full build — if notes are missing. Version is read the same way release.sh does.
VERSION=$(awk -F '=' '/MARKETING_VERSION/ {
    gsub(/[ \t;]/, "", $2)
    if ($2 ~ /^[0-9]+\.[0-9]+/) { print $2; exit }
}' BingWallpaper.xcodeproj/project.pbxproj)
[ -n "$VERSION" ] || { echo "error: could not determine MARKETING_VERSION" >&2; exit 1; }
TAG="v${VERSION}"

NOTES_FILE=${NOTES_FILE:-"$REPO_ROOT/ReleaseUtils/release-notes/${TAG}.md"}
[ -s "$NOTES_FILE" ] || {
  echo "error: release notes missing or empty: $NOTES_FILE" >&2
  echo "       write the notes there (see existing files in ReleaseUtils/release-notes/)," >&2
  echo "       or point NOTES_FILE=/path/to/notes.md at them, then re-run." >&2
  exit 1
}

# 1. Build + package. release.sh prints VERSION / ZIP / PKG / SHA256.
BUILD_OUT=$("$SCRIPT_DIR/release.sh")
echo "$BUILD_OUT"
VERSION=$(printf '%s\n' "$BUILD_OUT" | sed -n 's/^VERSION=//p')
ZIP=$(printf '%s\n' "$BUILD_OUT" | sed -n 's/^ZIP=//p')
PKG=$(printf '%s\n' "$BUILD_OUT" | sed -n 's/^PKG=//p')
SHA=$(printf '%s\n' "$BUILD_OUT" | sed -n 's/^SHA256=//p')
TAG="v${VERSION}"

[ -n "$VERSION" ] && [ -n "$ZIP" ] && [ -n "$SHA" ] || {
  echo "error: release.sh did not report VERSION/ZIP/SHA256" >&2; exit 1
}

# 2. Publish the GitHub release (create if missing; otherwise refresh assets + notes).
if gh release view "$TAG" --repo "$REPO" >/dev/null 2>&1; then
  echo "Release $TAG already exists; uploading assets (--clobber) and refreshing notes"
  gh release upload "$TAG" "$ZIP" "$PKG" --repo "$REPO" --clobber
  gh release edit "$TAG" --repo "$REPO" --notes-file "$NOTES_FILE"
else
  git tag -a "$TAG" -m "BingWallpaper $VERSION" 2>/dev/null || true
  git push origin "$TAG"
  gh release create "$TAG" "$ZIP" "$PKG" \
    --repo "$REPO" \
    --title "BingWallpaper $VERSION" \
    --notes-file "$NOTES_FILE"
fi

# 3. Bump the Homebrew cask (version + sha256) in the tap.
sed -i '' \
  -e "s/^  version \".*\"/  version \"${VERSION}\"/" \
  -e "s/^  sha256 \".*\"/  sha256 \"${SHA}\"/" \
  "$CASK"

# 4. Validate locally (full cask support on macOS).
if command -v brew >/dev/null 2>&1; then
  brew style "$CASK" || true
  brew audit --cask "$CASK" || true
fi

# 5. Commit & push the tap with your own git credentials.
if git -C "$TAP_DIR" diff --quiet -- "$CASK"; then
  echo "Cask already at ${VERSION}; nothing to commit"
else
  git -C "$TAP_DIR" add "$CASK"
  git -C "$TAP_DIR" commit -m "bingwallpaper: update to ${VERSION}"
  git -C "$TAP_DIR" push
  echo "Tap bumped to ${VERSION}"
fi

echo ""
echo "Published ${TAG} and updated the tap. Verify with:"
echo "  brew update && brew upgrade --cask bingwallpaper"
