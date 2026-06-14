import Cocoa

class SettingsWc: NSWindowController {
    
    override func windowDidLoad() {
        super.windowDidLoad()
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        self.window?.title = "BingWallpaper v\(version)"
        self.window?.titleVisibility = .visible
    }
    
    static func instance() -> SettingsWc {
        let mainStoryboard = NSStoryboard.init(name: NSStoryboard.Name("Main"), bundle: nil)
        return mainStoryboard.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier(String(describing: self))) as! SettingsWc
    }
}
