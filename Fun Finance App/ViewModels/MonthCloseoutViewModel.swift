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
    private let haptics: HapticFeedback
    private let settingsRepository: SettingsRepositoryProtocol
    private var taxRate: Decimal = .zero

    init(summary: MonthSummaryEntity,
         haptics: HapticFeedback,
         settingsRepository: SettingsRepositoryProtocol) {
        self.summary = summary
        self.context = summary.managedObjectContext ?? PersistenceController.shared.container.viewContext
        self.haptics = haptics
        self.settingsRepository = settingsRepository
        reload()
    }

    var title: String {
        MonthFormatter.displayName(for: summary.monthKey)
    }

    var canDraw: Bool {
        summary.winnerItemId == nil
    }

    func reload() {
        taxRate = (try? settingsRepository.loadAppSettings().taxRate.decimalValue) ?? .zero
        let entities = summary.wantedItems
        print("📊 MonthCloseoutViewModel reload: \(entities.count) items from summary")
        print("📊 Summary items NSSet count: \(summary.items?.count ?? 0)")
        items = entities.map { entity in
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
        if let winnerId = summary.winnerItemId,
           let winnerEntity = entities.first(where: { $0.id == winnerId }) {
            let winnerTags = winnerEntity.tags.isEmpty ? (winnerEntity.productText.map { [$0] } ?? []) : winnerEntity.tags
            let winnerPrice = winnerEntity.price.decimalValue

            winner = WantedItemDisplay(id: winnerEntity.id,
                                       title: winnerEntity.title,
                                       price: winnerPrice,
                                       priceWithTax: includeTax(on: winnerPrice),
                                       notes: winnerEntity.notes,
                                       tags: winnerTags,
                                       productURL: winnerEntity.productURL,
                                       imagePath: winnerEntity.imagePath,
                                       status: winnerEntity.status,
                                       createdAt: winnerEntity.createdAt)
        }
    }

    func drawWinner() {
        guard canDraw else { return }
        let candidates = summary.wantedItems.filter { $0.status == .saved }
        guard let winnerEntity = candidates.randomElement() else { return }
        isDrawing = true
        defer { isDrawing = false }

        // Mark winner as won, others stay saved
        for item in summary.wantedItems {
            if item.id == winnerEntity.id {
                item.status = .won
            }
            // Others remain .saved - no change needed
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

    func setWinner(_ display: WantedItemDisplay) {
        guard canDraw else { return }
        guard let winnerEntity = summary.wantedItems.first(where: { $0.id == display.id }) else { return }

        isDrawing = true
        defer { isDrawing = false }

        // Mark winner as won, others stay saved
        for item in summary.wantedItems {
            if item.id == winnerEntity.id {
                item.status = .won
            }
            // Others remain .saved - no change needed
        }
        summary.winnerItemId = winnerEntity.id
        summary.closedAt = Date()

        do {
            try context.save()
            reload()
        } catch {
            assertionFailure("Failed to save draw: \(error)")
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
