import CoreData

protocol MonthRepositoryProtocol {
    func rollIfNeeded(currentDate: Date) throws -> MonthSummaryEntity?
    func createSummary(for monthKey: String) throws -> MonthSummaryEntity
    func summaries() throws -> [MonthSummaryEntity]
    func summary(for monthKey: String) throws -> MonthSummaryEntity?
    func summary(with id: UUID) throws -> MonthSummaryEntity?
}

final class MonthRepository: MonthRepositoryProtocol {
    let context: NSManagedObjectContext
    private let itemRepository: ItemRepositoryProtocol
    private let calendar: Calendar

    init(context: NSManagedObjectContext, itemRepository: ItemRepositoryProtocol, calendar: Calendar = .current) {
        self.context = context
        self.itemRepository = itemRepository
        self.calendar = calendar
    }

    func rollIfNeeded(currentDate: Date) throws -> MonthSummaryEntity? {
        guard let previousMonthDate = calendar.date(byAdding: .month, value: -1, to: currentDate) else { return nil }
        let previousKey = itemRepository.monthKey(for: previousMonthDate)
        guard try summary(for: previousKey) == nil else { return nil }
        let items = try itemRepository.activeItems(for: previousKey)
        guard !items.isEmpty else { return nil }
        return try createSummary(for: previousKey, with: items)
    }

    func createSummary(for monthKey: String) throws -> MonthSummaryEntity {
        let items = try itemRepository.items(for: monthKey)
        return try createSummary(for: monthKey, with: items)
    }

    func summaries() throws -> [MonthSummaryEntity] {
        let request = NSFetchRequest<MonthSummaryEntity>(entityName: "MonthSummary")
        request.sortDescriptors = [NSSortDescriptor(key: "monthKey", ascending: false)]
        return try context.fetch(request)
    }

    func summary(for monthKey: String) throws -> MonthSummaryEntity? {
        let request = MonthSummaryEntity.fetchRequest(forMonthKey: monthKey)
        return try context.fetch(request).first
    }

    func summary(with id: UUID) throws -> MonthSummaryEntity? {
        let request = NSFetchRequest<MonthSummaryEntity>(entityName: "MonthSummary")
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try context.fetch(request).first
    }
}

private extension MonthRepository {
    func createSummary(for monthKey: String, with items: [WantedItemEntity]) throws -> MonthSummaryEntity {
        guard !items.isEmpty else {
            throw NSError(domain: "MonthRepository", code: 0, userInfo: [NSLocalizedDescriptionKey: "No items to summarize"])
        }
        let summary = MonthSummaryEntity(context: context)
        summary.id = UUID()
        summary.monthKey = monthKey
        let total = items.reduce(Decimal.zero) { partialResult, item in
            partialResult + item.price.decimalValue
        }
        summary.totalSaved = NSDecimalNumber(decimal: total)
        summary.itemCount = Int32(items.count)
        summary.winnerItemId = nil
        summary.closedAt = nil
        for item in items {
            item.summary = summary
        }
        if context.hasChanges {
            try context.save()
        }
        return summary
    }
}
