import Foundation
import AppKit
import OSLog

private let logger = Logger(
    subsystem: Logging.subsystem,
    category: Logging.Category.Update.rawValue
)

protocol UpdateManagerDelegate: AnyObject {
    @MainActor
    func downloadedNewImage()
}

@MainActor
final class UpdateManager {
    private static let ACTIVITY_IDENTIFIER = "com.vb3.BingWallpaper.update"
    private static let RETRY_INTERVAL: TimeInterval = 15 * 60

    weak var delegate: UpdateManagerDelegate?
    private let settings = Settings.shared
    private var activity: NSBackgroundActivityScheduler?
    private var pendingCompletion: NSBackgroundActivityScheduler.CompletionHandler?
    private var isUpdating = false

    @MainActor
    func start() {
        setupObserver()
        doUpdateOrScheduleActivity()
    }

    @MainActor
    private func doUpdateOrScheduleActivity() {
        if UpdateScheduleManager.isUpdateNecessary() {
            update()
            return
        }

        scheduleNextActivity()
    }

    @MainActor
    private func scheduleNextActivity(after interval: TimeInterval? = nil) {
        let nextFetchInterval = interval ?? UpdateScheduleManager.nextFetchTimeInterval()
        logger.info("Next update scheduled in \(nextFetchInterval, privacy: .public)s")

        activity?.invalidate()

        let scheduler = NSBackgroundActivityScheduler(identifier: UpdateManager.ACTIVITY_IDENTIFIER)
        scheduler.repeats = false
        scheduler.interval = nextFetchInterval
        scheduler.tolerance = min(nextFetchInterval / 2, 60 * 30)
        scheduler.qualityOfService = .utility
        scheduler.schedule { completion in
            Task { @MainActor [weak self] in
                guard let self = self else {
                    completion(.finished)
                    return
                }
                self.performUpdate(schedulerCompletion: completion)
            }
        }

        activity = scheduler
    }
        
    @MainActor
    private func cleanup() {
        guard let oldestDateStringToKeep = settings.oldestDateStringToKeep() else { return }
        try? Database.instance.deleteImageDescriptors(olderThan: oldestDateStringToKeep)
        FileHandler.deleteOldImages(oldestDateStringToKeep: oldestDateStringToKeep)
    }
    
    private func setupObserver() {
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(receiveSleepNote),
            name: NSWorkspace.willSleepNotification,
            object: nil
        )
        
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(receiveWakeNote),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
    }
    
    @MainActor
    @objc func update() {
        performUpdate(schedulerCompletion: nil)
    }

    @MainActor
    private func performUpdate(schedulerCompletion: NSBackgroundActivityScheduler.CompletionHandler?) {
        guard isUpdating == false else {
            logger.info("Update already in progress, skipping")
            schedulerCompletion?(.deferred)
            return
        }
        isUpdating = true
        pendingCompletion = schedulerCompletion
        logger.info("Updating")

        Task { @MainActor [weak self] in
            guard let self else { return }
            defer { self.isUpdating = false }

            let imageEntries: [DownloadManager.ImageEntry]
            do {
                imageEntries = try await DownloadManager.downloadImageEntries(numberOfImages: 8)
            } catch {
                logger.error("Failed to download image entries with error: \(error.localizedDescription)")
                self.finish(.deferred, rescheduleAfter: Self.RETRY_INTERVAL)
                return
            }

            // Only treat the fetch as "done" once it actually succeeded, so a
            // transient failure doesn't postpone the next attempt by a full interval.
            self.settings.lastUpdate = Date()

            _ = Database.instance.updateImageDescriptors(from: imageEntries)
            // Prune before downloading so we don't fetch images cleanup would delete.
            self.cleanup()

            // Retry every kept descriptor whose image is missing on disk, not just
            // the freshly inserted ones (covers earlier failed downloads).
            let downloadJobs = Database.instance.allImageDescriptors()
                .filter { Image.isSavedToDisk(descriptor: $0) == false }
                .map { (imageUrl: $0.imageUrl, downloadPath: Image.downloadPath(for: $0)) }

            var didDownloadAnyImage = false
            for job in downloadJobs {
                do {
                    try await Image.downloadAndSave(from: job.imageUrl, to: job.downloadPath)
                    didDownloadAnyImage = true
                } catch {
                    logger.error("Failed to download and store image with error: \(error.localizedDescription)")
                }
            }

            if didDownloadAnyImage {
                self.delegate?.downloadedNewImage()
            }

            self.finish(.finished, rescheduleAfter: nil)
        }
    }

    @MainActor
    private func finish(_ result: NSBackgroundActivityScheduler.Result, rescheduleAfter retryInterval: TimeInterval?) {
        let completion = pendingCompletion
        pendingCompletion = nil
        completion?(result)
        scheduleNextActivity(after: retryInterval)
    }
    
    @MainActor
    @objc func receiveSleepNote(note: NSNotification) {
        activity?.invalidate()
    }

    @MainActor
    @objc func receiveWakeNote(note: NSNotification) {
        doUpdateOrScheduleActivity()
    }
}
