//
//  Image.swift
//  BingWallpaper
//
//  Created by Laurenz Lazarus on 23.03.24.
//

import Foundation

class Image {
    enum Error: Swift.Error {
        case missingDescriptor
    }
    
    let downloadPath: URL
    private weak var descriptor: ImageDescriptor?
    
    init(descriptor: ImageDescriptor) {
        self.descriptor = descriptor
        self.downloadPath = Image.downloadPath(for: descriptor)
    }
    
    static func downloadPath(for descriptor: ImageDescriptor) -> URL {
        return downloadPath(forStartDate: descriptor.startDate)
    }
    
    static func downloadPath(forStartDate startDate: String) -> URL {
        return FileHandler.defaultBingWallpaperDirectory().appendingPathComponent(startDate + ".jpg")
    }
    
    func loadFromDisk() async throws -> Data {
        return try Data(contentsOf: downloadPath)
    }
    
    func downloadAndSaveToDisk() async throws {
        guard let descriptor else {
            throw Error.missingDescriptor
        }
        let imageData = try await DownloadManager.downloadBinary(from: descriptor.imageUrl)
        try FileHandler.saveImageDataToDisk(imageData: imageData, toUrl: downloadPath)
    }
    
    static func isSavedToDisk(descriptor: ImageDescriptor) -> Bool {
        return FileManager.default.fileExists(atPath: downloadPath(for: descriptor).path)
    }
    
    func isOnDisk() -> Bool {
        return FileManager.default.fileExists(atPath: downloadPath.relativePath)
    }
}
