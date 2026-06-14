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
    
    struct ImageEntry: Codable, Sendable {
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
        var components = URLComponents()
        components.scheme = "https"
        components.host = "www.bing.com"
        components.path = "/HPImageArchive.aspx"
        components.queryItems = [
            URLQueryItem(name: "format", value: "js"),
            URLQueryItem(name: "n", value: String(numberOfImages)),
            URLQueryItem(name: "idx", value: "0"),
        ]
        guard let url = components.url else {
            throw URLError(.badURL)
        }
        let response = try await downloadData(from: url)
        return try JSONDecoder().decode(ImageArchive.self, from: response.data).images
    }
    
    static func downloadBinary(from url: URL) async throws -> Data {
        return try await downloadData(from: url).data
    }
}
