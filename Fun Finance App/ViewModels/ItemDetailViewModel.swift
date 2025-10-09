import Combine
import CoreData
import Foundation
import UIKit

@MainActor
final class ItemDetailViewModel: ObservableObject {
    @Published private(set) var item: WantedItemDisplay
    @Published var title: String
    @Published var notes: String
    @Published var tagsText: String
    @Published var productURLText: String
    @Published var priceText: String
    @Published var editedImage: UIImage?
    @Published var hasImageChanged: Bool = false
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
        self.priceText = String(describing: item.price)
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
                priceText = String(describing: updatedDisplay.price)
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

        // Parse price
        let price: Decimal?
        if let parsedPrice = Decimal(string: priceText.trimmingCharacters(in: .whitespacesAndNewlines)) {
            guard parsedPrice >= 0 else {
                errorMessage = "Price must be positive."
                return
            }
            price = parsedPrice
        } else {
            errorMessage = "Invalid price format."
            return
        }

        let normalizedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedURL = productURLText.trimmingCharacters(in: .whitespacesAndNewlines)
        let tags = normalizedTags()

        do {
            try itemRepository.updateItem(id: item.id,
                                          title: trimmedTitle,
                                          price: price,
                                          notes: normalizedNotes.isEmpty ? nil : normalizedNotes,
                                          tags: tags,
                                          productURL: normalizedURL.isEmpty ? nil : normalizedURL,
                                          image: editedImage,
                                          replaceImage: hasImageChanged)
            hasImageChanged = false
            editedImage = nil
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

    func markAsBought() {
        do {
            try itemRepository.markAsBought(itemId: item.id)
            refreshFromStore()
            errorMessage = nil
        } catch {
            errorMessage = "Could not mark as bought."
        }
    }

    func markAsSaved() {
        do {
            try itemRepository.markAsSaved(itemId: item.id)
            refreshFromStore()
            errorMessage = nil
        } catch {
            errorMessage = "Could not mark as saved."
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
