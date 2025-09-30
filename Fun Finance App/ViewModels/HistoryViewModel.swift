import Combine
import CoreData
import Foundation
import UIKit

@MainActor
final class HistoryViewModel: ObservableObject {
    @Published var summaries: [MonthSummaryDisplay] = []
    @Published var sections: [HistorySection] = []

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
            let summaryEntities = try monthRepository.summaries()
            summaries = summaryEntities.map { entity in
                MonthSummaryDisplay(id: entity.id,
                                    monthKey: entity.monthKey,
                                    totalSaved: includeTax(on: entity.totalSaved.decimalValue),
                                    itemCount: Int(entity.itemCount),
                                    winnerItemId: entity.winnerItemId,
                                    closedAt: entity.closedAt)
            }

            let allItems = try itemRepository.allItems()
            sections = makeSections(from: allItems)
        } catch {
            assertionFailure("Failed to load history: \(error)")
        }
    }

    func items(for summaryId: UUID, filter: ItemStatus?) -> [WantedItemDisplay] {
        do {
            guard let summary = try monthRepository.summary(with: summaryId) else { return [] }
            let items = summary.wantedItems.filter { entity in
                guard let filter else { return true }
                return entity.status == filter
            }
            return items.map { entity in
                let tags = entity.tags.isEmpty ? (entity.productText.map { [$0] } ?? []) : entity.tags
                let basePrice = entity.price.decimalValue
                return WantedItemDisplay(id: entity.id,
                                         title: entity.title,
                                         price: basePrice,
                                         priceWithTax: includeTax(on: basePrice),
                                         notes: entity.notes,
                                         tags: tags,
                                         productURL: entity.productURL,
                                         imagePath: entity.imagePath,
                                         status: entity.status,
                                         createdAt: entity.createdAt)
            }
        } catch {
            assertionFailure("Failed to fetch summary items: \(error)")
            return []
        }
    }

    func image(for item: WantedItemDisplay) -> UIImage? {
        imageStore.loadImage(named: item.imagePath)
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
}

extension HistoryViewModel {
    struct HistorySection: Identifiable {
        let status: ItemStatus
        let title: String
        let items: [WantedItemDisplay]
        let subtotal: Decimal

        var id: ItemStatus { status }
    }
}

private extension HistoryViewModel {
    func makeSections(from entities: [WantedItemEntity]) -> [HistorySection] {
        let statuses: [ItemStatus] = [.redeemed, .skipped, .active]
        return statuses.compactMap { status in
            let filtered = entities.filter { $0.status == status }
            guard !filtered.isEmpty else { return nil }

            let displays = filtered
                .sorted(by: { $0.createdAt > $1.createdAt })
                .map { entity -> WantedItemDisplay in
                    let tags = entity.tags.isEmpty ? (entity.productText.map { [$0] } ?? []) : entity.tags
                    let basePrice = entity.price.decimalValue
                    return WantedItemDisplay(id: entity.id,
                                             title: entity.title,
                                             price: basePrice,
                                             priceWithTax: includeTax(on: basePrice),
                                             notes: entity.notes,
                                             tags: tags,
                                             productURL: entity.productURL,
                                             imagePath: entity.imagePath,
                                             status: entity.status,
                                             createdAt: entity.createdAt)
                }

            let subtotal = displays.reduce(.zero) { $0 + $1.priceWithTax }
            return HistorySection(status: status,
                                  title: title(for: status),
                                  items: displays,
                                  subtotal: subtotal)
        }
    }

    func title(for status: ItemStatus) -> String {
        switch status {
        case .active:
            return "Active"
        case .skipped:
            return "Skipped"
        case .redeemed:
            return "Redeemed"
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
