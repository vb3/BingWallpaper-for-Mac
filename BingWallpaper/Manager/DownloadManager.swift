import Cocoa
import Foundation
import OSLog

private let logger = Logger(
    subsystem: Logging.subsystem,
    category: Logging.Category.Download.rawValue
)

class DownloadManager {
    
    struct ImageArchive: Codable {
        let images: [ImageEntry]
    }
    
    struct ImageEntry: Codable {
        let url: String
        let enddate: String
        let startdate: String
        let copyright: String
        let copyrightlink: String
    }
    
    private static func downloadData(from url: URL) async throws-> DownloadResponse {
        let (data, urlResponse) = try await URLSession.shared.data(from: url)
        return DownloadResponse(data: data, urlResponse: urlResponse)
    }
    
    static func downloadImageEntries(numberOfImages: Int) async throws -> [ImageEntry] {
        // TODO: @2h4u: idx is the start index of the batch of image descriptors that is downloaded, maybe add support for it so more images from the past can be used?
        let response = try await downloadData(from: URL(string: "https://www.bing.com/HPImageArchive.aspx?format=js&n=\(numberOfImages)&idx=0")!)
        return try JSONDecoder().decode(ImageArchive.self, from: response.data).images
    }
    
    static func downloadBinary(from url: URL) async throws -> Data {
        return try await downloadData(from: url).data
    }
}
