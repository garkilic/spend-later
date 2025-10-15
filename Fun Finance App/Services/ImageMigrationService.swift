import Foundation
import CoreData
import UIKit

/// Migrates legacy file-based images to CloudKit-synced imageData
final class ImageMigrationService {
    private let context: NSManagedObjectContext
    private let imageStore: ImageStoring

    init(context: NSManagedObjectContext, imageStore: ImageStoring) {
        self.context = context
        self.imageStore = imageStore
    }

    /// Migrates all legacy file-based images to imageData for CloudKit sync
    /// This is safe to run multiple times - it only processes items that need migration
    /// NOTE: Disabled - imageData removed from schema as it caused CloudKit sync failures
    func migrateImagesToCloudKit() async throws {
        // Migration disabled - imageData removed from Core Data schema
        // Images are now stored locally via imagePath only
        print("⚠️ Image migration to CloudKit is disabled (imageData removed from schema)")
        return
    }

    /// Optional: Clean up old image files after successful migration
    /// Only call this after verifying imageData is working correctly
    /// NOTE: Disabled - imageData removed from schema
    func cleanupLegacyImageFiles() async throws {
        // Cleanup disabled - imageData removed from schema, images stay local
        print("⚠️ Legacy file cleanup is disabled (images are now local-only)")
        return
    }
}
