import CoreData
import UIKit

protocol ItemRepositoryProtocol {
    var currentMonthKey: String { get }
    var context: NSManagedObjectContext { get }
    func addItem(title: String, price: Decimal, notes: String?, tags: [String], productURL: String?, image: UIImage?) async throws
    func items(for monthKey: String) throws -> [WantedItemEntity]
    func activeItems(for monthKey: String) throws -> [WantedItemEntity]
    func allItems() throws -> [WantedItemEntity]
    func delete(_ item: WantedItemEntity) throws
    func restore(_ snapshot: ItemSnapshot) throws
    func makeSnapshot(from item: WantedItemEntity) -> ItemSnapshot
    func monthKey(for date: Date) -> String
    func item(with id: UUID) throws -> WantedItemEntity?
    func updateItem(id: UUID, title: String, notes: String?, tags: [String], productURL: String?) throws
    func updateItem(id: UUID, title: String, price: Decimal?, notes: String?, tags: [String], productURL: String?, image: UIImage?, replaceImage: Bool) async throws
    func markAsBought(itemId: UUID) throws
    func markAsSaved(itemId: UUID) throws
    func loadImage(for item: WantedItemEntity) -> UIImage?
}

struct ItemSnapshot {
    let id: UUID
    let title: String
    let price: Decimal
    let notes: String?
    let tags: [String]
    let productURL: String?
    let imagePath: String
    let createdAt: Date
    let monthKey: String
    let status: ItemStatus
}

final class ItemRepository: ItemRepositoryProtocol {
    let context: NSManagedObjectContext
    private let imageStore: ImageStoring
    private let calendar: Calendar
    private let monthFormatter: DateFormatter

    init(context: NSManagedObjectContext, imageStore: ImageStoring, calendar: Calendar = .current) {
        self.context = context
        self.imageStore = imageStore
        self.calendar = calendar
        self.monthFormatter = DateFormatter()
        self.monthFormatter.dateFormat = "yyyy,MM"
    }

    var currentMonthKey: String {
        monthKey(for: Date())
    }

    func addItem(title: String, price: Decimal, notes: String?, tags: [String], productURL: String?, image: UIImage?) async throws {
        let item = WantedItemEntity(context: context)
        item.id = UUID()
        item.title = title
        item.price = NSDecimalNumber(decimal: price)
        item.notes = notes
        item.productText = nil
        item.productURL = productURL

        // Handle image storage - save to both imageData (CloudKit) and imagePath (local backup)
        if let image {
            print("📸 Processing image for storage...")

            // Save to imageData for CloudKit sync (primary storage in v6)
            do {
                let compressedData = try await imageStore.compressImageToData(image)
                let sizeKB = Double(compressedData.count) / 1024.0
                print("📸 Image compressed to \(String(format: "%.1f", sizeKB)) KB")
                item.imageData = compressedData
                print("✅ imageData set for CloudKit sync")
            } catch {
                print("❌ Failed to set imageData: \(error.localizedDescription)")
                item.imageData = nil
            }

            // Also save to local file as backup (for offline access)
            do {
                let filename = try await imageStore.save(image: image)
                item.imagePath = filename
                print("✅ Image also saved to local file: \(filename)")
            } catch {
                print("⚠️ Failed to save image file: \(error.localizedDescription)")
                item.imagePath = ""
            }
        } else {
            item.imagePath = ""
            item.imageData = nil
            print("ℹ️ No image provided")
        }

        item.tags = tags
        item.createdAt = Date()
        item.monthKey = monthKey(for: item.createdAt)
        item.status = .saved
        try saveIfNeeded()
    }

    func items(for monthKey: String) throws -> [WantedItemEntity] {
        let request = WantedItemEntity.fetchRequest(forMonthKey: monthKey)
        request.fetchBatchSize = 10 // Smaller batches for device
        request.returnsObjectsAsFaults = true // Let Core Data lazy load
        return try context.fetch(request)
    }

    func activeItems(for monthKey: String) throws -> [WantedItemEntity] {
        let request = WantedItemEntity.fetchRequest(forMonthKey: monthKey)
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "monthKey == %@", monthKey),
            NSPredicate(format: "statusRaw == %@", ItemStatus.saved.rawValue)
        ])
        request.fetchBatchSize = 10
        request.returnsObjectsAsFaults = true
        return try context.fetch(request)
    }

    func allItems() throws -> [WantedItemEntity] {
        let request = NSFetchRequest<WantedItemEntity>(entityName: "WantedItem")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \WantedItemEntity.createdAt, ascending: false)]
        request.fetchBatchSize = 20 // Reduced from 50
        request.returnsObjectsAsFaults = true
        return try context.fetch(request)
    }

    func delete(_ item: WantedItemEntity) throws {
        context.delete(item)
        try saveIfNeeded()
    }

    func restore(_ snapshot: ItemSnapshot) throws {
        let item = WantedItemEntity(context: context)
        item.id = snapshot.id
        item.title = snapshot.title
        item.price = NSDecimalNumber(decimal: snapshot.price)
        item.notes = snapshot.notes
        item.productText = nil
        item.productURL = snapshot.productURL
        item.imagePath = snapshot.imagePath
        item.tags = snapshot.tags
        item.createdAt = snapshot.createdAt
        item.monthKey = snapshot.monthKey
        item.status = snapshot.status
        try saveIfNeeded()
    }

    func makeSnapshot(from item: WantedItemEntity) -> ItemSnapshot {
        ItemSnapshot(id: item.id,
                     title: item.title,
                     price: item.price.decimalValue,
                     notes: item.notes,
                     tags: item.tags,
                     productURL: item.productURL,
                     imagePath: item.imagePath,
                     createdAt: item.createdAt,
                     monthKey: item.monthKey,
                     status: item.status)
    }

    func monthKey(for date: Date) -> String {
        monthFormatter.string(from: date)
    }

    func item(with id: UUID) throws -> WantedItemEntity? {
        let request = NSFetchRequest<WantedItemEntity>(entityName: "WantedItem")
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try context.fetch(request).first
    }

    func updateItem(id: UUID, title: String, notes: String?, tags: [String], productURL: String?) throws {
        guard let entity = try item(with: id) else { return }
        entity.title = title
        entity.notes = notes
        entity.tags = tags
        entity.productURL = productURL
        entity.productText = nil
        try saveIfNeeded()

        // Refresh the object to ensure subsequent fetches get fresh data
        context.refresh(entity, mergeChanges: false)
    }

    func updateItem(id: UUID, title: String, price: Decimal?, notes: String?, tags: [String], productURL: String?, image: UIImage?, replaceImage: Bool) async throws {
        guard let entity = try item(with: id) else { return }
        entity.title = title
        if let price = price {
            entity.price = NSDecimalNumber(decimal: price)
        }
        entity.notes = notes
        entity.tags = tags
        entity.productURL = productURL
        entity.productText = nil

        // Handle image replacement
        if replaceImage {
            // Delete old file-based image if exists
            if !entity.imagePath.isEmpty {
                imageStore.deleteImage(named: entity.imagePath)
                entity.imagePath = ""
            }

            // Clear old imageData
            entity.imageData = nil

            // Save new image if provided (using imageData for CloudKit sync)
            if let image = image {
                let compressedData = try await imageStore.compressImageToData(image)
                entity.imageData = compressedData
            }
        }

        try saveIfNeeded()

        // Refresh the object to ensure subsequent fetches get fresh data
        // This is necessary because stalenessInterval is set to -1 in PersistenceController
        context.refresh(entity, mergeChanges: false)
    }

    func markAsBought(itemId: UUID) throws {
        guard let entity = try item(with: itemId) else { return }
        entity.actuallyPurchased = true
        entity.status = .bought
        try saveIfNeeded()

        // Refresh the object to ensure subsequent fetches get fresh data
        context.refresh(entity, mergeChanges: false)
    }

    func markAsSaved(itemId: UUID) throws {
        guard let entity = try item(with: itemId) else { return }
        entity.actuallyPurchased = false
        entity.status = .saved
        try saveIfNeeded()

        // Refresh the object to ensure subsequent fetches get fresh data
        context.refresh(entity, mergeChanges: false)
    }

    func loadImage(for item: WantedItemEntity) -> UIImage? {
        // Try imageData first (CloudKit-synced images)
        if let imageData = item.imageData, !imageData.isEmpty {
            return imageStore.loadImage(from: imageData)
        }

        // Fall back to file-based imagePath (legacy images)
        if !item.imagePath.isEmpty {
            return imageStore.loadImage(named: item.imagePath)
        }

        return nil
    }
}

private extension ItemRepository {
    func saveIfNeeded() throws {
        guard context.hasChanges else {
            print("💾 No changes to save")
            return
        }

        print("💾 Saving changes to Core Data...")
        print("   Inserted: \(context.insertedObjects.count), Updated: \(context.updatedObjects.count), Deleted: \(context.deletedObjects.count)")

        // Ensure we're on the correct thread for this context
        do {
            if Thread.isMainThread {
                try context.save()
            } else {
                try context.performAndWait {
                    try context.save()
                }
            }
            print("✅ Core Data save successful - CloudKit will sync automatically")
            print("   Note: CloudKit sync happens asynchronously in the background")
            print("   Watch for 'CloudKit Export' messages to confirm upload")
        } catch let error as NSError {
            print("❌ Core Data save failed: \(error.localizedDescription)")
            print("   Domain: \(error.domain), Code: \(error.code)")
            print("   UserInfo: \(error.userInfo)")

            // Try to provide helpful guidance
            if error.domain == NSCocoaErrorDomain && error.code == 134060 {
                print("   ⚠️ This is a validation error - likely schema mismatch")
                print("   ⚠️ Check that CloudKit Production schema matches app model")
            }

            throw error
        }
    }
}
