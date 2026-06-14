# Bing Wallpaper for Mac

<p align="center">
  <img width="400" alt="screenshot" src="https://user-images.githubusercontent.com/4823365/181782535-6235edf9-5e70-4861-96df-b4e2719482cf.png">
</p>

**BingWallpaper** is a lightweight menu-bar app for macOS that automatically downloads the
[Bing wallpaper of the day](https://www.microsoft.com/bing/bing-wallpaper) in full UHD resolution
and sets it as the desktop picture across **all of your monitors and Spaces**.

It lives quietly in the menu bar, refreshes itself in the background, and keeps a short history of
recent wallpapers you can browse through.

## Features

- 🖼️ **Daily wallpaper, automatically** — fetches the newest Bing image and applies it to every display.
- 🕑 **Browse recent days** — flip back through the last several days right from the menu bar.
- 🔗 **Image info** — click the caption to open the photo's description/credit on Bing.
- 🖥️ **Multi-monitor aware** — applies the wallpaper to newly connected external displays automatically.
- 🚀 **Launch at login** — optional, so it's ready every time you sign in.
- 🧹 **Automatic cleanup** — keep the last 5 / 10 / 50 / 100 days of images, or keep them forever.
- 🔕 **Stays out of the way** — menu-bar only (no Dock icon), no accounts, no tracking.

## Requirements

- macOS **14.0 (Sonoma)** or later
- Apple Silicon or Intel Mac

## Install

1. Download the latest `BingWallpaper_vX.Y.Z.zip` (or `.pkg`) from the
   [**Releases**](https://github.com/vb3/BingWallpaper-for-Mac/releases) page.
2. For the `.zip`: unzip and move **BingWallpaper.app** to your `Applications` folder.
   For the `.pkg`: double-click and follow the installer.
3. Launch it. A 🖼️ icon appears in your menu bar and today's wallpaper is applied.

> **First-launch note:** release builds are signed ad-hoc (not notarized by Apple), so macOS
> Gatekeeper may warn that the developer can't be verified. To open it the first time,
> **right-click the app → Open → Open**, or run `xattr -dr com.apple.quarantine /Applications/BingWallpaper.app`.

## Usage

Click the menu-bar icon to:

- **◀ / ▶** — browse and apply a wallpaper from a previous day.
- **Refresh Images** — fetch the latest image now.
- **Settings (⌘,)** — launch at login, hide the menu-bar icon, choose how many days of images to
  keep, or reset the local image database.
- **Quit (⌘Q)**.

Wallpapers are stored in `~/Pictures/bing-wallpapers/`. When a new day's image is downloaded, it is
applied automatically (overriding a manual back-in-time selection).

## Updating

BingWallpaper does **not** update itself — there is no built-in self-updater, which keeps the app's
security model simple (it never reaches out to download or launch installers on its own). To update,
download the latest build from the
[Releases page](https://github.com/vb3/BingWallpaper-for-Mac/releases) and replace the app.

## Privacy & security

- Runs inside the macOS **App Sandbox**.
- Network access is used only to fetch images from Bing.
- Writes only to your Pictures folder. No analytics, no accounts, no background phone-home.

## Building from source

```sh
git clone https://github.com/vb3/BingWallpaper-for-Mac.git
cd BingWallpaper-for-Mac
open BingWallpaper.xcodeproj
```

Build & run the **BingWallpaper** scheme in Xcode (15+/macOS 14 SDK). The project uses the Swift 6
language mode, SwiftUI, and SwiftData — no external dependencies or package manager required.

To run the test suite:

```sh
xcodebuild -project BingWallpaper.xcodeproj -scheme BingWallpaper \
  -destination 'platform=macOS' test
```

## Credits

A fork of [**2h4u/BingWallpaper-for-Mac**](https://github.com/2h4u/BingWallpaper-for-Mac).
Bing and the daily images are property of Microsoft.
