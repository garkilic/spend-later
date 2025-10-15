import Foundation
import CoreData

/// Migrates legacy productURL strings to CloudKit-synced productURLData
final class URLMigrationService {
    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    /// Migrates all legacy productURL strings to productURLData for CloudKit sync
    /// This is safe to run multiple times - it only processes items that need migration
    func migrateURLsToCloudKit() async throws {
        let migrationKey = "HasMigratedURLsToCloudKit_v8"

        // Check if migration has already been completed
        if UserDefaults.standard.bool(forKey: migrationKey) {
            print("✅ URL migration already completed")
            return
        }

        print("🔄 Starting URL migration to CloudKit...")

        // Fetch all items with productURL but no productURLData
        let request = NSFetchRequest<WantedItemEntity>(entityName: "WantedItem")
        request.predicate = NSPredicate(format: "productURL != nil AND productURLData == nil")

        let items = try context.fetch(request)

        guard !items.isEmpty else {
            print("✅ No URLs to migrate")
            UserDefaults.standard.set(true, forKey: migrationKey)
            return
        }

        print("📦 Found \(items.count) URLs to migrate")

        var successCount = 0
        var failureCount = 0

        for item in items {
            do {
                // Convert productURL string to Data
                guard let urlString = item.productURL, !urlString.isEmpty else {
                    failureCount += 1
                    continue
                }

                guard let urlData = urlString.data(using: .utf8) else {
                    print("⚠️ Could not convert URL to Data: \(urlString)")
                    failureCount += 1
                    continue
                }

                // Store in productURLData for CloudKit sync
                item.productURLData = urlData

                successCount += 1

                // Save in batches to avoid memory issues
                if successCount % 20 == 0 {
                    try context.save()
                    print("💾 Migrated \(successCount) URLs so far...")
                }
            } catch {
                print("❌ Failed to migrate URL for item \(item.id): \(error)")
                failureCount += 1
            }
        }

        // Final save
        if context.hasChanges {
            try context.save()
        }

        print("✅ URL migration complete: \(successCount) succeeded, \(failureCount) failed")

        // Mark migration as complete
        UserDefaults.standard.set(true, forKey: migrationKey)
    }
}
