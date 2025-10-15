import XCTest
import CoreData
@testable import Fun_Finance_App

final class MonthRepositoryTests: XCTestCase {
    var sut: MonthRepository!
    var itemRepository: ItemRepository!
    var context: NSManagedObjectContext!
    var imageStore: MockImageStore!
    var calendar: Calendar!

    override func setUp() {
        super.setUp()
        let controller = PersistenceController(inMemory: true)
        context = controller.container.viewContext
        imageStore = MockImageStore()
        itemRepository = ItemRepository(context: context, imageStore: imageStore)
        calendar = Calendar.current
        sut = MonthRepository(context: context, itemRepository: itemRepository, calendar: calendar)
    }

    override func tearDown() {
        sut = nil
        itemRepository = nil
        context = nil
        imageStore = nil
        calendar = nil
        super.tearDown()
    }

    // MARK: - Summary Creation

    func testCreateSummary_WithItems_CreatesSuccessfully() throws {
        // Given
        try itemRepository.addItem(title: "Item 1", price: 100, notes: nil, tags: [], productURL: nil, image: nil)
        try itemRepository.addItem(title: "Item 2", price: 50, notes: nil, tags: [], productURL: nil, image: nil)
        let monthKey = itemRepository.currentMonthKey

        // When
        let summary = try sut.createSummary(for: monthKey)

        // Then
        XCTAssertNotNil(summary.id)
        XCTAssertEqual(summary.monthKey, monthKey)
        XCTAssertEqual(summary.itemCount, 2)
        XCTAssertEqual(summary.totalSaved.decimalValue, 150)
        XCTAssertNil(summary.winnerItemId)
        XCTAssertNil(summary.closedAt)
    }

    func testCreateSummary_EmptyMonth_ThrowsError() throws {
        // Given
        let emptyMonthKey = "2025,01"

        // When/Then
        XCTAssertThrowsError(try sut.createSummary(for: emptyMonthKey)) { error in
            let nsError = error as NSError
            XCTAssertTrue(nsError.localizedDescription.contains("No items"))
        }
    }

    func testCreateSummary_CalculatesTotalCorrectly() throws {
        // Given
        try itemRepository.addItem(title: "A", price: Decimal(string: "19.99")!, notes: nil, tags: [], productURL: nil, image: nil)
        try itemRepository.addItem(title: "B", price: Decimal(string: "49.99")!, notes: nil, tags: [], productURL: nil, image: nil)
        try itemRepository.addItem(title: "C", price: Decimal(string: "5.50")!, notes: nil, tags: [], productURL: nil, image: nil)
        let monthKey = itemRepository.currentMonthKey

        // When
        let summary = try sut.createSummary(for: monthKey)

        // Then
        XCTAssertEqual(summary.totalSaved.decimalValue, Decimal(string: "75.48")!)
    }

    func testCreateSummary_LinksItemsToSummary() throws {
        // Given
        try itemRepository.addItem(title: "Item", price: 50, notes: nil, tags: [], productURL: nil, image: nil)
        let monthKey = itemRepository.currentMonthKey

        // When
        let summary = try sut.createSummary(for: monthKey)

        // Then
        let items = try itemRepository.items(for: monthKey)
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.summary?.id, summary.id)
    }

    // MARK: - Rollover Logic

    func testRollIfNeeded_PreviousMonthHasItems_CreatesSummary() throws {
        // Given - Create items for last month
        let lastMonth = calendar.date(byAdding: .month, value: -1, to: Date())!
        let lastMonthKey = itemRepository.monthKey(for: lastMonth)

        let item = WantedItemEntity(context: context)
        item.id = UUID()
        item.title = "Last Month Item"
        item.price = NSDecimalNumber(value: 100)
        item.createdAt = lastMonth
        item.monthKey = lastMonthKey
        item.status = .saved
        item.imagePath = ""
        item.tags = []
        try context.save()

        // When
        let summary = try sut.rollIfNeeded(currentDate: Date())

        // Then
        XCTAssertNotNil(summary)
        XCTAssertEqual(summary?.monthKey, lastMonthKey)
        XCTAssertEqual(summary?.itemCount, 1)
    }

    func testRollIfNeeded_SummaryAlreadyExists_DoesNotDuplicate() throws {
        // Given - Create summary for last month
        let lastMonth = calendar.date(byAdding: .month, value: -1, to: Date())!
        let lastMonthKey = itemRepository.monthKey(for: lastMonth)

        let item = WantedItemEntity(context: context)
        item.id = UUID()
        item.title = "Item"
        item.price = NSDecimalNumber(value: 100)
        item.createdAt = lastMonth
        item.monthKey = lastMonthKey
        item.status = .saved
        item.imagePath = ""
        item.tags = []
        try context.save()

        // Create summary first
        _ = try sut.createSummary(for: lastMonthKey)

        // When - Try to roll again
        let summary = try sut.rollIfNeeded(currentDate: Date())

        // Then - Should not create duplicate
        XCTAssertNil(summary)

        // Verify only one summary exists
        let summaries = try sut.summaries()
        XCTAssertEqual(summaries.count, 1)
    }

    func testRollIfNeeded_NoItemsLastMonth_DoesNotCreateSummary() throws {
        // Given - No items for last month

        // When
        let summary = try sut.rollIfNeeded(currentDate: Date())

        // Then
        XCTAssertNil(summary)
    }

    func testRollIfNeeded_OnlyBoughtItems_DoesNotCreateSummary() throws {
        // Given - Only bought items (not active)
        let lastMonth = calendar.date(byAdding: .month, value: -1, to: Date())!
        let lastMonthKey = itemRepository.monthKey(for: lastMonth)

        let item = WantedItemEntity(context: context)
        item.id = UUID()
        item.title = "Bought Item"
        item.price = NSDecimalNumber(value: 100)
        item.createdAt = lastMonth
        item.monthKey = lastMonthKey
        item.status = .bought // Not active
        item.imagePath = ""
        item.tags = []
        try context.save()

        // When
        let summary = try sut.rollIfNeeded(currentDate: Date())

        // Then - Should not create summary for bought items
        XCTAssertNil(summary)
    }

    // MARK: - Fetching Summaries

    func testSummary_ForMonthKey_ReturnsCorrectSummary() throws {
        // Given
        try itemRepository.addItem(title: "Item", price: 100, notes: nil, tags: [], productURL: nil, image: nil)
        let monthKey = itemRepository.currentMonthKey
        let created = try sut.createSummary(for: monthKey)

        // When
        let fetched = try sut.summary(for: monthKey)

        // Then
        XCTAssertEqual(fetched?.id, created.id)
    }

    func testSummary_NonexistentMonth_ReturnsNil() throws {
        // Given
        let nonexistentKey = "1999,12"

        // When
        let summary = try sut.summary(for: nonexistentKey)

        // Then
        XCTAssertNil(summary)
    }

    func testSummary_ById_ReturnsCorrectSummary() throws {
        // Given
        try itemRepository.addItem(title: "Item", price: 100, notes: nil, tags: [], productURL: nil, image: nil)
        let monthKey = itemRepository.currentMonthKey
        let created = try sut.createSummary(for: monthKey)

        // When
        let fetched = try sut.summary(with: created.id)

        // Then
        XCTAssertNotNil(fetched)
        XCTAssertEqual(fetched?.id, created.id)
        XCTAssertEqual(fetched?.monthKey, monthKey)
    }

    func testSummaries_ReturnsAllSummaries_SortedByDate() throws {
        // Given - Create summaries for multiple months
        let now = Date()
        let twoMonthsAgo = calendar.date(byAdding: .month, value: -2, to: now)!
        let oneMonthAgo = calendar.date(byAdding: .month, value: -1, to: now)!

        // Create items for different months
        for (date, title) in [(twoMonthsAgo, "Old"), (oneMonthAgo, "Recent"), (now, "Current")] {
            let item = WantedItemEntity(context: context)
            item.id = UUID()
            item.title = title
            item.price = NSDecimalNumber(value: 100)
            item.createdAt = date
            item.monthKey = itemRepository.monthKey(for: date)
            item.status = .saved
            item.imagePath = ""
            item.tags = []

            _ = try sut.createSummary(for: item.monthKey)
        }

        // When
        let summaries = try sut.summaries()

        // Then - Should be sorted newest first
        XCTAssertEqual(summaries.count, 3)
        XCTAssertEqual(summaries[0].monthKey, itemRepository.monthKey(for: now))
        XCTAssertEqual(summaries[1].monthKey, itemRepository.monthKey(for: oneMonthAgo))
        XCTAssertEqual(summaries[2].monthKey, itemRepository.monthKey(for: twoMonthsAgo))
    }

    // MARK: - Edge Cases

    func testCreateSummary_SingleItem_Works() throws {
        // Given
        try itemRepository.addItem(title: "Solo", price: 42, notes: nil, tags: [], productURL: nil, image: nil)
        let monthKey = itemRepository.currentMonthKey

        // When
        let summary = try sut.createSummary(for: monthKey)

        // Then
        XCTAssertEqual(summary.itemCount, 1)
        XCTAssertEqual(summary.totalSaved.decimalValue, 42)
    }

    func testCreateSummary_LargeNumberOfItems_Handles() throws {
        // Given - Create 100 items
        for i in 1...100 {
            try itemRepository.addItem(title: "Item \(i)", price: 10, notes: nil, tags: [], productURL: nil, image: nil)
        }
        let monthKey = itemRepository.currentMonthKey

        // When
        let summary = try sut.createSummary(for: monthKey)

        // Then
        XCTAssertEqual(summary.itemCount, 100)
        XCTAssertEqual(summary.totalSaved.decimalValue, 1000)
    }
}
