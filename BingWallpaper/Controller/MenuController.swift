import Cocoa
import OSLog
import SwiftUI

private let logger = Logger(
    subsystem: Logging.subsystem,
    category: Logging.Category.Menu.rawValue
)

@MainActor
class MenuController: NSObject {
    private var statusItem: NSStatusItem?
    private var menu: NSMenu?
    private let settings = Settings()
    private var descriptors = [ImageDescriptor]()
    private var selectedDescriptorIndex = 0
    private var imageSelectorView: ImageSelectorView!
    var updateManager: UpdateManager?
    private static let IMAGE_VIEW_TAG = 6
    private static let TEXT_VIEW_TAG = 7
    private var settingsWindow: NSWindow?
    private lazy var settingsModel = SettingsViewModel()
    
    // MARK: - UI setup
    
    @MainActor
    func setup() {
        guard self.statusItem == nil && self.menu == nil else { return }
        if settings.hideMenuBarIcon == true { return }
        
        self.statusItem = createStatusBarItem()
        self.menu = createMenu()
        self.statusItem!.menu = menu
        
        showNewestImage()
    }
    
    private func createStatusBarItem() -> NSStatusItem {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "photo.artframe", accessibilityDescription: "BingWallpaper")
        }
        
        return statusItem
    }
    
    private func createMenu() -> NSMenu {
        let menu = NSMenu()
        menu.delegate = self
        menu.minimumWidth = 300
        
        let imageItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        imageSelectorView = ImageSelectorView(frame: CGRect(x: 0, y: 0, width: menu.size.width, height: imageSelectorViewHeight(menu: menu)))
        imageSelectorView.leftButton.action = #selector(MenuController.imageSelectorViewLeftButtonAction)
        imageSelectorView.leftButton.target = self
        imageSelectorView.rightButton.action = #selector(MenuController.imageSelectorViewRightButtonAction)
        imageSelectorView.rightButton.target = self
        imageItem.view = imageSelectorView
        imageItem.tag = MenuController.IMAGE_VIEW_TAG
        menu.addItem(imageItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let refreshItem = NSMenuItem(title: "Refresh Images", action: #selector(refreshImages), keyEquivalent: "")
        refreshItem.target = self
        menu.addItem(refreshItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let settingsItem = NSMenuItem(title: "Settings", action: #selector(showSettingsWc), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        
        return menu
    }
    
    // MARK: - IBActions
    
    @MainActor
    @objc func showSettingsWc(sender: NSMenuItem?) {
        settingsModel.menuBarIconController = self
        settingsModel.updateManager = updateManager
        settingsModel.refreshFromSettings()

        if settingsWindow == nil {
            let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
            let window = NSWindow(contentViewController: NSHostingController(rootView: SettingsView(model: settingsModel)))
            window.title = "BingWallpaper v\(version)"
            window.styleMask = [.titled, .closable, .miniaturizable]
            window.isReleasedWhenClosed = false
            settingsWindow = window
        }

        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }
    
    @MainActor
    @objc func refreshImages(sender: NSMenuItem) {
        updateManager?.update()
    }
    
    @MainActor
    @objc func imageSelectorViewLeftButtonAction(_ sender: NSButton) {
        if descriptors.indices.contains(selectedDescriptorIndex - 1) == false {
            return
        }
        
        selectedDescriptorIndex = selectedDescriptorIndex - 1
        updateSelectedImage(newSelectedDescriptorIndex: selectedDescriptorIndex)
        updateImageSelectorView(newSelectedDescriptorIndex: selectedDescriptorIndex)
    }
    
    @MainActor
    @objc func imageSelectorViewRightButtonAction(_ sender: NSButton) {
        if descriptors.indices.contains(selectedDescriptorIndex + 1) == false {
            return
        }
        
        selectedDescriptorIndex = selectedDescriptorIndex + 1
        updateSelectedImage(newSelectedDescriptorIndex: selectedDescriptorIndex)
        updateImageSelectorView(newSelectedDescriptorIndex: selectedDescriptorIndex)
    }
    
    @MainActor
    @objc func textItemAction(sender: NSMenuItem) {
        if let descriptor = descriptors[safe: selectedDescriptorIndex] {
            NSWorkspace.shared.open(descriptor.copyrightUrl)
        }
    }
    
    // MARK: - Helper
    
    private func imageSelectorViewHeight(menu: NSMenu) -> CGFloat {
        let outerPadding = 5.0
        let buttonWidth = 15.0
        let innerPadding = 5.0
        let imageViewWidth = menu.size.width - outerPadding*2 - buttonWidth*2 - innerPadding*2
        let topMargin = 4.0
        return imageViewWidth / 16*9 + topMargin
    }
    
    private func updateSelectedImage(newSelectedDescriptorIndex: Int) {
        if let descriptor = descriptors[safe: newSelectedDescriptorIndex] {
            WallpaperManager.shared.setWallpaper(descriptor: descriptor)
        }
    }
    
    @MainActor
    private func updateImageSelectorView(newSelectedDescriptorIndex: Int) {
        guard let menu = menu else { return }
        
        let descriptor = descriptors[safe: newSelectedDescriptorIndex]
        Task { [weak self] in
            guard let self, let descriptor else { return }
            let downloadPath = Image.downloadPath(for: descriptor)
            do {
                let imageData = try await Image.loadData(from: downloadPath)
                self.imageSelectorView.imageView.image = NSImage(data: imageData)
            } catch {
                logger.error("Failed to load image from disk: \(downloadPath.lastPathComponent, privacy: .public)")
            }
        }
        
        let textItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        textItem.tag = MenuController.TEXT_VIEW_TAG
        let textView = TextView(frame: CGRect(x: 0, y: 0, width: menu.size.width, height: 0))
        textView.descriptionLabel.stringValue = getDescription(description: descriptor?.descriptionString)
        textView.copyrightLabel.stringValue = getCopyright(description: descriptor?.descriptionString)
        textView.button.action = #selector(textItemAction)
        textView.button.target = self
        textItem.view = textView
        
        if let oldTextItem = menu.item(withTag: MenuController.TEXT_VIEW_TAG) {
            menu.removeItem(oldTextItem)
        }
        if let imageView = menu.item(withTag: MenuController.IMAGE_VIEW_TAG) {
            let textViewIndex = menu.index(of: imageView) + 1
            menu.insertItem(textItem, at: textViewIndex)
        } else {
            logger.error("Image menu item not found; skipping text view insertion")
        }
        
        imageSelectorView.leftButton.isEnabled = descriptors.indices.contains(newSelectedDescriptorIndex - 1)
        imageSelectorView.rightButton.isEnabled = descriptors.indices.contains(newSelectedDescriptorIndex + 1)
    }
    
    private func getDescription(description: String?) -> String {
        if description == nil { return "" }
        return String(description?.split(separator: "(").first ?? "")
    }
    
    private func getCopyright(description: String?) -> String {
        if description == nil { return "" }
        return description?.split(separator: "(").last?.replacingOccurrences(of: ")", with: "") ?? ""
    }
    
    @MainActor
    private func reloadDescriptors() {
        descriptors = Database.instance.allImageDescriptors()
            .filter { Image.isSavedToDisk(descriptor: $0) }
        if descriptors.indices.contains(selectedDescriptorIndex) == false {
            selectedDescriptorIndex = descriptors.isEmpty ? 0 : descriptors.count - 1
        }
    }
    
    @MainActor
    private func showNewestImage() {
        reloadDescriptors()
        selectedDescriptorIndex = descriptors.isEmpty ? 0 : descriptors.count - 1
        updateSelectedImage(newSelectedDescriptorIndex: selectedDescriptorIndex)
    }
}

// MARK: - Delegates

extension MenuController: UpdateManagerDelegate {
    func downloadedNewImage() {
        showNewestImage()
    }
}

extension MenuController: NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        reloadDescriptors()
        updateImageSelectorView(newSelectedDescriptorIndex: selectedDescriptorIndex)
    }
}

extension MenuController: MenuBarIconControlling {
    func showMenuBarIcon() {
        setup()
    }
    
    func hideMenuBarIcon() {
        guard let statusItem = statusItem else { return }
        NSStatusBar.system.removeStatusItem(statusItem)
        self.menu?.removeAllItems()
        self.menu = nil
        self.statusItem = nil
    }
}
