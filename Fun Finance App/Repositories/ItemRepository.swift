import CoreData
import UIKit

protocol ItemRepositoryProtocol {
    var currentMonthKey: String { get }
    func addItem(title: String, price: Decimal, notes: String?, productText: String?, image: UIImage?) throws
    func items(for monthKey: String) throws -> [WantedItemEntity]
    func activeItems(for monthKey: String) throws -> [WantedItemEntity]
    func allItems() throws -> [WantedItemEntity]
    func delete(_ item: WantedItemEntity) throws
    func restore(_ snapshot: ItemSnapshot) throws
    func makeSnapshot(from item: WantedItemEntity) -> ItemSnapshot
    func monthKey(for date: Date) -> String
    func item(with id: UUID) throws -> WantedItemEntity?
}

struct ItemSnapshot {
    let id: UUID
    let title: String
    let price: Decimal
    let notes: String?
    let productText: String?
    let imagePath: String
    let createdAt: Date
    let monthKey: String
    let status: ItemStatus
}

final class ItemRepository: ItemRepositoryProtocol {
    private let context: NSManagedObjectContext
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

    func addItem(title: String, price: Decimal, notes: String?, productText: String?, image: UIImage?) throws {
        let filename: String
        if let image {
            filename = try imageStore.save(image: image)
        } else {
            filename = ""
        }
        let item = WantedItemEntity(context: context)
        item.id = UUID()
        item.title = title
        item.price = NSDecimalNumber(decimal: price)
        item.notes = notes
        item.productText = productText
        item.imagePath = filename
        item.createdAt = Date()
        item.monthKey = monthKey(for: item.createdAt)
        item.status = .active
        try saveIfNeeded()
    }

    func items(for monthKey: String) throws -> [WantedItemEntity] {
        let request = WantedItemEntity.fetchRequest(forMonthKey: monthKey)
        return try context.fetch(request)
    }

    func activeItems(for monthKey: String) throws -> [WantedItemEntity] {
        let request = WantedItemEntity.fetchRequest(forMonthKey: monthKey)
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "monthKey == %@", monthKey),
            NSPredicate(format: "statusRaw == %@", ItemStatus.active.rawValue)
        ])
        return try context.fetch(request)
    }

    func allItems() throws -> [WantedItemEntity] {
        let request = NSFetchRequest<WantedItemEntity>(entityName: "WantedItem")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \WantedItemEntity.createdAt, ascending: false)]
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
        item.productText = snapshot.productText
        item.imagePath = snapshot.imagePath
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
                     productText: item.productText,
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
}

private extension ItemRepository {
    func saveIfNeeded() throws {
        if context.hasChanges {
            try context.save()
        }
    }
}
