import Combine
import Foundation
import UIKit

@MainActor
final class AddItemViewModel: ObservableObject {
    @Published var title: String = ""
    @Published var price: Decimal = .zero
    @Published var priceText: String = ""
    @Published var notes: String = ""
    @Published var tagsText: String = ""
    @Published var urlText: String = ""
    @Published var image: UIImage?
    @Published var previewImage: UIImage?
    @Published var isSaving: Bool = false
    @Published var isFetchingPreview: Bool = false
    @Published var errorMessage: String?
    @Published private(set) var isValid: Bool = false

    private let itemRepository: ItemRepositoryProtocol
    private let linkPreviewService: LinkPreviewServicing
    private var resolvedProductURL: URL?
    private var previewTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()
    private var isInitialLoad = true

    init(itemRepository: ItemRepositoryProtocol,
         linkPreviewService: LinkPreviewServicing? = nil) {
        self.itemRepository = itemRepository
        self.linkPreviewService = linkPreviewService ?? LinkPreviewService()

        // Debounced validation - only validate after user stops typing for 200ms
        Publishers.CombineLatest($title, $price)
            .debounce(for: .milliseconds(200), scheduler: DispatchQueue.main)
            .map { title, price in
                !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && price > 0
            }
            .removeDuplicates() // Only update when validation state actually changes
            .assign(to: \.isValid, on: self)
            .store(in: &cancellables)

        // Auto-trigger URL preview when user stops typing for 500ms
        // Skip initial empty value to prevent lag on first load
        $urlText
            .dropFirst() // Skip initial empty value
            .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
            .removeDuplicates()
            .sink { [weak self] newURL in
                guard let self else { return }
                let trimmed = newURL.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    Task { @MainActor in
                        await self.loadPreviewInternal(for: trimmed)
                    }
                } else {
                    self.previewImage = nil
                    self.resolvedProductURL = nil
                }
            }
            .store(in: &cancellables)
    }

    deinit {
        previewTask?.cancel()
        cancellables.removeAll()
    }

    func requestLinkPreview() {
        // Manual trigger - cancel existing and fetch immediately
        previewTask?.cancel()
        let trimmed = urlText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            resolvedProductURL = nil
            previewImage = nil
            isFetchingPreview = false
            return
        }

        Task { @MainActor in
            await loadPreviewInternal(for: trimmed)
        }
    }

    private func loadPreviewInternal(for urlString: String) async {
        // Cancel any existing preview task
        previewTask?.cancel()

        previewTask = Task { @MainActor in
            await self.loadPreview(for: urlString)
        }
    }

    func save() async -> Bool {
        guard isValid else {
            errorMessage = "Enter a title and dollar amount to save."
            return false
        }
        isSaving = true
        defer { isSaving = false }
        do {
            let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
            let parsedTags = normalizedTags()
            let storedProductURL = resolvedProductURL?.absoluteString ?? normalizedURL(from: urlText)?.absoluteString
            let imageToPersist = image ?? previewImage
            let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)

            try itemRepository.addItem(title: trimmedTitle,
                                       price: price,
                                       notes: trimmedNotes.isEmpty ? nil : trimmedNotes,
                                       tags: parsedTags,
                                       productURL: storedProductURL,
                                       image: imageToPersist)
            clear()
            return true
        } catch {
            errorMessage = "Could not save item."
            return false
        }
    }

    func updatePriceFromText() {
        let cleaned = priceText.replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespaces)

        if let decimal = Decimal(string: cleaned) {
            price = decimal
        } else if cleaned.isEmpty {
            price = .zero
        }
    }

    func clear() {
        previewTask?.cancel()
        title = ""
        price = .zero
        priceText = ""
        notes = ""
        tagsText = ""
        image = nil
        previewImage = nil
        urlText = ""
        resolvedProductURL = nil
        isFetchingPreview = false
        errorMessage = nil
    }
}

private extension AddItemViewModel {
    func loadPreview(for urlString: String) async {
        isFetchingPreview = true
        defer {
            isFetchingPreview = false
            previewTask = nil
        }

        do {
            let metadata = try await linkPreviewService.fetchMetadata(for: urlString)
            guard !Task.isCancelled else { return }
            resolvedProductURL = metadata.normalizedURL

            // Auto-fill title if empty
            if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               let fetchedTitle = metadata.title,
               !fetchedTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                title = fetchedTitle
            }

            // Auto-fill price if found and current price is zero
            if price == .zero, let fetchedPrice = metadata.price, fetchedPrice > 0 {
                price = fetchedPrice
                priceText = String(format: "%.2f", NSDecimalNumber(decimal: fetchedPrice).doubleValue)
            }

            previewImage = metadata.image ?? metadata.icon
        } catch {
            guard !Task.isCancelled else { return }
            resolvedProductURL = normalizedURL(from: urlString)
            previewImage = nil
        }
    }

    func normalizedURL(from text: String) -> URL? {
        var trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if !trimmed.contains("://") {
            trimmed = "https://" + trimmed
        }
        guard var components = URLComponents(string: trimmed) else { return nil }
        if components.scheme == nil {
            components.scheme = "https"
        }
        if let host = components.host {
            components.host = host.lowercased()
        }
        components.fragment = nil
        return components.url
    }

    func normalizedTags() -> [String] {
        tagsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}
