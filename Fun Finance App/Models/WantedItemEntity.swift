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
    @NSManaged var createdAt: Date
    @NSManaged var monthKey: String
    @NSManaged var statusRaw: String
    @NSManaged var summary: MonthSummaryEntity?

    var status: ItemStatus {
        get { ItemStatus(rawValue: statusRaw) ?? .active }
        set { statusRaw = newValue.rawValue }
    }
}

extension WantedItemEntity {
    static func fetchRequest(forMonthKey monthKey: String) -> NSFetchRequest<WantedItemEntity> {
        let request = NSFetchRequest<WantedItemEntity>(entityName: "WantedItem")
        request.predicate = NSPredicate(format: "monthKey == %@", monthKey)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \WantedItemEntity.createdAt, ascending: false)]
        return request
    }
}
