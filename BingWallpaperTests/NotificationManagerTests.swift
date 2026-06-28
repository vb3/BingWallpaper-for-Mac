//
//  NotificationManagerTests.swift
//  BingWallpaperTests
//

import XCTest
@testable import BingWallpaper
import AppKit

final class NotificationManagerTests: XCTestCase {

    func testNotificationBodySplitsTitleAndCopyright() {
        let body = NotificationManager.notificationBody(from: "Sunrise over the Alps (© Someone/Getty)")
        XCTAssertEqual(body, "Sunrise over the Alps\n© Someone/Getty")
    }

    func testNotificationBodyUsesLastParenthesizedGroupAsCopyright() {
        let body = NotificationManager.notificationBody(from: "A bridge (built 1932) at dusk (© Photographer)")
        XCTAssertEqual(body, "A bridge (built 1932) at dusk\n© Photographer")
    }

    func testNotificationBodyWithoutParenthesesReturnsWholeString() {
        let body = NotificationManager.notificationBody(from: "Just a title")
        XCTAssertEqual(body, "Just a title")
    }

    func testNotificationBodyTrimsWhitespace() {
        let body = NotificationManager.notificationBody(from: "  Title   (© Owner)  ")
        XCTAssertEqual(body, "Title\n© Owner")
    }

    func testNotificationBodyWithEmptyTitleReturnsCopyrightOnly() {
        let body = NotificationManager.notificationBody(from: "(© Owner)")
        XCTAssertEqual(body, "© Owner")
    }

    // MARK: - Dedup decision (coalescing / backfill invariant)

    func testShouldNotNotifyWhenDisabled() {
        XCTAssertFalse(NotificationManager.shouldNotify(enabled: false, newStartDate: "20240102", lastNotified: "20240101"))
    }

    func testShouldNotifyForNewImageWhenNothingNotifiedYet() {
        XCTAssertTrue(NotificationManager.shouldNotify(enabled: true, newStartDate: "20240101", lastNotified: nil))
    }

    func testShouldNotifyWhenNewestChanged() {
        XCTAssertTrue(NotificationManager.shouldNotify(enabled: true, newStartDate: "20240102", lastNotified: "20240101"))
    }

    func testShouldNotNotifyWhenNewestUnchanged() {
        // The backfill case: an older missing image was re-downloaded but the
        // newest wallpaper is the one we already announced — must not re-notify.
        XCTAssertFalse(NotificationManager.shouldNotify(enabled: true, newStartDate: "20240101", lastNotified: "20240101"))
    }

    // MARK: - Thumbnail attachment (best-effort path)

    func testThumbnailAttachmentIsNilForMissingFile() {
        let missing = FileManager.default.temporaryDirectory
            .appendingPathComponent("does-not-exist-\(UUID().uuidString).jpg")
        XCTAssertNil(NotificationManager.makeThumbnailAttachment(from: missing, identifier: "20240101"))
    }

    func testThumbnailAttachmentIsBuiltForValidImage() throws {
        let imageURL = try writeSampleImage()
        defer { try? FileManager.default.removeItem(at: imageURL) }

        let attachment = NotificationManager.makeThumbnailAttachment(from: imageURL, identifier: "20240101")
        XCTAssertNotNil(attachment, "A valid image should yield a notification attachment")
    }

    private func writeSampleImage() throws -> URL {
        let image = NSImage(size: NSSize(width: 1920, height: 1080))
        image.lockFocus()
        NSColor.systemBlue.setFill()
        NSRect(x: 0, y: 0, width: 1920, height: 1080).fill()
        image.unlockFocus()

        let tiff = try XCTUnwrap(image.tiffRepresentation)
        let bitmap = try XCTUnwrap(NSBitmapImageRep(data: tiff))
        let jpeg = try XCTUnwrap(bitmap.representation(using: .jpeg, properties: [:]))

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("sample-\(UUID().uuidString).jpg")
        try jpeg.write(to: url)
        return url
    }
}
