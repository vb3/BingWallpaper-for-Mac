import Cocoa

// TODO: @2h4u create and add a custom menu-bar icon (app icon added)

@main
@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    private let menuController = MenuController()

    /// Posted by a duplicate launch to ask the already-running instance to
    /// surface its Settings window. Delivered via `DistributedNotificationCenter`,
    /// which is permitted here because both processes share this app's sandbox
    /// identity (same bundle id / container).
    private static let focusExistingInstanceNotification = Notification.Name("com.vb3.BingWallpaper.focusExistingInstance")

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        if terminateIfAnotherInstanceIsRunning() { return }

        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(focusExistingInstance),
            name: AppDelegate.focusExistingInstanceNotification,
            object: nil
        )

        FileHandler.createWallpaperFolderIfNeeded()
        
        let updateManager = UpdateManager()
        updateManager.delegate = menuController
        updateManager.start()
        
        menuController.updateManager = updateManager
        menuController.setup()
    }

    /// Enforces a single running instance. If another copy is already running,
    /// nudges it to show Settings and terminates this newcomer before it sets up
    /// a second menu-bar icon. Returns `true` when this instance is bowing out.
    private func terminateIfAnotherInstanceIsRunning() -> Bool {
        // The unit-test host shares this bundle id; exiting would kill the test
        // runner, so never enforce single-instance under XCTest.
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            return false
        }

        guard let bundleID = Bundle.main.bundleIdentifier else { return false }

        let others = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            .filter { $0 != .current }
        guard others.isEmpty == false else { return false }

        DistributedNotificationCenter.default().postNotificationName(
            AppDelegate.focusExistingInstanceNotification,
            object: nil,
            userInfo: nil,
            deliverImmediately: true
        )

        // Exit immediately so the duplicate never touches the shared SwiftData
        // store or installs a second status item.
        exit(0)
    }

    @objc private func focusExistingInstance() {
        menuController.showSettingsWc(sender: nil)
    }

    /// Re-opening the app (e.g. launching it again while it's already running)
    /// surfaces Settings, since there's no Dock icon or main window.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        menuController.showSettingsWc(sender: nil)
        return true
    }
    
    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
    
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        try? Database.instance.container.mainContext.save()
        return .terminateNow
    }
}
