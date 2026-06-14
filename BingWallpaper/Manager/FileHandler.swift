import AppKit
import Foundation
import OSLog

private let logger = Logger(
    subsystem: Logging.subsystem,
    category: Logging.Category.FileHandler.rawValue
)

class FileHandler {
    static func usersPictureDirectory() -> String {
        guard let picturesDirectory = NSSearchPathForDirectoriesInDomains(.picturesDirectory, .userDomainMask, true).first else {
            logger.error("Couldn't find picture directory of user")
            return FileManager.default.homeDirectoryForCurrentUser.path
        }
        
        return picturesDirectory
    }
    
    static func defaultBingWallpaperDirectory() -> String {
        return usersPictureDirectory() + "/bing-wallpapers/"
    }
    
    static func defaultBingWallpaperDirectory() -> URL {
        return URL(fileURLWithPath: defaultBingWallpaperDirectory(), isDirectory: true)
    }
    
    static func createWallpaperFolderIfNeeded() {
        let bingDir: String = defaultBingWallpaperDirectory()
        
        if FileManager.default.fileExists(atPath: bingDir) { return }
        
        do {
            try FileManager.default.createDirectory(atPath: bingDir, withIntermediateDirectories: false)
        } catch {
            logger.error("Failed to create bing-wallpapers folder with error: \(error.localizedDescription)")
        }
    }
    
    static func saveImageDataToDisk(imageData: Data, toUrl: URL) throws {
        try imageData.write(to: toUrl, options: .withoutOverwriting)
    }
    
    static func getSavedImages() -> [URL] {
        do {
            return try FileManager.default.contentsOfDirectory(at: defaultBingWallpaperDirectory(), includingPropertiesForKeys: nil, options: FileManager.DirectoryEnumerationOptions.skipsHiddenFiles)
        } catch {
            logger.error("Failed to list saved images: \(error.localizedDescription)")
            return []
        }
    }
    
    static func removeImageFromDisk(imagePath: URL) {
        do {
            return try FileManager.default.removeItem(at: imagePath)
        } catch {
            logger.error("Failed to remove image at \(imagePath.path, privacy: .private): \(error.localizedDescription)")
            return
        }
    }
    
    static func deleteOldImages(oldestDateStringToKeep: String) {
        getSavedImages()
            .filter { $0.lastPathComponent.replacingOccurrences(of: ".jpg", with: "") <= oldestDateStringToKeep }
            .forEach { removeImageFromDisk(imagePath: $0) }
    }
}
