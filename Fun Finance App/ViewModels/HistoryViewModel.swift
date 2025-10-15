import Combine
import CoreData
import Foundation
import SwiftUI
import UIKit

@MainActor
final class HistoryViewModel: ObservableObject {
    @Published var monthSections: [MonthSection] = []

    private let monthRepository: MonthRepositoryProtocol
    private let itemRepository: ItemRepositoryProtocol
    private let imageStore: ImageStoring
    private let calendar: Calendar
    private let settingsRepository: SettingsRepositoryProtocol
    private var taxRate: Decimal = .zero

    init(monthRepository: MonthRepositoryProtocol,
         itemRepository: ItemRepositoryProtocol,
         imageStore: ImageStoring,
         settingsRepository: SettingsRepositoryProtocol,
         calendar: Calendar = .current) {
        self.monthRepository = monthRepository
        self.itemRepository = itemRepository
        self.imageStore = imageStore
        self.settingsRepository = settingsRepository
        self.calendar = calendar
    }

    func refresh() {
        do {
            try reloadTaxRate()
            let allItems = try itemRepository.allItems()
            monthSections = makeMonthSections(from: allItems)
        } catch {
            assertionFailure("Failed to load history: \(error)")
        }
    }

    func image(for item: WantedItemDisplay) -> UIImage? {
        // Load from file-based imagePath (local-only images)
        if !item.imagePath.isEmpty {
            return imageStore.loadImage(named: item.imagePath)
        }
        return nil
    }

    func items(for summaryId: UUID, filter: ItemStatus?) -> [WantedItemDisplay] {
        do {
            guard let summary = try monthRepository.summary(with: summaryId) else { return [] }
            let items = summary.wantedItems.filter { entity in
                guard let filter else { return true }
                return entity.status == filter
            }
            return makeDisplays(from: Array(items))
        } catch {
            assertionFailure("Failed to fetch summary items: \(error)")
            return []
        }
    }

    func delete(_ display: WantedItemDisplay) {
        do {
            guard let entity = try itemRepository.item(with: display.id) else { return }
            let path = entity.imagePath
            try itemRepository.delete(entity)
            imageStore.deleteImage(named: path)
            refresh()
        } catch {
            assertionFailure("Failed to delete item: \(error)")
        }
    }

    func markAsBought(_ display: WantedItemDisplay) {
        do {
            try itemRepository.markAsBought(itemId: display.id)
            refresh()
        } catch {
            assertionFailure("Failed to mark as bought: \(error)")
        }
    }

    func markAsSaved(_ display: WantedItemDisplay) {
        do {
            try itemRepository.markAsSaved(itemId: display.id)
            refresh()
        } catch {
            assertionFailure("Failed to mark as saved: \(error)")
        }
    }
}

extension HistoryViewModel {
    struct MonthSection: Identifiable {
        let monthKey: String
        let monthName: String
        let statusSections: [StatusSection]
        let totalSaved: Decimal // saved total
        let totalBought: Decimal // bought total
        let netSaved: Decimal // saved - bought

        var id: String { monthKey }
    }

    struct StatusSection: Identifiable {
        let status: ItemStatus
        let title: String
        let items: [WantedItemDisplay]
        let subtotal: Decimal

        var id: ItemStatus { status }
    }
}

private extension HistoryViewModel {
    func makeMonthSections(from entities: [WantedItemEntity]) -> [MonthSection] {
        // Group items by month
        let groupedByMonth = Dictionary(grouping: entities) { $0.monthKey }

        // Sort month keys in descending order (newest first)
        let sortedMonthKeys = groupedByMonth.keys.sorted(by: >)

        return sortedMonthKeys.compactMap { monthKey in
            guard let monthItems = groupedByMonth[monthKey] else { return nil }

            // Group by status within the month
            let savedItems = monthItems.filter { $0.status == .saved }
            let boughtItems = monthItems.filter { $0.status == .bought }
            let wonItems = monthItems.filter { $0.status == .won }

            // Create status sections
            var statusSections: [StatusSection] = []

            // Saved section
            if !savedItems.isEmpty {
                let displays = makeDisplays(from: savedItems)
                let subtotal = displays.reduce(.zero) { $0 + $1.priceWithTax }
                statusSections.append(StatusSection(
                    status: .saved,
                    title: "Saved",
                    items: displays,
                    subtotal: subtotal
                ))
            }

            // Bought section
            if !boughtItems.isEmpty {
                let displays = makeDisplays(from: boughtItems)
                let subtotal = displays.reduce(.zero) { $0 + $1.priceWithTax }
                statusSections.append(StatusSection(
                    status: .bought,
                    title: "Bought",
                    items: displays,
                    subtotal: subtotal
                ))
            }

            // Won section
            if !wonItems.isEmpty {
                let displays = makeDisplays(from: wonItems)
                let subtotal = displays.reduce(.zero) { $0 + $1.priceWithTax }
                statusSections.append(StatusSection(
                    status: .won,
                    title: "Won",
                    items: displays,
                    subtotal: subtotal
                ))
            }

            guard !statusSections.isEmpty else { return nil }

            // Calculate totals
            let totalSaved = statusSections.first { $0.status == .saved }?.subtotal ?? .zero
            let totalBought = statusSections.first { $0.status == .bought }?.subtotal ?? .zero
            let netSaved = totalSaved - totalBought

            return MonthSection(
                monthKey: monthKey,
                monthName: MonthFormatter.displayName(for: monthKey),
                statusSections: statusSections,
                totalSaved: totalSaved,
                totalBought: totalBought,
                netSaved: netSaved
            )
        }
    }

    func makeDisplays(from entities: [WantedItemEntity]) -> [WantedItemDisplay] {
        entities
            .sorted(by: { $0.createdAt > $1.createdAt })
            .map { entity -> WantedItemDisplay in
                let tags = entity.tags.isEmpty ? (entity.productText.map { [$0] } ?? []) : entity.tags
                let basePrice = entity.price.decimalValue

                return WantedItemDisplay(
                    id: entity.id,
                    title: entity.title,
                    price: basePrice,
                    priceWithTax: includeTax(on: basePrice),
                    notes: entity.notes,
                    tags: tags,
                    productURL: entity.productURL,
                    imagePath: entity.imagePath,
                    imageData: nil, // imageData removed from schema
                    status: entity.status,
                    createdAt: entity.createdAt
                )
            }
    }

    func includeTax(on amount: Decimal) -> Decimal {
        guard taxRate > 0 else { return amount }
        var result = amount
        let multiplier = Decimal(1) + taxRate
        result *= multiplier
        return result
    }

    func reloadTaxRate() throws {
        let settings = try settingsRepository.loadAppSettings()
        taxRate = settings.taxRate.decimalValue
    }
}
