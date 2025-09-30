import XCTest
@testable import Fun_Finance_App

final class LinkPreviewServiceTests: XCTestCase {
    func testFetchMetadataFromAppleHomepage() async throws {
        let service = LinkPreviewService()
        do {
            let metadata = try await service.fetchMetadata(for: "https://www.apple.com")
            XCTAssertEqual(metadata.normalizedURL.host, "www.apple.com")
            if let title = metadata.title {
                XCTAssertFalse(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        } catch {
            if let urlError = error as? URLError {
                throw XCTSkip("Skipping network-dependent test: \(urlError.localizedDescription)")
            }
            throw error
        }
    }
}
