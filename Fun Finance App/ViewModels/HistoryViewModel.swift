import Combine
import CoreData
import Foundation
import UIKit

@MainActor
final class HistoryViewModel: ObservableObject {
    @Published var summaries: [MonthSummaryDisplay] = []

    private let monthRepository: MonthRepositoryProtocol
    private let imageStore: ImageStoring

    init(monthRepository: MonthRepositoryProtocol, imageStore: ImageStoring) {
        self.monthRepository = monthRepository
        self.imageStore = imageStore
    }

    func refresh() {
        do {
            let entities = try monthRepository.summaries()
            summaries = entities.map { entity in
                MonthSummaryDisplay(id: entity.id,
                                    monthKey: entity.monthKey,
                                    totalSaved: entity.totalSaved.decimalValue,
                                    itemCount: Int(entity.itemCount),
                                    winnerItemId: entity.winnerItemId,
                                    closedAt: entity.closedAt)
            }
        } catch {
            assertionFailure("Failed to fetch summaries: \(error)")
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
