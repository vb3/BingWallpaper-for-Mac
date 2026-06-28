import AppKit
import Foundation
import OSLog

private let logger = Logger(
    subsystem: Logging.subsystem,
    category: Logging.Category.Wallpaper.rawValue
)

@MainActor
class WallpaperManager {
    private var imageDescriptor: ImageDescriptor?
    static let shared = WallpaperManager()
    
    private init() {
        setupObserver()
    }
    
    private func setupObserver() {
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(WallpaperManager.activeWorkspaceDidChange),
            name: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(WallpaperManager.workspaceDidWake),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(WallpaperManager.screenParametersDidChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }
    
    @objc func activeWorkspaceDidChange() {
        updateWallpaperIfNeeded()
    }
    
    @objc func workspaceDidWake() {
        updateWallpaperIfNeeded()
    }
    
    @objc func screenParametersDidChange() {
        updateWallpaperIfNeeded()
    }
    
    @discardableResult
    func setWallpaper(descriptor: ImageDescriptor) -> Bool {
        imageDescriptor = descriptor
        return updateWallpaperIfNeeded()
    }

    @discardableResult
    private func updateWallpaperIfNeeded() -> Bool {
        guard let descriptor = imageDescriptor else { return false }
        let imageUrl = Image.downloadPath(for: descriptor)
        let workspace = NSWorkspace.shared
        let targetPath = imageUrl.standardizedFileURL.path

        var didFail = false
        for screen in NSScreen.screens {
            // macOS keeps a separate wallpaper per Space, so the current image
            // must be queried live for each screen (never cached): a newly
            // created Space reports a different/absent URL and still gets set.
            if workspace.desktopImageURL(for: screen)?.standardizedFileURL.path == targetPath {
                continue
            }
            do {
                try workspace.setDesktopImageURL(imageUrl, for: screen, options: [:])
            } catch {
                logger.error("Failed to set desktop image: \(error.localizedDescription)")
                didFail = true
            }
        }
        // Treat "already matching on every screen" as success; only a thrown
        // setDesktopImageURL counts as a failure.
        return didFail == false
    }
}
