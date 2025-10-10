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
    @Published var previewImage: UIImage?
    @Published var errorMessage: String?
    @Published var isSaving: Bool = false
    @Published var isFetchingPreview: Bool = false

    private let itemRepository: ItemRepositoryProtocol
    private let linkPreviewService: LinkPreviewServicing
    private let decimalFormatter: NumberFormatter
    private let currencyFormatter: NumberFormatter
    private var resolvedProductURL: URL?

    init(itemRepository: ItemRepositoryProtocol,
         linkPreviewService: LinkPreviewServicing? = nil,
         locale: Locale = .current) {
        self.itemRepository = itemRepository
        self.linkPreviewService = linkPreviewService ?? LinkPreviewService()
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

            // Use resolved URL if available, otherwise use the trimmed text
            let productURL = resolvedProductURL?.absoluteString ?? (trimmedURL.isEmpty ? nil : trimmedURL)

            // Use manual photo if available, otherwise use preview image
            let imageToSave = image ?? previewImage

            try await itemRepository.addItem(
                title: trimmedTitle,
                price: price,
                notes: trimmedNotes.isEmpty ? nil : trimmedNotes,
                tags: tags,
                productURL: productURL,
                image: imageToSave
            )

            clear()
            return true
        } catch {
            errorMessage = "Failed to save item"
            return false
        }
    }

    func requestLinkPreview() async {
        let trimmed = urlText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            resolvedProductURL = nil
            previewImage = nil
            return
        }

        isFetchingPreview = true
        defer { isFetchingPreview = false }

        do {
            let metadata = try await linkPreviewService.fetchMetadata(for: trimmed)
            resolvedProductURL = metadata.normalizedURL

            // Auto-fill title if empty
            if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               let fetchedTitle = metadata.title,
               !fetchedTitle.isEmpty {
                title = fetchedTitle
            }

            // Auto-fill price if empty
            if priceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               let fetchedPrice = metadata.price,
               fetchedPrice > 0 {
                priceText = String(format: "%.2f", NSDecimalNumber(decimal: fetchedPrice).doubleValue)
            }

            // Set preview image (prefer main image, fallback to icon)
            previewImage = metadata.image ?? metadata.icon
        } catch {
            // Silently fail - user can still save without preview
            resolvedProductURL = nil
            previewImage = nil
        }
    }

    func clear() {
        title = ""
        priceText = ""
        notes = ""
        tagsText = ""
        urlText = ""
        image = nil
        previewImage = nil
        resolvedProductURL = nil
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
