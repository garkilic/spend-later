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
    private let dayFormatter: DateFormatter

    init(monthRepository: MonthRepositoryProtocol,
         itemRepository: ItemRepositoryProtocol,
         imageStore: ImageStoring,
         calendar: Calendar = .current) {
        self.monthRepository = monthRepository
        self.itemRepository = itemRepository
        self.imageStore = imageStore
        self.calendar = calendar

        self.dayFormatter = DateFormatter()
        dayFormatter.dateStyle = .medium
        dayFormatter.timeStyle = .none
    }

    func refresh() {
        do {
            let summaryEntities = try monthRepository.summaries()
            summaries = summaryEntities.map { entity in
                MonthSummaryDisplay(id: entity.id,
                                    monthKey: entity.monthKey,
                                    totalSaved: entity.totalSaved.decimalValue,
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
                WantedItemDisplay(id: entity.id,
                                  title: entity.title,
                                  price: entity.price.decimalValue,
                                  notes: entity.notes,
                                  productText: entity.productText,
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
}

extension HistoryViewModel {
    struct HistorySection: Identifiable {
        let id: Date
        let title: String
        let items: [WantedItemDisplay]
    }
}

private extension HistoryViewModel {
    func makeSections(from entities: [WantedItemEntity]) -> [HistorySection] {
        let grouped = Dictionary(grouping: entities) { calendar.startOfDay(for: $0.createdAt) }

        return grouped.map { date, groupedItems in
            let displays = groupedItems
                .sorted(by: { $0.createdAt > $1.createdAt })
                .map { entity in
                    WantedItemDisplay(id: entity.id,
                                      title: entity.title,
                                      price: entity.price.decimalValue,
                                      notes: entity.notes,
                                      productText: entity.productText,
                                      productURL: entity.productURL,
                                      imagePath: entity.imagePath,
                                      status: entity.status,
                                      createdAt: entity.createdAt)
                }

            return HistorySection(id: date,
                                   title: dayFormatter.string(from: date),
                                   items: displays)
        }
        .sorted { $0.id > $1.id }
    }
}
