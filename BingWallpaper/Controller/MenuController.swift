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
    private let settings = Settings.shared
    private var descriptors = [ImageDescriptor]()
    private var selectedDescriptorIndex = 0
    private var imageSelectorView: ImageSelectorView!
    var updateManager: UpdateManager?
    private static let IMAGE_VIEW_TAG = 6
    private static let TEXT_VIEW_TAG = 7
    private var settingsWindow: NSWindow?
    private lazy var settingsModel = SettingsViewModel()
    private var textView: TextView?
    private var imageLoadToken = 0
    let notificationManager = NotificationManager()

    override init() {
        super.init()
        notificationManager.installAsDelegate()
    }

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
            button.image = NSImage(systemSymbolName: "photo", accessibilityDescription: "BingWallpaper")
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

        let textItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        textItem.tag = MenuController.TEXT_VIEW_TAG
        let textView = TextView(frame: CGRect(x: 0, y: 0, width: menu.size.width, height: 0))
        textView.button.action = #selector(textItemAction)
        textView.button.target = self
        textItem.view = textView
        self.textView = textView
        menu.addItem(textItem)

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
        settingsModel.notificationManager = notificationManager
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
    
    @discardableResult
    private func updateSelectedImage(newSelectedDescriptorIndex: Int) -> Bool {
        if let descriptor = descriptors[safe: newSelectedDescriptorIndex] {
            return WallpaperManager.shared.setWallpaper(descriptor: descriptor)
        }
        return false
    }
    
    @MainActor
    private func updateImageSelectorView(newSelectedDescriptorIndex: Int) {
        let descriptor = descriptors[safe: newSelectedDescriptorIndex]

        imageLoadToken += 1
        let token = imageLoadToken
        if let descriptor {
            Task { [weak self] in
                guard let self else { return }
                let downloadPath = Image.downloadPath(for: descriptor)
                do {
                    let imageData = try await Image.loadData(from: downloadPath)
                    // Drop the result if a newer selection has superseded this load.
                    guard token == self.imageLoadToken else { return }
                    self.imageSelectorView.imageView.image = NSImage(data: imageData)
                } catch {
                    logger.error("Failed to load image from disk: \(downloadPath.lastPathComponent, privacy: .public)")
                }
            }
        }

        textView?.descriptionLabel.stringValue = getDescription(description: descriptor?.descriptionString)
        textView?.copyrightLabel.stringValue = getCopyright(description: descriptor?.descriptionString)

        imageSelectorView.leftButton.isEnabled = descriptors.indices.contains(newSelectedDescriptorIndex - 1)
        imageSelectorView.rightButton.isEnabled = descriptors.indices.contains(newSelectedDescriptorIndex + 1)
    }
    
    private func getDescription(description: String?) -> String {
        return Caption.split(description).text
    }

    private func getCopyright(description: String?) -> String {
        return Caption.split(description).copyright
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
    @discardableResult
    private func showNewestImage() -> (descriptor: ImageDescriptor?, didSet: Bool) {
        reloadDescriptors()
        selectedDescriptorIndex = descriptors.isEmpty ? 0 : descriptors.count - 1
        let didSet = updateSelectedImage(newSelectedDescriptorIndex: selectedDescriptorIndex)
        return (descriptors[safe: selectedDescriptorIndex], didSet)
    }
}

// MARK: - Delegates

extension MenuController: UpdateManagerDelegate {
    func downloadedNewImage() {
        let (descriptor, didSet) = showNewestImage()
        guard didSet, let descriptor else { return }

        // Extract plain values off the SwiftData @Model on the main actor before
        // handing them to the async notification work.
        let startDate = descriptor.startDate
        let descriptionString = descriptor.descriptionString
        let imageURL = Image.downloadPath(for: descriptor)

        Task {
            await notificationManager.notifyWallpaperChanged(
                startDate: startDate,
                descriptionString: descriptionString,
                imageURL: imageURL
            )
        }
    }
}

extension MenuController: NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        textView?.highlighted = false
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
        self.textView = nil
    }
}
