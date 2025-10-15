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
    func migrateImagesToCloudKit() async throws {
        let migrationKey = "HasMigratedImagesToCloudKit_v1"

        // Check if migration has already been completed
        if UserDefaults.standard.bool(forKey: migrationKey) {
            print("✅ Image migration already completed")
            return
        }

        print("🔄 Starting image migration to CloudKit...")

        // Fetch all items with imagePath but no imageData
        let request = NSFetchRequest<WantedItemEntity>(entityName: "WantedItem")
        request.predicate = NSPredicate(format: "imagePath != '' AND imageData == nil")

        let items = try context.fetch(request)

        guard !items.isEmpty else {
            print("✅ No images to migrate")
            UserDefaults.standard.set(true, forKey: migrationKey)
            return
        }

        print("📦 Found \(items.count) images to migrate")

        var successCount = 0
        var failureCount = 0

        for item in items {
            do {
                // Load image from file
                guard let image = imageStore.loadImage(named: item.imagePath) else {
                    print("⚠️ Could not load image from file: \(item.imagePath)")
                    failureCount += 1
                    continue
                }

                // Compress and store in imageData
                let compressedData = try await imageStore.compressImageToData(image)
                item.imageData = compressedData

                // Keep imagePath for now as backup (can be cleaned up later)
                // item.imagePath can be cleared after verifying imageData works

                successCount += 1

                // Save in batches to avoid memory issues
                if successCount % 10 == 0 {
                    try context.save()
                    print("💾 Migrated \(successCount) images so far...")
                }
            } catch {
                print("❌ Failed to migrate image for item \(item.id): \(error)")
                failureCount += 1
            }
        }

        // Final save
        if context.hasChanges {
            try context.save()
        }

        print("✅ Image migration complete: \(successCount) succeeded, \(failureCount) failed")

        // Mark migration as complete
        UserDefaults.standard.set(true, forKey: migrationKey)
    }

    /// Optional: Clean up old image files after successful migration
    /// Only call this after verifying imageData is working correctly
    func cleanupLegacyImageFiles() async throws {
        print("🧹 Starting cleanup of legacy image files...")

        let request = NSFetchRequest<WantedItemEntity>(entityName: "WantedItem")
        request.predicate = NSPredicate(format: "imagePath != '' AND imageData != nil")

        let items = try context.fetch(request)
        var cleanedCount = 0

        for item in items {
            // Delete the file
            imageStore.deleteImage(named: item.imagePath)

            // Clear the imagePath
            item.imagePath = ""
            cleanedCount += 1
        }

        if context.hasChanges {
            try context.save()
        }

        print("✅ Cleaned up \(cleanedCount) legacy image files")
    }
}
