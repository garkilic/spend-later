import XCTest
import UIKit
import CoreData
@testable import Fun_Finance_App

final class ItemRepositoryTests: XCTestCase {
    func testAddItemPersistsProductURLAndImageFilename() async throws {
        let controller = PersistenceController(inMemory: true)
        let imageStore = MockImageStore()
        let repository = ItemRepository(context: controller.container.viewContext, imageStore: imageStore)

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 10, height: 10))
        let image = renderer.image { context in
            UIColor.systemBlue.setFill()
            context.fill(CGRect(origin: .zero, size: CGSize(width: 10, height: 10)))
        }

        let productURL = "https://example.com/item"
        try await repository.addItem(title: "Test Item",
                                     price: 9.99,
                                     notes: nil,
                                     tags: [],
                                     productURL: productURL,
                                     image: image)

        let items = try repository.allItems()
        XCTAssertEqual(items.count, 1)
        let savedItem = try XCTUnwrap(items.first)
        XCTAssertEqual(savedItem.productURL, productURL)
        XCTAssertFalse(savedItem.imagePath.isEmpty)
        XCTAssertNotNil(imageStore.savedImages[savedItem.imagePath])
    }
}
