import XCTest
@testable import Fun_Finance_App

final class DashboardViewModelTests: XCTestCase {
    var sut: DashboardViewModel!
    var mockItemRepository: MockItemRepository!
    var mockMonthRepository: MockMonthRepository!
    var mockSettingsRepository: MockSettingsRepository!
    var mockImageStore: MockImageStore!

    @MainActor
    override func setUp() {
        super.setUp()
        mockItemRepository = MockItemRepository()
        mockMonthRepository = MockMonthRepository()
        mockSettingsRepository = MockSettingsRepository()
        mockImageStore = MockImageStore()

        sut = DashboardViewModel(
            itemRepository: mockItemRepository,
            monthRepository: mockMonthRepository,
            settingsRepository: mockSettingsRepository,
            imageStore: mockImageStore
        )
    }

    override func tearDown() {
        sut = nil
        mockItemRepository = nil
        mockMonthRepository = nil
        mockSettingsRepository = nil
        mockImageStore = nil
        super.tearDown()
    }

    @MainActor
    func testRefresh_WithNoItems_SetsCountToZero() {
        // Given
        mockItemRepository.itemsToReturn = []

        // When
        sut.refresh()

        // Then
        XCTAssertEqual(sut.itemCount, 0)
        XCTAssertEqual(sut.totalSaved, .zero)
        XCTAssertEqual(sut.averageItemPrice, .zero)
    }

    @MainActor
    func testRefresh_WithItems_CalculatesTotalCorrectly() {
        // Given
        let item1 = createMockItem(price: 100)
        let item2 = createMockItem(price: 200)
        mockItemRepository.itemsToReturn = [item1, item2]
        mockSettingsRepository.taxRate = 0.1

        // When
        sut.refresh()

        // Then
        XCTAssertEqual(sut.itemCount, 2)
        XCTAssertEqual(sut.totalSaved, 330) // (100 + 200) * 1.1
        XCTAssertEqual(sut.averageItemPrice, 165) // 330 / 2
    }

    @MainActor
    func testDelete_RemovesItemFromList() {
        // Given
        let item = createMockItem(price: 100)
        mockItemRepository.itemsToReturn = [item]
        sut.refresh()

        let display = sut.items.first!

        // When
        sut.delete(display)

        // Then
        XCTAssertEqual(sut.items.count, 0)
        XCTAssertTrue(mockItemRepository.deletedItems.contains(where: { $0.id == item.id }))
    }

    @MainActor
    func testDelete_CreatesPendingUndoItem() {
        // Given
        let item = createMockItem(price: 100)
        mockItemRepository.itemsToReturn = [item]
        sut.refresh()

        let display = sut.items.first!

        // When
        sut.delete(display)

        // Then
        XCTAssertNotNil(sut.pendingUndoItem)
        XCTAssertEqual(sut.pendingUndoItem?.title, display.title)
    }

    private func createMockItem(price: Decimal) -> WantedItemEntity {
        let item = WantedItemEntity(context: mockItemRepository.context)
        item.id = UUID()
        item.title = "Test Item"
        item.price = NSDecimalNumber(decimal: price)
        item.notes = nil
        item.productText = nil
        item.productURL = nil
        item.imagePath = ""
        item.tags = []
        item.createdAt = Date()
        item.monthKey = "2025,09"
        item.status = .active
        return item
    }
}
