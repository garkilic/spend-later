import Combine
import CoreData
import Foundation
import UIKit

@MainActor
final class ReviewItemsViewModel: ObservableObject {
    struct ReviewCard: Identifiable {
        let id: UUID
        let item: WantedItemDisplay
    }

    @Published private(set) var pendingCards: [ReviewCard] = []
    @Published private(set) var kept: [ReviewCard] = []
    @Published private(set) var dismissed: [ReviewCard] = []

    private let itemRepository: ItemRepositoryProtocol
    private let imageStore: ImageStoring
    private let settingsRepository: SettingsRepositoryProtocol
    private let calendar: Calendar
    private var taxRate: Decimal = .zero

    init(itemRepository: ItemRepositoryProtocol,
         imageStore: ImageStoring,
         settingsRepository: SettingsRepositoryProtocol,
         calendar: Calendar = .current) {
        self.itemRepository = itemRepository
        self.imageStore = imageStore
        self.settingsRepository = settingsRepository
        self.calendar = calendar
        load()
    }

    func image(for card: ReviewCard) -> UIImage? {
        imageStore.loadImage(named: card.item.imagePath)
    }

    func markTop(as status: Status) {
        guard let card = pendingCards.first else { return }
        pendingCards.removeFirst()
        switch status {
        case .keep:
            kept.append(card)
        case .dismiss:
            dismissed.append(card)
        }
    }

    func reset() {
        kept.removeAll()
        dismissed.removeAll()
        load()
    }
}

extension ReviewItemsViewModel {
    enum Status {
        case keep
        case dismiss
    }
}

private extension ReviewItemsViewModel {
    func load() {
        do {
            taxRate = try settingsRepository.loadAppSettings().taxRate.decimalValue
            guard let previousDate = calendar.date(byAdding: .month, value: -1, to: Date()) else {
                pendingCards = []
                return
            }
            let monthKey = itemRepository.monthKey(for: previousDate)
            let entities = try itemRepository.items(for: monthKey)
                .filter { $0.status == .active }
                .sorted(by: { $0.createdAt > $1.createdAt })
            pendingCards = entities.map { entity in
                ReviewCard(id: entity.id, item: makeDisplay(from: entity))
            }
        } catch {
            pendingCards = []
        }
    }

    func makeDisplay(from entity: WantedItemEntity) -> WantedItemDisplay {
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

    func includeTax(on amount: Decimal) -> Decimal {
        guard taxRate > 0 else { return amount }
        var result = amount
        let multiplier = Decimal(1) + taxRate
        result *= multiplier
        return result
    }
}
