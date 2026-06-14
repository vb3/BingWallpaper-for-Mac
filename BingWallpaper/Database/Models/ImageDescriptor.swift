import Foundation
import SwiftData

@Model
final class ImageDescriptor {
    @Attribute(.unique) var startDate: String
    var endDate: String
    var imageUrl: URL
    var descriptionString: String
    var copyrightUrl: URL
    
    init(startDate: String, endDate: String, imageUrl: URL, descriptionString: String, copyrightUrl: URL) {
        self.startDate = startDate
        self.endDate = endDate
        self.imageUrl = imageUrl
        self.descriptionString = descriptionString
        self.copyrightUrl = copyrightUrl
    }
    
    static func make(from entry: DownloadManager.ImageEntry) -> ImageDescriptor {
        return ImageDescriptor(
            startDate: entry.startdate,
            endDate: entry.enddate,
            imageUrl: bingUrl(from: entry.url.replacingOccurrences(of: "1920x1080", with: "UHD")),
            descriptionString: entry.copyright,
            copyrightUrl: bingUrl(from: entry.copyrightlink)
        )
    }
    
    private static let bingBaseUrl = URL(string: "https://www.bing.com")!
    
    static func bingUrl(from relativeOrAbsolute: String) -> URL {
        return URL(string: relativeOrAbsolute, relativeTo: bingBaseUrl)?.absoluteURL ?? bingBaseUrl
    }
}
