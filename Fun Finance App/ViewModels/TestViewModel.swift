import Foundation
import Combine
import UIKit
import CoreData

@MainActor
final class TestViewModel: ObservableObject {
    @Published var items: [WantedItemDisplay] = []
    @Published var totalSaved: Decimal = .zero
    @Published var itemCount: Int = 0
    @Published var testSummary: MonthSummaryEntity?
    @Published var pendingCloseout: MonthSummaryEntity?
    @Published var daysRemainingInWindow: Int?

    let haptics: HapticManager
    let settingsRepository: SettingsRepositoryProtocol

    private let itemRepository: ItemRepositoryProtocol
    private let monthRepository: MonthRepositoryProtocol
    private let rolloverService: RolloverService
    private let imageStore: ImageStoring
    private let calendar: Calendar
    private var taxRate: Decimal = .zero

    init(itemRepository: ItemRepositoryProtocol,
         monthRepository: MonthRepositoryProtocol,
         settingsRepository: SettingsRepositoryProtocol,
         imageStore: ImageStoring,
         haptics: HapticManager,
         calendar: Calendar = .current) {
        self.itemRepository = itemRepository
        self.monthRepository = monthRepository
        self.settingsRepository = settingsRepository
        self.imageStore = imageStore
        self.haptics = haptics
        self.calendar = calendar
        self.rolloverService = RolloverService(
            monthRepository: monthRepository,
            itemRepository: itemRepository,
            calendar: calendar
        )
    }

    func refresh() {
        do {
            taxRate = try settingsRepository.loadAppSettings().taxRate.decimalValue
            let items = try itemRepository.items(for: itemRepository.currentMonthKey)
            let displays = makeDisplays(from: items)
            self.items = displays
            totalSaved = displays.reduce(.zero) { $0 + $1.priceWithTax }
            itemCount = displays.count

            // Check for pending closeout
            pendingCloseout = try rolloverService.evaluateIfNeeded()

            // Calculate days remaining in claim window
            daysRemainingInWindow = rolloverService.daysRemainingInWindow()
        } catch {
            assertionFailure("Failed to fetch items: \(error)")
        }
    }

    func clearTestData() {
        do {
            let context = itemRepository.context

            // Delete all month summaries
            let summaryRequest = NSFetchRequest<MonthSummaryEntity>(entityName: "MonthSummary")
            let summaries = try context.fetch(summaryRequest)
            for summary in summaries {
                context.delete(summary)
            }

            // Delete all items
            let itemRequest = NSFetchRequest<WantedItemEntity>(entityName: "WantedItem")
            let items = try context.fetch(itemRequest)
            for item in items {
                context.delete(item)
            }

            if context.hasChanges {
                try context.save()
            }

            print("🧹 Reset complete - all data cleared")
        } catch {
            print("❌ Reset failed: \(error)")
        }
    }

    func createTestSummary() {
        do {
            let monthKey = itemRepository.currentMonthKey
            let context = itemRepository.context

            // Get existing items
            let items = try itemRepository.items(for: monthKey)

            // Reset all items to saved status
            for item in items {
                item.status = .saved
            }

            // If no items exist, create some test items
            if items.isEmpty {
                let testItems = [
                    ("Luxury Watch", Decimal(599.99), ["accessories", "luxury"]),
                    ("Premium Headphones", Decimal(349.99), ["audio", "tech"]),
                    ("Designer Bag", Decimal(450.00), ["fashion", "accessories"]),
                    ("Gaming Console", Decimal(499.99), ["gaming", "tech"])
                ]

                for (title, price, tags) in testItems {
                    let item = WantedItemEntity(context: context)
                    item.id = UUID()
                    item.title = title
                    item.price = NSDecimalNumber(decimal: price)
                    item.notes = "Test item for closeout"
                    item.productText = nil
                    item.productURL = nil
                    item.imagePath = ""
                    item.tags = tags
                    item.createdAt = Date()
                    item.monthKey = monthKey
                    item.status = .saved
                }
                try context.save()

                // Refresh to get the newly created items
                refresh()
            }

            // Now create the test summary with the items
            let updatedItems = try itemRepository.items(for: monthKey)
            print("🧪 Creating test summary with \(updatedItems.count) items")

            let summary = MonthSummaryEntity(context: context)
            summary.id = UUID()
            summary.monthKey = monthKey
            summary.totalSaved = NSDecimalNumber(decimal: totalSaved)
            summary.itemCount = Int32(updatedItems.count)
            summary.items = NSSet(array: updatedItems)
            summary.winnerItemId = nil
            summary.closedAt = nil

            print("🧪 Summary created with items NSSet count: \(summary.items?.count ?? 0)")
            print("🧪 Wanted items array count: \(summary.wantedItems.count)")

            // Save the summary to Core Data
            try context.save()

            // Refresh the context to ensure relationship is loaded
            context.refresh(summary, mergeChanges: true)

            print("🧪 After save - items NSSet count: \(summary.items?.count ?? 0)")
            print("🧪 After save - wanted items array count: \(summary.wantedItems.count)")

            testSummary = summary
        } catch {
            assertionFailure("Failed to create test summary: \(error)")
        }
    }

    func resetTestSummary() {
        do {
            guard let summary = testSummary else { return }

            // Reset all items back to saved status
            for item in summary.wantedItems {
                item.status = .saved
            }

            // Clear winner
            summary.winnerItemId = nil
            summary.closedAt = nil

            // Save changes
            try itemRepository.context.save()

            // Refresh to show updated state
            refresh()
        } catch {
            assertionFailure("Failed to reset test summary: \(error)")
        }
    }

    func clearAllData() {
        do {
            let context = itemRepository.context

            // Delete all items
            let allItems = try itemRepository.allItems()
            for item in allItems {
                context.delete(item)
            }

            // Delete all summaries
            let allSummaries = try monthRepository.summaries()
            for summary in allSummaries {
                context.delete(summary)
            }

            try context.save()

            // Refresh
            refresh()
        } catch {
            assertionFailure("Failed to clear all data: \(error)")
        }
    }

    func populateReviewTestData() {
        do {
            guard let previousDate = calendar.date(byAdding: .month, value: -1, to: Date()) else { return }
            let previousMonthKey = itemRepository.monthKey(for: previousDate)

            // Delete existing previous month items
            let existingItems = try itemRepository.items(for: previousMonthKey)
            for item in existingItems {
                try itemRepository.delete(item)
            }

            // Create sample items for review directly with previous month date
            let testItems = [
                ("Fancy Coffee Machine", Decimal(299.99), ["kitchen", "luxury"]),
                ("Designer Sneakers", Decimal(180.00), ["fashion", "shoes"]),
                ("Smart Watch", Decimal(399.99), ["tech", "fitness"]),
                ("Gaming Headset", Decimal(149.99), ["gaming", "audio"]),
                ("Leather Jacket", Decimal(450.00), ["fashion", "outerwear"])
            ]

            let context = itemRepository.context
            for (title, price, tags) in testItems {
                let item = WantedItemEntity(context: context)
                item.id = UUID()
                item.title = title
                item.price = NSDecimalNumber(decimal: price)
                item.notes = "Test item for review"
                item.productText = nil
                item.productURL = nil
                item.imagePath = ""
                item.tags = tags
                item.createdAt = previousDate
                item.monthKey = previousMonthKey
                item.status = .saved
            }

            try context.save()
        } catch {
            assertionFailure("Failed to populate review test data: \(error)")
        }
    }

    private func makeDisplays(from items: [WantedItemEntity]) -> [WantedItemDisplay] {
        items.map { entity in
            let tags = entity.tags.isEmpty ? (entity.productText.map { [$0] } ?? []) : entity.tags
            let basePrice = entity.price.decimalValue

            return WantedItemDisplay(id: entity.id,
                                     title: entity.title,
                                     price: basePrice,
                                     priceWithTax: includeTax(on: basePrice),
                                     notes: entity.notes,
                                     tags: tags,
                                     productURL: itemRepository.loadURL(for: entity),
                                     imagePath: entity.imagePath,
                                     imageData: entity.imageData,
                                     status: entity.status,
                                     createdAt: entity.createdAt)
        }
    }

    private func includeTax(on amount: Decimal) -> Decimal {
        guard taxRate > 0 else { return amount }
        var result = amount
        let multiplier = Decimal(1) + taxRate
        result *= multiplier
        return result
    }
}
