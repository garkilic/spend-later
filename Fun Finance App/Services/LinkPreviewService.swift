import Foundation
import LinkPresentation
import UIKit

struct LinkPreviewMetadata {
    let title: String?
    let image: UIImage?
    let icon: UIImage?
    let normalizedURL: URL
}

protocol LinkPreviewServicing {
    func fetchMetadata(for urlString: String) async throws -> LinkPreviewMetadata
}

final class LinkPreviewService: LinkPreviewServicing {
    enum LinkPreviewError: Error {
        case invalidURL
    }

    private let urlSession: URLSession

    init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
    }

    func fetchMetadata(for urlString: String) async throws -> LinkPreviewMetadata {
        let normalizedURL = try normalize(urlString: urlString)
        do {
            var providerResult = try await fetchUsingMetadataProvider(for: normalizedURL)
            if providerResult.image == nil || providerResult.icon == nil || providerResult.title == nil {
                if let enriched = try? await fetchFromHTML(for: providerResult.normalizedURL) {
                    providerResult = LinkPreviewMetadata(title: providerResult.title ?? enriched.title,
                                                         image: providerResult.image ?? enriched.image,
                                                         icon: providerResult.icon ?? enriched.icon,
                                                         normalizedURL: enriched.normalizedURL)
                }
            }
            return providerResult
        } catch {
            return try await fetchFromHTML(for: normalizedURL)
        }
    }
}

private extension LinkPreviewService {
    func normalize(urlString: String) throws -> URL {
        var trimmed = urlString.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw LinkPreviewError.invalidURL }
        if !trimmed.contains("://") {
            trimmed = "https://" + trimmed
        }
        guard var components = URLComponents(string: trimmed) else {
            throw LinkPreviewError.invalidURL
        }
        if components.scheme == nil {
            components.scheme = "https"
        }
        if let host = components.host {
            components.host = host.lowercased()
        }
        components.fragment = nil
        guard let url = components.url else {
            throw LinkPreviewError.invalidURL
        }
        return url
    }

    func fetchUsingMetadataProvider(for url: URL) async throws -> LinkPreviewMetadata {
        let provider = LPMetadataProvider()
        let metadata: LPLinkMetadata = try await withCheckedThrowingContinuation { continuation in
            provider.startFetchingMetadata(for: url) { metadata, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let metadata else {
                    continuation.resume(throwing: LinkPreviewError.invalidURL)
                    return
                }
                continuation.resume(returning: metadata)
            }
        }

        let resolvedURL = metadata.url ?? metadata.originalURL ?? url
        let title = metadata.title?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        let image = await loadImage(from: metadata.imageProvider)
        let icon = await loadImage(from: metadata.iconProvider)

        return LinkPreviewMetadata(title: title, image: image, icon: icon, normalizedURL: resolvedURL)
    }

    func loadImage(from provider: NSItemProvider?) async -> UIImage? {
        guard let provider, provider.canLoadObject(ofClass: UIImage.self) else { return nil }
        return await withCheckedContinuation { (continuation: CheckedContinuation<UIImage?, Never>) in
            provider.loadObject(ofClass: UIImage.self) { object, _ in
                continuation.resume(returning: object as? UIImage)
            }
        }
    }

    func fetchFromHTML(for url: URL) async throws -> LinkPreviewMetadata {
        let (data, _) = try await urlSession.data(from: url)
        guard let html = String(data: data, encoding: .utf8) else {
            return LinkPreviewMetadata(title: nil, image: nil, icon: nil, normalizedURL: url)
        }

        let title = parseTitle(in: html)
        let imageURL = parseMetaContent(in: html, keys: ["og:image", "twitter:image", "og:image:url"])?.resolved(relativeTo: url)
        let iconURL = parseIconURL(in: html, baseURL: url)

        async let image = loadRemoteImage(from: imageURL)
        async let icon = loadRemoteImage(from: iconURL)

        return LinkPreviewMetadata(title: title, image: await image, icon: await icon, normalizedURL: url)
    }

    func parseTitle(in html: String) -> String? {
        if let metaTitle = parseMetaContent(in: html, keys: ["og:title", "twitter:title"]) {
            return metaTitle.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        }

        guard let range = html.range(of: "<title>", options: [.caseInsensitive]) else {
            return nil
        }
        let lower = html[range.upperBound...]
        guard let closeRange = lower.range(of: "</title>", options: [.caseInsensitive]) else {
            return nil
        }
        return String(lower[..<closeRange.lowerBound]).trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
    }

    func parseMetaContent(in html: String, keys: [String]) -> String? {
        guard let tagRegex = try? NSRegularExpression(pattern: "<meta[^>]+>", options: [.caseInsensitive]) else {
            return nil
        }
        let nsRange = NSRange(html.startIndex..., in: html)
        let matches = tagRegex.matches(in: html, range: nsRange)
        for match in matches {
            guard let range = Range(match.range, in: html) else { continue }
            let tag = String(html[range])
            for key in keys {
                if attribute(in: tag, named: "property", matches: key) || attribute(in: tag, named: "name", matches: key) {
                    if let content = attributeValue(in: tag, named: "content") {
                        return content
                    }
                }
            }
        }
        return nil
    }

    func parseIconURL(in html: String, baseURL: URL) -> URL? {
        guard let linkRegex = try? NSRegularExpression(pattern: "<link[^>]+>", options: [.caseInsensitive]) else {
            return baseURL.faviconURL()
        }
        let nsRange = NSRange(html.startIndex..., in: html)
        let matches = linkRegex.matches(in: html, range: nsRange)
        for match in matches {
            guard let range = Range(match.range, in: html) else { continue }
            let tag = String(html[range])
            guard let rel = attributeValue(in: tag, named: "rel")?.lowercased() else { continue }
            let targets = ["apple-touch-icon", "apple-touch-icon-precomposed", "shortcut icon", "icon"]
            guard targets.contains(where: { rel.contains($0) }) else { continue }
            if let href = attributeValue(in: tag, named: "href"), let url = href.resolved(relativeTo: baseURL) {
                return url
            }
        }
        return baseURL.faviconURL()
    }

    func attribute(in tag: String, named name: String, matches value: String) -> Bool {
        guard let attributeValue = attributeValue(in: tag, named: name)?.lowercased() else { return false }
        return attributeValue == value.lowercased()
    }

    func attributeValue(in tag: String, named name: String) -> String? {
        let pattern = "\(name)\\s*=\\s*\"([^\"]*)\""
        if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
           let match = regex.firstMatch(in: tag, range: NSRange(tag.startIndex..., in: tag)),
           let range = Range(match.range(at: 1), in: tag) {
            return String(tag[range])
        }
        let singlePattern = "\(name)\\s*=\\s*'([^']*)'"
        if let regex = try? NSRegularExpression(pattern: singlePattern, options: [.caseInsensitive]),
           let match = regex.firstMatch(in: tag, range: NSRange(tag.startIndex..., in: tag)),
           let range = Range(match.range(at: 1), in: tag) {
            return String(tag[range])
        }
        return nil
    }

    func loadRemoteImage(from url: URL?) async -> UIImage? {
        guard let url else { return nil }
        do {
            let (data, _) = try await urlSession.data(from: url)
            return UIImage(data: data)
        } catch {
            return nil
        }
    }
}

private extension String {
    func resolved(relativeTo baseURL: URL) -> URL? {
        if let absolute = URL(string: self), absolute.scheme != nil {
            return absolute
        }
        return URL(string: self, relativeTo: baseURL)?.absoluteURL
    }
}

private extension URL {
    func faviconURL() -> URL? {
        guard let host else { return nil }
        var components = URLComponents()
        components.scheme = scheme ?? "https"
        components.host = host
        components.path = "/favicon.ico"
        return components.url
    }
}
