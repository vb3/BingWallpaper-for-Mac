//
//  Image.swift
//  BingWallpaper
//
//  Created by Laurenz Lazarus on 23.03.24.
//

import Foundation
import ImageIO

enum Image {
    static func downloadPath(for descriptor: ImageDescriptor) -> URL {
        return downloadPath(forStartDate: descriptor.startDate)
    }
    
    static func downloadPath(forStartDate startDate: String) -> URL {
        return FileHandler.defaultBingWallpaperDirectory().appendingPathComponent(startDate + ".jpg")
    }
    
    static func isSavedToDisk(descriptor: ImageDescriptor) -> Bool {
        return FileManager.default.fileExists(atPath: downloadPath(for: descriptor).path)
    }
    
    static func loadData(from downloadPath: URL) async throws -> Data {
        return try Data(contentsOf: downloadPath)
    }
    
    static func downloadAndSave(from imageUrl: URL, to downloadPath: URL) async throws {
        let imageData = try await DownloadManager.downloadBinary(from: imageUrl)
        // Fully decode the first frame so truncated or non-image payloads (error
        // pages, captive portals) are rejected. Throwing here leaves the descriptor
        // "not on disk" so it is retried on the next update instead of persisting garbage.
        guard isValidImageData(imageData) else {
            throw ImageError.dataNotValid
        }
        try FileHandler.saveImageDataToDisk(imageData: imageData, toUrl: downloadPath)
    }

    /// Returns `true` only if `data` decodes to at least one complete image,
    /// catching truncated downloads that a lenient decoder might accept.
    static func isValidImageData(_ data: Data) -> Bool {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              CGImageSourceGetType(source) != nil,
              CGImageSourceGetCount(source) > 0,
              CGImageSourceCreateImageAtIndex(source, 0, nil) != nil else {
            return false
        }
        return true
    }
}
