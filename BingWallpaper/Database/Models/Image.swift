//
//  Image.swift
//  BingWallpaper
//
//  Created by Laurenz Lazarus on 23.03.24.
//

import Foundation

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
        try FileHandler.saveImageDataToDisk(imageData: imageData, toUrl: downloadPath)
    }
}
