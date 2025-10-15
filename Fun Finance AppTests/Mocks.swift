import Foundation
import CoreData
import UIKit
@testable import Fun_Finance_App

// MARK: - Mock Item Repository
class MockItemRepository: ItemRepositoryProtocol {
    let context: NSManagedObjectContext = PersistenceController.preview.container.viewContext
    var itemsToReturn: [WantedItemEntity] = []
    var deletedItems: [WantedItemEntity] = []
    var addedItems: [(title: String, price: Decimal)] = []

    var currentMonthKey: String = "2025,09"

    func addItem(title: String, price: Decimal, notes: String?, tags: [String], productURL: String?, image: UIImage?) async throws {
        addedItems.append((title, price))
    }

    func addItem(title: String, price: Decimal, notes: String?, tags: [String], productURL: String?, cachedImageFilename: String?) throws {
        addedItems.append((title, price))
    }

    func preprocessAndCacheImage(_ image: UIImage) async throws -> String {
        let filename = UUID().uuidString
        return filename
    }

    func items(for monthKey: String) throws -> [WantedItemEntity] {
        return itemsToReturn
    }

    func activeItems(for monthKey: String) throws -> [WantedItemEntity] {
        return itemsToReturn.filter { $0.status == .saved }
    }

    func allItems() throws -> [WantedItemEntity] {
        return itemsToReturn
    }

    func delete(_ item: WantedItemEntity) throws {
        deletedItems.append(item)
        itemsToReturn.removeAll { $0.id == item.id }
    }

    func restore(_ snapshot: ItemSnapshot) throws {
        // Mock implementation
    }

    func makeSnapshot(from item: WantedItemEntity) -> ItemSnapshot {
        return ItemSnapshot(
            id: item.id,
            title: item.title,
            price: item.price.decimalValue,
            notes: item.notes,
            tags: item.tags,
            productURL: item.productURL,
            imagePath: item.imagePath,
            createdAt: item.createdAt,
            monthKey: item.monthKey,
            status: item.status
        )
    }

    func monthKey(for date: Date) -> String {
        return currentMonthKey
    }

    func item(with id: UUID) throws -> WantedItemEntity? {
        return itemsToReturn.first { $0.id == id }
    }

    func updateItem(id: UUID, title: String, notes: String?, tags: [String], productURL: String?) throws {
        // Mock implementation
    }

    func updateItem(id: UUID, title: String, price: Decimal?, notes: String?, tags: [String], productURL: String?, image: UIImage?, replaceImage: Bool) async throws {
        // Mock implementation
    }

    func markAsBought(itemId: UUID) throws {
        // Mock implementation
    }

    func markAsSaved(itemId: UUID) throws {
        // Mock implementation
    }
}

// MARK: - Mock Month Repository
class MockMonthRepository: MonthRepositoryProtocol {
    var summariesToReturn: [MonthSummaryEntity] = []
    var rolledMonth: MonthSummaryEntity?

    func rollIfNeeded(currentDate: Date) throws -> MonthSummaryEntity? {
        return rolledMonth
    }

    func createSummary(for monthKey: String) throws -> MonthSummaryEntity {
        let summary = MonthSummaryEntity(context: PersistenceController.preview.container.viewContext)
        summary.id = UUID()
        summary.monthKey = monthKey
        summary.totalSaved = .zero
        summary.itemCount = 0
        return summary
    }

    func summaries() throws -> [MonthSummaryEntity] {
        return summariesToReturn
    }

    func summary(for monthKey: String) throws -> MonthSummaryEntity? {
        return summariesToReturn.first { $0.monthKey == monthKey }
    }

    func summary(with id: UUID) throws -> MonthSummaryEntity? {
        return summariesToReturn.first { $0.id == id }
    }
}

// MARK: - Mock Settings Repository
class MockSettingsRepository: SettingsRepositoryProtocol {
    var taxRate: Decimal = 0.0
    var passcodeEnabled: Bool = false
    private let context = PersistenceController.preview.container.viewContext

    func loadAppSettings() throws -> AppSettingsEntity {
        let settings = AppSettingsEntity(context: context)
        settings.id = UUID()
        settings.taxRate = NSDecimalNumber(decimal: taxRate)
        settings.currencyCode = "USD"
        settings.passcodeEnabled = passcodeEnabled
        settings.weeklyReminderEnabled = false
        settings.monthlyReminderEnabled = false
        return settings
    }

    func updatePasscodeEnabled(_ enabled: Bool, key: String?) throws {
        passcodeEnabled = enabled
    }

    func updateReminderPrefs(weekly: Bool, monthly: Bool) throws {
        // Mock implementation
    }

    func updateCurrencyCode(_ code: String) throws {
        // Mock implementation
    }

    func updateTaxRate(_ rate: Decimal) throws {
        taxRate = rate
    }
}

// MARK: - Mock Image Store
class MockImageStore: ImageStoring {
    var savedImages: [String: UIImage] = [:]

    func save(image: UIImage) async throws -> String {
        let filename = UUID().uuidString
        savedImages[filename] = image
        return filename
    }

    func loadImage(named filename: String) -> UIImage? {
        return savedImages[filename]
    }

    func deleteImage(named filename: String) {
        savedImages.removeValue(forKey: filename)
    }
}

// MARK: - Mock Haptic Manager
class MockHapticManager: HapticFeedback {
    var successCalled = false
    var warningCalled = false
    var errorCalled = false

    func success() {
        successCalled = true
    }

    func warning() {
        warningCalled = true
    }

    func error() {
        errorCalled = true
    }

    func lightImpact() {}
    func mediumImpact() {}
    func heavyImpact() {}
}
