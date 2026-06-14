//
//  Database.swift
//  BingWallpaper
//
//  Created by Laurenz Lazarus on 24.03.24.
//

import Foundation
import SwiftData
import OSLog

private let logger = Logger(
    subsystem: Logging.subsystem,
    category: Logging.Category.Database.rawValue
)

@MainActor
final class Database {
    static let instance = Database()
    
    let container: ModelContainer
    private var context: ModelContext { container.mainContext }
    
    private init() {
        do {
            container = try ModelContainer(for: ImageDescriptor.self)
        } catch {
            logger.error("Persistent ModelContainer failed: \(error). Falling back to an in-memory store.")
            do {
                container = try ModelContainer(
                    for: ImageDescriptor.self,
                    configurations: ModelConfiguration(isStoredInMemoryOnly: true)
                )
            } catch {
                logger.fault("In-memory ModelContainer also failed: \(error)")
                fatalError("Unable to create SwiftData container")
            }
        }
    }
    
    func allImageDescriptors() -> [ImageDescriptor] {
        let descriptor = FetchDescriptor<ImageDescriptor>(sortBy: [SortDescriptor(\.startDate)])
        do {
            return try context.fetch(descriptor)
        } catch {
            logger.error("Failed to fetch image descriptors: \(error)")
            return []
        }
    }
    
    func deleteImageDescriptors(olderThan oldestDateStringToKeep: String) throws {
        try context.delete(
            model: ImageDescriptor.self,
            where: #Predicate { $0.startDate <= oldestDateStringToKeep }
        )
        try context.save()
    }
    
    func updateImageDescriptors(from imageEntries: [DownloadManager.ImageEntry]) -> [ImageDescriptor] {
        let existingStartDates = Set(allImageDescriptors().map { $0.startDate })
        let uniqueIncoming = Dictionary(
            imageEntries.map { ($0.startdate, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        
        let newDescriptors = uniqueIncoming.values
            .filter { existingStartDates.contains($0.startdate) == false }
            .map { ImageDescriptor.make(from: $0) }
        
        newDescriptors.forEach { context.insert($0) }
        
        do {
            try context.save()
        } catch {
            logger.error("Failed to save new image descriptors: \(error)")
            context.rollback()
            return []
        }
        
        return newDescriptors
    }
}
