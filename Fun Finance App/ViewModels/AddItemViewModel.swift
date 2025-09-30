import Combine
import Foundation
import UIKit

@MainActor
final class AddItemViewModel: ObservableObject {
    @Published var title: String = ""
    @Published var price: Decimal = .zero
    @Published var notes: String = ""
    @Published var productText: String = ""
    @Published var image: UIImage?
    @Published var isSaving: Bool = false
    @Published var errorMessage: String?

    private let itemRepository: ItemRepositoryProtocol

    init(itemRepository: ItemRepositoryProtocol) {
        self.itemRepository = itemRepository
    }

    var isValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && price > 0
    }

    func save() async -> Bool {
        guard isValid else {
            errorMessage = "Enter a title and dollar amount to save."
            return false
        }
        isSaving = true
        defer { isSaving = false }
        do {
            try itemRepository.addItem(title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                                       price: price,
                                       notes: notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : notes,
                                       productText: productText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : productText,
                                       image: image)
            clear()
            return true
        } catch {
            errorMessage = "Could not save item."
            return false
        }
    }

    func clear() {
        title = ""
        price = .zero
        notes = ""
        productText = ""
        image = nil
        errorMessage = nil
    }
}
