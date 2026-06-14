//
//  UrlAndPathTests.swift
//  BingWallpaperTests
//

import XCTest
@testable import BingWallpaper

final class UrlAndPathTests: XCTestCase {

    // MARK: - ImageDescriptor.bingUrl(from:)

    func testBingUrlResolvesRelativePathAgainstBing() {
        let url = ImageDescriptor.bingUrl(from: "/th?id=OHR.Test_UHD.jpg&pid=hp")
        XCTAssertEqual(url.absoluteString, "https://www.bing.com/th?id=OHR.Test_UHD.jpg&pid=hp")
    }

    func testBingUrlPassesThroughAbsoluteUrl() {
        let absolute = "https://www.bing.com/search?q=Badlands&form=hpcapt"
        XCTAssertEqual(ImageDescriptor.bingUrl(from: absolute).absoluteString, absolute)
    }

    func testBingUrlFallsBackToBingHomeForEmptyString() {
        XCTAssertEqual(ImageDescriptor.bingUrl(from: "").absoluteString, "https://www.bing.com")
    }

    // MARK: - Image.downloadPath(forStartDate:)

    func testDownloadPathDerivesFilenameUnderBingWallpapers() {
        let url = Image.downloadPath(forStartDate: "20260613")
        XCTAssertEqual(url.lastPathComponent, "20260613.jpg")
        XCTAssertEqual(url.deletingLastPathComponent().lastPathComponent, "bing-wallpapers")
    }
}
