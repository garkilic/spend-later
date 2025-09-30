import CoreData

@objc(MonthSummaryEntity)
final class MonthSummaryEntity: NSManagedObject {
    @NSManaged var id: UUID
    @NSManaged var monthKey: String
    @NSManaged var totalSaved: NSDecimalNumber
    @NSManaged var itemCount: Int32
    @NSManaged var winnerItemId: UUID?
    @NSManaged var closedAt: Date?

    @NSManaged var items: NSSet?
}

extension MonthSummaryEntity {
    var wantedItems: [WantedItemEntity] {
        (items?.allObjects as? [WantedItemEntity]) ?? []
    }

    static func fetchRequest(forMonthKey monthKey: String) -> NSFetchRequest<MonthSummaryEntity> {
        let request = NSFetchRequest<MonthSummaryEntity>(entityName: "MonthSummary")
        request.predicate = NSPredicate(format: "monthKey == %@", monthKey)
        request.fetchLimit = 1
        return request
    }
}

extension MonthSummaryEntity: Identifiable {}
