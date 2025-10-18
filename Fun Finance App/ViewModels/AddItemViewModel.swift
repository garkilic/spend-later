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
    @Published var isProcessingImage: Bool = false
    @Published var isBlockedByCap: Bool = false

    private let itemRepository: ItemRepositoryProtocol
    private let linkPreviewService: LinkPreviewServicing
    let savingsTracker: SavingsTracker
    private let decimalFormatter: NumberFormatter
    private let currencyFormatter: NumberFormatter
    private var resolvedProductURL: URL?
    private var processedImageTask: Task<Void, Never>?
    private var cachedImageData: Data?

    init(itemRepository: ItemRepositoryProtocol,
         savingsTracker: SavingsTracker,
         linkPreviewService: LinkPreviewServicing? = nil,
         locale: Locale = .current) {
        self.itemRepository = itemRepository
        self.savingsTracker = savingsTracker
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

        // Check if blocked by savings cap
        if !savingsTracker.canAddItems() {
            isBlockedByCap = true
            return false
        }

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

            // Wait for any ongoing image processing to complete
            await processedImageTask?.value

            // Always use imageData for CloudKit sync
            let imageToSave = image ?? previewImage
            try await itemRepository.addItem(
                title: trimmedTitle,
                price: price,
                notes: trimmedNotes.isEmpty ? nil : trimmedNotes,
                tags: tags,
                productURL: productURL,
                image: imageToSave
            )

            // Recalculate savings after adding item
            savingsTracker.calculateTotalSavings()

            clear()
            return true
        } catch {
            errorMessage = "Failed to save item"
            return false
        }
    }

    /// Set the image for the new item
    func processImage(_ image: UIImage) {
        // Cancel any existing processing
        processedImageTask?.cancel()
        cachedImageData = nil

        self.image = image
        // No need to preprocess - imageData compression happens during save
        self.isProcessingImage = false
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

            // Only auto-fill title if user hasn't entered one yet
            // This preserves user's manual input before pasting URL
            if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               let fetchedTitle = metadata.title,
               !fetchedTitle.isEmpty {
                title = fetchedTitle
            }

            // Only auto-fill price if user hasn't entered one yet
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
        processedImageTask?.cancel()
        processedImageTask = nil
        cachedImageData = nil
        isProcessingImage = false
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
