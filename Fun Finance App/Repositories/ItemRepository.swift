import CoreData
import UIKit

protocol ItemRepositoryProtocol {
    var currentMonthKey: String { get }
    var context: NSManagedObjectContext { get }
    func addItem(title: String, price: Decimal, notes: String?, tags: [String], productURL: String?, image: UIImage?) async throws
    func addItem(title: String, price: Decimal, notes: String?, tags: [String], productURL: String?, cachedImageFilename: String?) throws
    func preprocessAndCacheImage(_ image: UIImage) async throws -> String
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
        let filename: String
        if let image {
            filename = try await imageStore.save(image: image)
        } else {
            filename = ""
        }
        let item = WantedItemEntity(context: context)
        item.id = UUID()
        item.title = title
        item.price = NSDecimalNumber(decimal: price)
        item.notes = notes
        item.productText = nil
        item.productURL = productURL
        item.imagePath = filename
        item.tags = tags
        item.createdAt = Date()
        item.monthKey = monthKey(for: item.createdAt)
        item.status = .saved
        try saveIfNeeded()
    }

    func addItem(title: String, price: Decimal, notes: String?, tags: [String], productURL: String?, cachedImageFilename: String?) throws {
        // Fast path - image already processed and saved
        let item = WantedItemEntity(context: context)
        item.id = UUID()
        item.title = title
        item.price = NSDecimalNumber(decimal: price)
        item.notes = notes
        item.productText = nil
        item.productURL = productURL
        item.imagePath = cachedImageFilename ?? ""
        item.tags = tags
        item.createdAt = Date()
        item.monthKey = monthKey(for: item.createdAt)
        item.status = .saved
        try saveIfNeeded()
    }

    func preprocessAndCacheImage(_ image: UIImage) async throws -> String {
        // Process and save image in background - returns filename for later use
        return try await imageStore.save(image: image)
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
            // Delete old image if exists
            if !entity.imagePath.isEmpty {
                imageStore.deleteImage(named: entity.imagePath)
            }

            // Save new image if provided
            if let image = image {
                let filename = try await imageStore.save(image: image)
                entity.imagePath = filename
            } else {
                entity.imagePath = ""
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
}

private extension ItemRepository {
    func saveIfNeeded() throws {
        guard context.hasChanges else { return }

        // Ensure we're on the correct thread for this context
        if Thread.isMainThread {
            try context.save()
        } else {
            try context.performAndWait {
                try context.save()
            }
        }
    }
}
