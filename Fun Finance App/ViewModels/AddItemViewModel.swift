import Combine
import Foundation
import UIKit

@MainActor
final class AddItemViewModel: ObservableObject {
    @Published var title: String = ""
    @Published var price: Decimal = .zero
    @Published var notes: String = ""
    @Published var tagsText: String = ""
    @Published var urlText: String = ""
    @Published var image: UIImage?
    @Published var previewImage: UIImage?
    @Published var isSaving: Bool = false
    @Published var isFetchingPreview: Bool = false
    @Published var errorMessage: String?

    private let itemRepository: ItemRepositoryProtocol
    private let linkPreviewService: LinkPreviewServicing
    private var resolvedProductURL: URL?
    private var previewTask: Task<Void, Never>?

    init(itemRepository: ItemRepositoryProtocol,
         linkPreviewService: LinkPreviewServicing? = nil) {
        self.itemRepository = itemRepository
        self.linkPreviewService = linkPreviewService ?? LinkPreviewService()
    }

    var isValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && price > 0
    }

    deinit {
        previewTask?.cancel()
    }

    func requestLinkPreview() {
        let trimmed = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
        previewTask?.cancel()

        guard !trimmed.isEmpty else {
            resolvedProductURL = nil
            previewImage = nil
            return
        }

        previewTask = Task { [weak self] in
            guard let self else { return }
            await self.loadPreview(for: trimmed)
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

    func clear() {
        previewTask?.cancel()
        title = ""
        price = .zero
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
            if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               let fetchedTitle = metadata.title,
               !fetchedTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                title = fetchedTitle
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
