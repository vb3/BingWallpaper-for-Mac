import Cocoa

class SettingsWc: NSWindowController {
    
    override func windowDidLoad() {
        super.windowDidLoad()
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        self.window?.title = "BingWallpaper v\(version)"
        self.window?.titleVisibility = .visible
    }
    
    static func instance() -> SettingsWc {
        let mainStoryboard = NSStoryboard(name: NSStoryboard.Name("Main"), bundle: nil)
        let identifier = NSStoryboard.SceneIdentifier(String(describing: self))
        guard let windowController = mainStoryboard.instantiateController(withIdentifier: identifier) as? SettingsWc else {
            fatalError("Main.storyboard is missing a \(identifier) scene of type SettingsWc")
        }
        return windowController
    }
}
