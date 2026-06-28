import SwiftUI
import AppKit
import ServiceManagement
import OSLog

private let logger = Logger(
    subsystem: Logging.subsystem,
    category: Logging.Category.Settings.rawValue
)

@MainActor
protocol MenuBarIconControlling: AnyObject {
    func showMenuBarIcon()
    func hideMenuBarIcon()
}

@MainActor
@Observable
final class SettingsViewModel {
    private let settings: Settings
    weak var menuBarIconController: MenuBarIconControlling?
    weak var updateManager: UpdateManager?
    weak var notificationManager: NotificationManager?

    var launchAtLogin: Bool
    var hideMenuBarIcon: Bool {
        didSet {
            guard hideMenuBarIcon != oldValue else { return }
            settings.hideMenuBarIcon = hideMenuBarIcon
            if hideMenuBarIcon {
                menuBarIconController?.hideMenuBarIcon()
            } else {
                menuBarIconController?.showMenuBarIcon()
            }
        }
    }
    var keepImageDuration: Int {
        didSet {
            guard keepImageDuration != oldValue else { return }
            settings.keepImageDuration = keepImageDuration
        }
    }
    var notifyOnWallpaperChange: Bool {
        didSet {
            guard notifyOnWallpaperChange != oldValue else { return }
            settings.notifyOnWallpaperChange = notifyOnWallpaperChange
            if notifyOnWallpaperChange {
                handleNotificationsEnabled()
            }
        }
    }

    init() {
        let settings = Settings.shared
        launchAtLogin = settings.launchAtLogin
        hideMenuBarIcon = settings.hideMenuBarIcon
        keepImageDuration = settings.keepImageDuration
        notifyOnWallpaperChange = settings.notifyOnWallpaperChange
        self.settings = settings
    }

    /// Re-read state that can change outside the app (e.g. the user approving
    /// the login item in System Settings) so the window reflects reality when reshown.
    func refreshFromSettings() {
        launchAtLogin = settings.launchAtLogin
    }

    var keepImagesLabel: String {
        guard let duration = KeepImageDuration(rawValue: keepImageDuration) else { return "" }
        switch duration {
        case .five, .ten, .fifty, .onehundred:
            return "Keep last \(duration.text) images"
        case .infinite:
            return "Keep all images forever"
        }
    }

    func setLaunchAtLogin(_ newValue: Bool) {
        do {
            try settings.setLaunchAtLogin(newValue)
        } catch {
            logger.error("Failed to toggle launch-at-login: \(String(describing: error))")
            launchAtLogin = settings.launchAtLogin
            let capturedError = error
            Task { @MainActor in self.presentLaunchAtLoginError(capturedError) }
            return
        }

        launchAtLogin = settings.launchAtLogin

        if newValue, settings.launchAtLoginRequiresApproval {
            Task { @MainActor in self.promptToApproveLoginItem() }
        }
    }

    func resetDatabase() {        logger.info("Resetting Database...")
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd"
        let oldestDateStringToKeep = dateFormatter.string(from: Date())

        do {
            try Database.instance.deleteImageDescriptors(olderThan: oldestDateStringToKeep)
        } catch {
            logger.error("Failed resetting Database: \(error.localizedDescription)")
            presentAlert(title: "Failed to reset Database", message: error.localizedDescription)
        }

        updateManager?.update()
    }

    /// When the user opts in, seed dedup state with the currently-set wallpaper
    /// (so the existing wallpaper isn't immediately re-announced) and request
    /// notification authorization. If the user denies, revert the toggle and
    /// point them to System Settings.
    private func handleNotificationsEnabled() {
        if let newest = newestSavedDescriptor() {
            notificationManager?.seedLastNotified(startDate: newest.startDate)
        }

        Task { @MainActor in
            guard let notificationManager else { return }
            let granted = await notificationManager.requestAuthorizationIfNeeded()
            guard granted == false else { return }
            notifyOnWallpaperChange = false
            presentNotificationsDeniedAlert()
        }
    }

    private func newestSavedDescriptor() -> ImageDescriptor? {
        return Database.instance.allImageDescriptors()
            .filter { Image.isSavedToDisk(descriptor: $0) }
            .last
    }

    private func presentNotificationsDeniedAlert() {
        let alert = NSAlert()
        alert.messageText = "Notifications are turned off"
        alert.informativeText = "BingWallpaper isn't allowed to send notifications. Enable them for BingWallpaper in System Settings to be notified when the wallpaper changes."
        alert.alertStyle = .informational
        let openButton = alert.addButton(withTitle: "Open Notification Settings")
        alert.addButton(withTitle: "Later")
        alert.window.defaultButtonCell = openButton.cell as? NSButtonCell

        if alert.runModal() == .alertFirstButtonReturn,
           let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") {
            NSWorkspace.shared.open(url)
        }
    }

    private func promptToApproveLoginItem() {        let alert = NSAlert()
        alert.messageText = "Approve BingWallpaper in Login Items"
        alert.informativeText = "BingWallpaper has been added to your Login Items but macOS needs your approval before it can launch at login. Open System Settings to confirm it."
        alert.alertStyle = .informational
        let openButton = alert.addButton(withTitle: "Open Login Items")
        alert.addButton(withTitle: "Later")
        alert.window.defaultButtonCell = openButton.cell as? NSButtonCell

        if alert.runModal() == .alertFirstButtonReturn {
            SMAppService.openSystemSettingsLoginItems()
        }
    }

    private func presentLaunchAtLoginError(_ error: Error) {
        presentAlert(title: "Couldn't update Launch at Login", message: error.localizedDescription, style: .warning)
    }

    private func presentAlert(title: String, message: String, style: NSAlert.Style = .informational) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = style
        alert.addButton(withTitle: "Ok")
        alert.runModal()
    }
}

struct SettingsView: View {
    @Bindable var model: SettingsViewModel

    var body: some View {
        Form {
            Toggle("Launch at login", isOn: Binding(
                get: { model.launchAtLogin },
                set: { model.setLaunchAtLogin($0) }
            ))

            Toggle("Hide menu bar icon", isOn: $model.hideMenuBarIcon)

            Toggle("Notify when wallpaper changes", isOn: $model.notifyOnWallpaperChange)

            VStack(alignment: .leading) {
                Text(model.keepImagesLabel)
                Slider(
                    value: Binding(
                        get: { Double(model.keepImageDuration) },
                        set: { model.keepImageDuration = Int($0.rounded()) }
                    ),
                    in: 0...Double(KeepImageDuration.infinite.rawValue),
                    step: 1
                )
            }

            Button("Reset Image Database") {
                model.resetDatabase()
            }
        }
        .formStyle(.grouped)
        .frame(width: 440)
        .fixedSize(horizontal: false, vertical: true)
    }
}
