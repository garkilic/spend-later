import Combine
import CoreData
import Foundation
import UIKit

@MainActor
final class MonthCloseoutViewModel: ObservableObject {
    @Published var items: [WantedItemDisplay] = []
    @Published var winner: WantedItemDisplay?
    @Published var isDrawing: Bool = false

    private let summary: MonthSummaryEntity
    private let context: NSManagedObjectContext
    private let haptics: HapticManager

    init(summary: MonthSummaryEntity, haptics: HapticManager) {
        self.summary = summary
        self.context = summary.managedObjectContext ?? PersistenceController.shared.container.viewContext
        self.haptics = haptics
        reload()
    }

    var title: String {
        MonthFormatter.displayName(for: summary.monthKey)
    }

    var canDraw: Bool {
        summary.winnerItemId == nil
    }

    func reload() {
        let entities = summary.wantedItems
        items = entities.map { entity in
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
        if let winnerId = summary.winnerItemId,
           let winnerEntity = entities.first(where: { $0.id == winnerId }) {
            winner = WantedItemDisplay(id: winnerEntity.id,
                                       title: winnerEntity.title,
                                       price: winnerEntity.price.decimalValue,
                                       notes: winnerEntity.notes,
                                       productText: winnerEntity.productText,
                                       productURL: winnerEntity.productURL,
                                       imagePath: winnerEntity.imagePath,
                                       status: winnerEntity.status,
                                       createdAt: winnerEntity.createdAt)
        }
    }

    func drawWinner() {
        guard canDraw else { return }
        let candidates = summary.wantedItems.filter { $0.status == .active }
        guard let winnerEntity = candidates.randomElement() else { return }
        isDrawing = true
        defer { isDrawing = false }

        for item in summary.wantedItems {
            if item.id == winnerEntity.id {
                item.status = .redeemed
            } else {
                item.status = .skipped
            }
        }
        summary.winnerItemId = winnerEntity.id
        summary.closedAt = Date()

        do {
            try context.save()
            haptics.success()
            reload()
        } catch {
            assertionFailure("Failed to save draw: \(error)")
        }
    }
}
