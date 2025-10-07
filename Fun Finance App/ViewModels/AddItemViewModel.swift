import Combine
import Foundation
import UIKit

@MainActor
final class AddItemViewModel: ObservableObject {
    @Published var title: String = ""
    @Published var priceText: String = ""
    @Published var notes: String = ""
    @Published var tagsText: String = ""
    @Published var urlText: String = ""
    @Published var image: UIImage?
    @Published var errorMessage: String?
    @Published var isSaving: Bool = false

    private let itemRepository: ItemRepositoryProtocol
    private let decimalFormatter: NumberFormatter
    private let currencyFormatter: NumberFormatter

    init(itemRepository: ItemRepositoryProtocol, locale: Locale = .current) {
        self.itemRepository = itemRepository
        let decimalFormatter = NumberFormatter()
        decimalFormatter.locale = locale
        decimalFormatter.numberStyle = .decimal
        decimalFormatter.maximumFractionDigits = 2
        decimalFormatter.generatesDecimalNumbers = true
        self.decimalFormatter = decimalFormatter

        let currencyFormatter = NumberFormatter()
        currencyFormatter.locale = locale
        currencyFormatter.numberStyle = .currency
        currencyFormatter.maximumFractionDigits = 2
        currencyFormatter.generatesDecimalNumbers = true
        self.currencyFormatter = currencyFormatter
    }

    func save() async -> Bool {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        errorMessage = nil

        // Simple validation
        guard !trimmedTitle.isEmpty else {
            errorMessage = "Please enter a title"
            return false
        }

        guard let price = parsePrice(), price > 0 else {
            errorMessage = "Please enter a valid price"
            return false
        }

        isSaving = true
        defer { isSaving = false }

        do {
            let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedURL = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
            let tags = tagsText
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            try itemRepository.addItem(
                title: trimmedTitle,
                price: price,
                notes: trimmedNotes.isEmpty ? nil : trimmedNotes,
                tags: tags,
                productURL: trimmedURL.isEmpty ? nil : trimmedURL,
                image: image
            )

            clear()
            return true
        } catch {
            errorMessage = "Failed to save item"
            return false
        }
    }

    func clear() {
        title = ""
        priceText = ""
        notes = ""
        tagsText = ""
        urlText = ""
        image = nil
        errorMessage = nil
    }
}

private extension AddItemViewModel {
    func parsePrice() -> Decimal? {
        let trimmed = priceText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let number = decimalFormatter.number(from: trimmed) ?? currencyFormatter.number(from: trimmed) {
            return number.decimalValue
        }

        if let localized = Decimal(string: trimmed, locale: decimalFormatter.locale) {
            return localized
        }

        // As a fallback, strip out currency symbols while preserving likely separators.
        let numericCharacters = CharacterSet(charactersIn: "0123456789.,")
        let filteredScalars = trimmed.unicodeScalars.filter { numericCharacters.contains($0) }
        let fallbackString = String(String.UnicodeScalarView(filteredScalars))

        if let localized = Decimal(string: fallbackString, locale: decimalFormatter.locale) {
            return localized
        }

        return Decimal(string: fallbackString, locale: Locale(identifier: "en_US_POSIX"))
    }
}
