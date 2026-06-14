import AppKit
import CoreData
import Foundation

public final class ImageDescriptor: NSManagedObject {
    @NSManaged var startDate: String
    @NSManaged var endDate: String
    @NSManaged var imageUrl: URL
    @NSManaged var descriptionString: String
    @NSManaged var copyrightUrl: URL
    lazy var image: Image = {
        return Image(descriptor: self)
    }()
    
    private static let bingBaseUrl = URL(string: "https://www.bing.com")!
    
    private static func bingUrl(from relativeOrAbsolute: String) -> URL {
        return URL(string: relativeOrAbsolute, relativeTo: bingBaseUrl)?.absoluteURL ?? bingBaseUrl
    }
    
    static func == (lhs: ImageDescriptor, rhs: ImageDescriptor) -> Bool {
        return lhs.startDate == rhs.startDate
    }
    
    static func instantiate(from entry: DownloadManager.ImageEntry, in managedContext: NSManagedObjectContext) -> ImageDescriptor {
        let entity = NSEntityDescription.entity(forEntityName: "ImageDescriptor", in: managedContext)!
        let imageDescriptor = ImageDescriptor(entity: entity, insertInto: managedContext)
        imageDescriptor.startDate = entry.startdate
        imageDescriptor.endDate = entry.enddate
        imageDescriptor.imageUrl = bingUrl(from: entry.url.replacingOccurrences(of: "1920x1080", with: "UHD"))
        imageDescriptor.descriptionString = entry.copyright
        imageDescriptor.copyrightUrl = bingUrl(from: entry.copyrightlink)
        return imageDescriptor
    }
}

extension ImageDescriptor: Comparable {
    public static func < (lhs: ImageDescriptor, rhs: ImageDescriptor) -> Bool {
        return lhs.startDate < rhs.startDate
    }
}
