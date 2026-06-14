import Cocoa

// TODO: @2h4u create and add icon (app icon and menubar icon)

@main
@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    private let menuController = MenuController()
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        FileHandler.createWallpaperFolderIfNeeded()
        
        let updateManager = UpdateManager()
        updateManager.delegate = menuController
        updateManager.start()
        
        menuController.updateManager = updateManager
        menuController.setup()
    }
    
    func applicationDidBecomeActive(_ notification: Notification) {
        menuController.showSettingsWc(sender: nil)
    }
    
    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
    
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        try? Database.instance.container.mainContext.save()
        return .terminateNow
    }
}
