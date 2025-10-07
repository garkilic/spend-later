import XCTest
@testable import Fun_Finance_App

final class AddItemViewModelTests: XCTestCase {
    func testSaveParsesCurrencyStringInCurrentLocale() async throws {
        let repository = MockItemRepository()
        let viewModel = AddItemViewModel(itemRepository: repository)
        viewModel.title = "Coffee"
        viewModel.priceText = "$4.25"

        let didSave = await viewModel.save()

        XCTAssertTrue(didSave)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertEqual(repository.addedItems.first?.price, Decimal(string: "4.25"))
    }

    func testSaveParsesDecimalUsingInjectedLocale() async throws {
        let repository = MockItemRepository()
        let locale = Locale(identifier: "de_DE")
        let viewModel = AddItemViewModel(itemRepository: repository, locale: locale)
        viewModel.title = "Buch"
        viewModel.priceText = "12,49"

        let didSave = await viewModel.save()

        XCTAssertTrue(didSave)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertEqual(repository.addedItems.first?.price, Decimal(string: "12.49"))
    }

    func testSaveRejectsInvalidPrice() async {
        let repository = MockItemRepository()
        let viewModel = AddItemViewModel(itemRepository: repository)
        viewModel.title = "Shoes"
        viewModel.priceText = "abc"

        let didSave = await viewModel.save()

        XCTAssertFalse(didSave)
        XCTAssertEqual(viewModel.errorMessage, "Please enter a valid price")
        XCTAssertTrue(repository.addedItems.isEmpty)
    }
}
