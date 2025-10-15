import CoreData
import UIKit

@objc(WantedItemEntity)
final class WantedItemEntity: NSManagedObject {
    @NSManaged var id: UUID
    @NSManaged var title: String
    @NSManaged var price: NSDecimalNumber
    @NSManaged var notes: String?
    @NSManaged var productText: String?
    @NSManaged var productURL: String?
    @NSManaged var imagePath: String
    @NSManaged var imageData: Data? // CloudKit-synced as CKAsset (external storage)
    @NSManaged var tagsRaw: String?
    @NSManaged var createdAt: Date
    @NSManaged var monthKey: String
    @NSManaged var statusRaw: String
    @NSManaged var actuallyPurchased: Bool
    @NSManaged var summary: MonthSummaryEntity?

    var status: ItemStatus {
        get { ItemStatus(rawValue: statusRaw) ?? .saved }
        set { statusRaw = newValue.rawValue }
    }

    var isBought: Bool {
        return status == .bought
    }
}

extension WantedItemEntity {
    var tags: [String] {
        get {
            guard let tagsRaw else { return [] }
            return tagsRaw
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }
        set {
            let joined = newValue
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .joined(separator: ",")
            tagsRaw = joined.isEmpty ? nil : joined
        }
    }

    static func fetchRequest(forMonthKey monthKey: String) -> NSFetchRequest<WantedItemEntity> {
        let request = NSFetchRequest<WantedItemEntity>(entityName: "WantedItem")
        request.predicate = NSPredicate(format: "monthKey == %@", monthKey)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \WantedItemEntity.createdAt, ascending: false)]
        return request
    }
}
