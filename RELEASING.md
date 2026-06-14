# Releasing

Releases are cut **locally on macOS** and published to GitHub Releases; the Homebrew cask
in [vb3/homebrew-tap](https://github.com/vb3/homebrew-tap) is bumped in the same step.
No CI, runners, tokens, or secrets are involved — everything uses your own `git`/`gh` credentials.

## Prerequisites

- Xcode (macOS 14+ SDK).
- `gh` authenticated — check with `gh auth status`.
- The tap cloned next to this repo (default `../homebrew-tap`), or point `TAP_DIR` at it.
- Homebrew (for local `brew style` / `brew audit` validation).

## Cut a release

1. Bump `MARKETING_VERSION` in `BingWallpaper.xcodeproj` — this is the single source of truth
   for the version.
2. Commit and push the app repo.
3. Run:
   ```sh
   ./ReleaseUtils/publish.sh
   ```
   This will:
   - build an ad-hoc / unsigned `BingWallpaper.app` (notarization is intentionally skipped),
   - produce `BingWallpaper_v<VERSION>.zip` (the cask asset) and `.pkg` (optional installer),
   - tag `v<VERSION>` and create/refresh the GitHub release with both assets,
   - update `version` + `sha256` in the tap's `Casks/bingwallpaper.rb`,
   - run `brew style` / `brew audit --cask`, then commit & push the tap.

Override the tap location or repo if needed:
```sh
TAP_DIR=/path/to/homebrew-tap ./ReleaseUtils/publish.sh
```

## Release contract (do not break)

The cask's `url` and `livecheck` depend on this exact naming:

- Git tag: `v<X.Y.Z>` (e.g. `v0.5.4`).
- Zip asset: `BingWallpaper_v<X.Y.Z>.zip`, containing `BingWallpaper.app` at the top level.

If you ever change either, update `Casks/bingwallpaper.rb` in the tap to match.

## Build only (no publish)

```sh
./ReleaseUtils/release.sh
```

Prints `VERSION`, `ZIP`, `PKG`, and `SHA256` — handy for manually updating the cask.

## Notarization

Currently skipped: builds are ad-hoc signed, and the cask strips the download quarantine on
install so Gatekeeper doesn't block first launch. If you later add a Developer ID signature +
notarization, drop the `postflight`/`caveats` quarantine handling from the cask.
