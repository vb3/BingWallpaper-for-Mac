import AppKit
import Foundation
import OSLog
import UserNotifications

private let logger = Logger(
    subsystem: Logging.subsystem,
    category: Logging.Category.Notification.rawValue
)

/// Posts a local notification when a new Bing wallpaper is downloaded and set.
///
/// Authorization is requested lazily — only when the user has opted in — and the
/// posting path is async so the very first notification after the user grants
/// permission isn't dropped while the system prompt is still resolving.
@MainActor
final class NotificationManager: NSObject {
    private let settings = Settings.shared
    private let center = UNUserNotificationCenter.current()

    /// Install as the notification-center delegate so banners still appear while
    /// the app is active (e.g. the Settings window is open). An `LSUIElement`
    /// agent app would otherwise have notifications suppressed when foregrounded.
    func installAsDelegate() {
        center.delegate = self
    }

    /// Request authorization when the current status is undetermined. Returns
    /// whether notifications are authorized afterwards.
    @discardableResult
    func requestAuthorizationIfNeeded() async -> Bool {
        let status = await currentAuthorizationStatus()
        switch status {
        case .notDetermined:
            do {
                return try await center.requestAuthorization(options: [.alert, .sound])
            } catch {
                logger.error("Failed to request notification authorization: \(error.localizedDescription)")
                return false
            }
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        @unknown default:
            return false
        }
    }

    /// `true` when the user has previously denied notification permission, so the
    /// caller can guide them to System Settings instead of silently failing.
    func isDenied() async -> Bool {
        return await currentAuthorizationStatus() == .denied
    }

    /// Record the given start date as already-notified without posting anything.
    /// Used to seed dedup state when the feature is first enabled while a
    /// wallpaper is already set, so we don't notify for an unchanged wallpaper.
    func seedLastNotified(startDate: String) {
        settings.lastNotifiedImageStartDate = startDate
    }

    /// Post a "new wallpaper set" notification for the given image, subject to the
    /// opt-in toggle, dedup, and authorization. Safe to call for every download
    /// event — it no-ops when the newest image hasn't changed.
    ///
    /// Plain value parameters are intentionally extracted from the SwiftData
    /// `@Model` on the @MainActor by the caller, so nothing is carried across the
    /// awaits below.
    func notifyWallpaperChanged(startDate: String, descriptionString: String, imageURL: URL) async {
        guard Self.shouldNotify(
            enabled: settings.notifyOnWallpaperChange,
            newStartDate: startDate,
            lastNotified: settings.lastNotifiedImageStartDate
        ) else { return }

        let authorized = await requestAuthorizationIfNeeded()
        guard authorized else {
            logger.info("Notification skipped: not authorized")
            return
        }

        // Re-check the dedup decision in case the toggle was flipped or another
        // notification for the same image landed while authorization resolved.
        guard Self.shouldNotify(
            enabled: settings.notifyOnWallpaperChange,
            newStartDate: startDate,
            lastNotified: settings.lastNotifiedImageStartDate
        ) else { return }

        let content = UNMutableNotificationContent()
        content.title = "New Bing wallpaper set"
        content.body = Self.notificationBody(from: descriptionString)
        if let attachment = Self.makeThumbnailAttachment(from: imageURL, identifier: startDate) {
            content.attachments = [attachment]
        }

        let request = UNNotificationRequest(
            identifier: "wallpaper-\(startDate)",
            content: content,
            trigger: nil
        )

        do {
            try await center.add(request)
            settings.lastNotifiedImageStartDate = startDate
        } catch {
            logger.error("Failed to post wallpaper notification: \(error.localizedDescription)")
        }
    }

    // MARK: - Helpers

    /// Pure dedup decision: notify only when the feature is enabled and the
    /// newest image differs from the last one we announced. Centralizing this
    /// keeps the coalescing/backfill invariant — only notify for a genuinely new
    /// newest wallpaper, never for re-downloaded older images — unit-testable.
    static nonisolated func shouldNotify(enabled: Bool, newStartDate: String, lastNotified: String?) -> Bool {
        guard enabled else { return false }
        return newStartDate != lastNotified
    }

    private func currentAuthorizationStatus() async -> UNAuthorizationStatus {
        return await center.notificationSettings().authorizationStatus
    }

    /// Build the notification body from Bing's "Title (copyright)" caption,
    /// reusing the shared `Caption` parser. Falls back to whichever part is
    /// present when the caption has no title or no credit.
    static nonisolated func notificationBody(from descriptionString: String) -> String {
        let trimmed = descriptionString.trimmingCharacters(in: .whitespacesAndNewlines)
        let caption = Caption.split(trimmed)
        let title = caption.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let copyright = caption.copyright.trimmingCharacters(in: .whitespacesAndNewlines)

        if title.isEmpty { return copyright }
        if copyright.isEmpty { return title }
        return "\(title)\n\(copyright)"
    }

    /// Best-effort thumbnail attachment. The system takes ownership of the file,
    /// so a downsized JPEG is written to a unique path in the temporary directory.
    /// Any failure returns nil and the notification is posted without an image.
    static nonisolated func makeThumbnailAttachment(from imageURL: URL, identifier: String) -> UNNotificationAttachment? {
        guard let image = NSImage(contentsOf: imageURL) else { return nil }

        let maxDimension: CGFloat = 600
        let size = image.size
        guard size.width > 0, size.height > 0 else { return nil }
        let scale = min(1, maxDimension / max(size.width, size.height))
        let targetSize = NSSize(width: size.width * scale, height: size.height * scale)

        let thumbnail = NSImage(size: targetSize)
        thumbnail.lockFocus()
        image.draw(
            in: NSRect(origin: .zero, size: targetSize),
            from: NSRect(origin: .zero, size: size),
            operation: .copy,
            fraction: 1
        )
        thumbnail.unlockFocus()

        guard let tiff = thumbnail.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let jpegData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.8]) else {
            return nil
        }

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("notif-\(identifier)-\(UUID().uuidString)")
            .appendingPathExtension("jpg")

        do {
            try jpegData.write(to: tempURL)
            return try UNNotificationAttachment(identifier: identifier, url: tempURL, options: nil)
        } catch {
            logger.error("Failed to build notification thumbnail: \(error.localizedDescription)")
            try? FileManager.default.removeItem(at: tempURL)
            return nil
        }
    }
}

extension NotificationManager: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list, .sound])
    }
}
