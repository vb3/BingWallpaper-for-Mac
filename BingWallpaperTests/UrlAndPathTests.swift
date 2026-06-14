//
//  UrlAndPathTests.swift
//  BingWallpaperTests
//

import XCTest
@testable import BingWallpaper

final class UrlAndPathTests: XCTestCase {

    // MARK: - ImageDescriptor.bingUrl(from:)

    func testBingUrlResolvesRelativePath() {
        let url = ImageDescriptor.bingUrl(from: "/th?id=OHR.Test_UHD.jpg&pid=hp")
        XCTAssertEqual(url.absoluteString, "https://www.bing.com/th?id=OHR.Test_UHD.jpg&pid=hp")
    }

    func testBingUrlPassesThroughAbsoluteUrl() {
        let absolute = "https://www.bing.com/search?q=Badlands&form=hpcapt"
        let url = ImageDescriptor.bingUrl(from: absolute)
        XCTAssertEqual(url.absoluteString, absolute)
    }

    func testBingUrlFallsBackForEmptyString() {
        let url = ImageDescriptor.bingUrl(from: "")
        XCTAssertEqual(url.absoluteString, "https://www.bing.com")
    }

    func testBingUrlAlwaysHasHttpsSchemeAndBingHost() {
        let url = ImageDescriptor.bingUrl(from: "/foo")
        XCTAssertEqual(url.scheme, "https")
        XCTAssertEqual(url.host, "www.bing.com")
    }

    // MARK: - Image.downloadPath(forStartDate:)

    func testDownloadPathUsesStartDateAsFilename() {
        let url = Image.downloadPath(forStartDate: "20260613")
        XCTAssertEqual(url.lastPathComponent, "20260613.jpg")
    }

    func testDownloadPathIsInBingWallpapersDirectory() {
        let url = Image.downloadPath(forStartDate: "20260613")
        XCTAssertEqual(url.deletingLastPathComponent().lastPathComponent, "bing-wallpapers")
    }
}
