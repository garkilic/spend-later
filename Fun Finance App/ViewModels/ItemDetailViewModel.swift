import Combine
import CoreData
import Foundation

@MainActor
final class ItemDetailViewModel: ObservableObject {
    @Published private(set) var item: WantedItemDisplay
    @Published var title: String
    @Published var notes: String
    @Published var tagsText: String
    @Published var productURLText: String
    @Published var errorMessage: String?
    @Published var isSaving: Bool = false

    private let itemRepository: ItemRepositoryProtocol
    private let settingsRepository: SettingsRepositoryProtocol
    private var taxRate: Decimal = .zero

    init(item: WantedItemDisplay,
         itemRepository: ItemRepositoryProtocol,
         settingsRepository: SettingsRepositoryProtocol) {
        self.item = item
        self.itemRepository = itemRepository
        self.settingsRepository = settingsRepository
        self.title = item.title
        self.notes = item.notes ?? ""
        self.tagsText = item.tags.joined(separator: ", ")
        self.productURLText = item.productURL ?? ""
        refreshFromStore()
    }

    func refreshFromStore() {
        do {
            taxRate = try settingsRepository.loadAppSettings().taxRate.decimalValue
            if let entity = try itemRepository.item(with: item.id) {
                let updatedDisplay = makeDisplay(from: entity)
                item = updatedDisplay
                title = updatedDisplay.title
                notes = updatedDisplay.notes ?? ""
                tagsText = updatedDisplay.tags.joined(separator: ", ")
                productURLText = updatedDisplay.productURL ?? ""
            }
        } catch {
            errorMessage = "Unable to load item."
        }
    }

    func saveChanges() {
        isSaving = true
        defer { isSaving = false }
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            errorMessage = "Title is required."
            return
        }

        let normalizedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedURL = productURLText.trimmingCharacters(in: .whitespacesAndNewlines)
        let tags = normalizedTags()

        do {
            try itemRepository.updateItem(id: item.id,
                                          title: trimmedTitle,
                                          notes: normalizedNotes.isEmpty ? nil : normalizedNotes,
                                          tags: tags,
                                          productURL: normalizedURL.isEmpty ? nil : normalizedURL)
            refreshFromStore()
            errorMessage = nil
        } catch {
            errorMessage = "Could not save changes."
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

    private func normalizedTags() -> [String] {
        tagsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func includeTax(on amount: Decimal) -> Decimal {
        guard taxRate > 0 else { return amount }
        var result = amount
        let multiplier = Decimal(1) + taxRate
        result *= multiplier
        return result
    }
}
