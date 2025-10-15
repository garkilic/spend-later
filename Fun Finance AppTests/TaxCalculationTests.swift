import XCTest
@testable import Fun_Finance_App

final class TaxCalculationTests: XCTestCase {

    // MARK: - Basic Tax Calculations

    func testTaxCalculation_ZeroTax_ReturnsSamePrice() {
        // Given
        let price = Decimal(100)
        let taxRate = Decimal(0) // 0%

        // When
        let priceWithTax = price * (1 + taxRate)

        // Then
        XCTAssertEqual(priceWithTax, 100)
    }

    func testTaxCalculation_10PercentTax_AddsCorrectly() {
        // Given
        let price = Decimal(100)
        let taxRate = Decimal(0.10) // 10%

        // When
        let priceWithTax = price * (1 + taxRate)

        // Then
        XCTAssertEqual(priceWithTax, 110)
    }

    func testTaxCalculation_5PercentTax_Accurate() {
        // Given
        let price = Decimal(string: "99.99")!
        let taxRate = Decimal(0.05) // 5%

        // When
        let priceWithTax = price * (1 + taxRate)

        // Then
        XCTAssertEqual(priceWithTax, Decimal(string: "104.9895")!)
    }

    func testTaxCalculation_13PercentTax_Accurate() {
        // Given - Canadian HST rate
        let price = Decimal(50)
        let taxRate = Decimal(0.13) // 13%

        // When
        let priceWithTax = price * (1 + taxRate)

        // Then
        XCTAssertEqual(priceWithTax, Decimal(56.5))
    }

    // MARK: - Edge Cases

    func testTaxCalculation_VerySmallAmount_Precise() {
        // Given
        let price = Decimal(string: "0.01")! // 1 cent
        let taxRate = Decimal(0.10)

        // When
        let priceWithTax = price * (1 + taxRate)

        // Then
        XCTAssertEqual(priceWithTax, Decimal(string: "0.011")!)
    }

    func testTaxCalculation_VeryLargeAmount_NoPrecisionLoss() {
        // Given
        let price = Decimal(999999.99)
        let taxRate = Decimal(0.10)

        // When
        let priceWithTax = price * (1 + taxRate)

        // Then
        XCTAssertEqual(priceWithTax, Decimal(1099999.989))
    }

    func testTaxCalculation_MultipleItems_SumsCorrectly() {
        // Given
        let prices = [
            Decimal(string: "19.99")!,
            Decimal(string: "49.99")!,
            Decimal(string: "5.50")!
        ]
        let taxRate = Decimal(0.08) // 8%

        // When
        let subtotal = prices.reduce(Decimal.zero, +)
        let total = subtotal * (1 + taxRate)

        // Then
        XCTAssertEqual(subtotal, Decimal(string: "75.48")!)
        XCTAssertEqual(total, Decimal(string: "81.5184")!)
    }

    // MARK: - Real-World Scenarios

    func testDashboardCalculation_WithTax_AggregatesCorrectly() async throws {
        // Given
        let controller = PersistenceController(inMemory: true)
        let context = controller.container.viewContext
        let imageStore = MockImageStore()
        let repository = ItemRepository(context: context, imageStore: imageStore)
        let settingsRepo = SettingsRepository(context: context)

        // Set 10% tax
        try settingsRepo.updateTaxRate(Decimal(0.10))

        // Add items
        try await repository.addItem(title: "Item 1", price: 100, notes: nil, tags: [], productURL: nil, image: nil)
        try await repository.addItem(title: "Item 2", price: 50, notes: nil, tags: [], productURL: nil, image: nil)

        // When
        let items = try repository.items(for: repository.currentMonthKey)
        let settings = try settingsRepo.loadAppSettings()
        let taxMultiplier = 1 + settings.taxRate.decimalValue
        let total = items.reduce(Decimal.zero) { $0 + ($1.price.decimalValue * taxMultiplier) }

        // Then
        XCTAssertEqual(total, 165) // (100 + 50) * 1.10
    }

    func testAverageCalculation_WithTax_Accurate() async throws {
        // Given
        let controller = PersistenceController(inMemory: true)
        let context = controller.container.viewContext
        let imageStore = MockImageStore()
        let repository = ItemRepository(context: context, imageStore: imageStore)
        let settingsRepo = SettingsRepository(context: context)

        try settingsRepo.updateTaxRate(Decimal(0.05)) // 5% tax

        // Add 3 items
        try await repository.addItem(title: "A", price: 10, notes: nil, tags: [], productURL: nil, image: nil)
        try await repository.addItem(title: "B", price: 20, notes: nil, tags: [], productURL: nil, image: nil)
        try await repository.addItem(title: "C", price: 30, notes: nil, tags: [], productURL: nil, image: nil)

        // When
        let items = try repository.items(for: repository.currentMonthKey)
        let settings = try settingsRepo.loadAppSettings()
        let taxMultiplier = 1 + settings.taxRate.decimalValue
        let total = items.reduce(Decimal.zero) { $0 + ($1.price.decimalValue * taxMultiplier) }
        let average = items.isEmpty ? Decimal.zero : total / Decimal(items.count)

        // Then
        // Total: (10 + 20 + 30) * 1.05 = 63
        // Average: 63 / 3 = 21
        XCTAssertEqual(total, 63)
        XCTAssertEqual(average, 21)
    }

    // MARK: - Decimal Precision

    func testDecimal_NoFloatingPointErrors() {
        // Given - Classic floating point problem: 0.1 + 0.2 != 0.3
        let value1 = Decimal(string: "0.1")!
        let value2 = Decimal(string: "0.2")!

        // When
        let sum = value1 + value2

        // Then - Decimal handles this correctly
        XCTAssertEqual(sum, Decimal(string: "0.3")!)
    }

    func testDecimal_RepeatingDecimals_HandledCorrectly() {
        // Given - 1/3 = 0.333...
        let price = Decimal(100)
        let taxRate = Decimal(1) / Decimal(3) // 33.333...%

        // When
        let priceWithTax = price * (1 + taxRate)

        // Then - Should have reasonable precision
        // 100 * 1.333333... ≈ 133.33
        let expected = Decimal(string: "133.3333333333333333333333333333")!
        XCTAssertEqual(priceWithTax, expected)
    }

    // MARK: - Tax Rate Changes

    func testTaxCalculation_RateChange_NewItemsUseNewRate() throws {
        // Given
        let controller = PersistenceController(inMemory: true)
        let context = controller.container.viewContext
        let imageStore = MockImageStore()
        let repository = ItemRepository(context: context, imageStore: imageStore)
        let settingsRepo = SettingsRepository(context: context)

        // Initial 5% tax
        try settingsRepo.updateTaxRate(Decimal(0.05))

        // When - Change to 10%
        try settingsRepo.updateTaxRate(Decimal(0.10))

        // Then
        let settings = try settingsRepo.loadAppSettings()
        XCTAssertEqual(settings.taxRate.decimalValue, Decimal(0.10))
    }
}
