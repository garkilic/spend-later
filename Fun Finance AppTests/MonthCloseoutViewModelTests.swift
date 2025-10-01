import XCTest
import CoreData
@testable import Fun_Finance_App

final class MonthCloseoutViewModelTests: XCTestCase {
    var sut: MonthCloseoutViewModel!
    var mockSummary: MonthSummaryEntity!
    var mockHaptics: MockHapticManager!
    var mockSettingsRepository: MockSettingsRepository!
    var context: NSManagedObjectContext!

    @MainActor
    override func setUp() {
        super.setUp()
        context = PersistenceController.preview.container.viewContext
        mockHaptics = MockHapticManager()
        mockSettingsRepository = MockSettingsRepository()

        mockSummary = MonthSummaryEntity(context: context)
        mockSummary.id = UUID()
        mockSummary.monthKey = "2025,09"
        mockSummary.totalSaved = NSDecimalNumber(value: 300)
        mockSummary.itemCount = 3
        mockSummary.winnerItemId = nil
        mockSummary.closedAt = nil

        let items = createMockItems(count: 3)
        mockSummary.items = NSSet(array: items)

        sut = MonthCloseoutViewModel(
            summary: mockSummary,
            haptics: mockHaptics,
            settingsRepository: mockSettingsRepository
        )
    }

    override func tearDown() {
        sut = nil
        mockSummary = nil
        mockHaptics = nil
        mockSettingsRepository = nil
        context = nil
        super.tearDown()
    }

    @MainActor
    func testCanDraw_WhenNoWinner_ReturnsTrue() {
        // Given
        mockSummary.winnerItemId = nil

        // Then
        XCTAssertTrue(sut.canDraw)
    }

    @MainActor
    func testCanDraw_WhenWinnerExists_ReturnsFalse() {
        // Given
        mockSummary.winnerItemId = UUID()

        // When
        sut.reload()

        // Then
        XCTAssertFalse(sut.canDraw)
    }

    @MainActor
    func testDrawWinner_SelectsRandomItem() {
        // When
        sut.drawWinner()

        // Then
        XCTAssertNotNil(mockSummary.winnerItemId)
        XCTAssertNotNil(mockSummary.closedAt)
        XCTAssertNotNil(sut.winner)
        XCTAssertTrue(mockHaptics.successCalled)
    }

    @MainActor
    func testDrawWinner_SetsWinnerToRedeemed() {
        // When
        sut.drawWinner()

        // Then
        let winner = mockSummary.wantedItems.first { $0.id == mockSummary.winnerItemId }
        XCTAssertEqual(winner?.status, .redeemed)
    }

    @MainActor
    func testDrawWinner_SetsOthersToSkipped() {
        // When
        sut.drawWinner()

        // Then
        let nonWinners = mockSummary.wantedItems.filter { $0.id != mockSummary.winnerItemId }
        XCTAssertTrue(nonWinners.allSatisfy { $0.status == .skipped })
    }

    @MainActor
    func testReload_PopulatesItemsCorrectly() {
        // When
        sut.reload()

        // Then
        XCTAssertEqual(sut.items.count, 3)
    }

    private func createMockItems(count: Int) -> [WantedItemEntity] {
        (0..<count).map { index in
            let item = WantedItemEntity(context: context)
            item.id = UUID()
            item.title = "Test Item \(index)"
            item.price = NSDecimalNumber(value: 100 + index * 50)
            item.notes = nil
            item.productText = nil
            item.productURL = nil
            item.imagePath = ""
            item.tags = ["test"]
            item.createdAt = Date()
            item.monthKey = "2025,09"
            item.status = .active
            return item
        }
    }
}
