//
//  ModelTests.swift
//  BingWallpaperTests
//

import XCTest
@testable import BingWallpaper

final class ModelTests: XCTestCase {

    private func entry(startdate: String) -> DownloadManager.ImageEntry {
        return DownloadManager.ImageEntry(
            url: "/th?id=OHR.Test_1920x1080.jpg&pid=hp",
            enddate: "20240102",
            startdate: startdate,
            copyright: "Test (© Someone)",
            copyrightlink: "https://www.bing.com/search?q=test"
        )
    }

    func testMakeMapsEntryFieldsAndUpgradesImageUrlToUHD() {
        let descriptor = ImageDescriptor.make(from: entry(startdate: "20240101"))
        XCTAssertEqual(descriptor.startDate, "20240101")
        XCTAssertEqual(descriptor.endDate, "20240102")
        XCTAssertEqual(descriptor.descriptionString, "Test (© Someone)")
        XCTAssertEqual(descriptor.imageUrl.absoluteString, "https://www.bing.com/th?id=OHR.Test_UHD.jpg&pid=hp")
        XCTAssertEqual(descriptor.copyrightUrl.absoluteString, "https://www.bing.com/search?q=test")
    }
}
