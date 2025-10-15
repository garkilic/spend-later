import XCTest
import CoreData
@testable import Fun_Finance_App

final class SettingsRepositoryTests: XCTestCase {
    var sut: SettingsRepository!
    var context: NSManagedObjectContext!

    override func setUp() {
        super.setUp()
        let controller = PersistenceController(inMemory: true)
        context = controller.container.viewContext
        sut = SettingsRepository(context: context)
    }

    override func tearDown() {
        sut = nil
        context = nil
        super.tearDown()
    }

    // MARK: - Initial Settings

    func testLoadAppSettings_FirstTime_CreatesDefaultSettings() throws {
        // When
        let settings = try sut.loadAppSettings()

        // Then - Should create settings with defaults
        XCTAssertNotNil(settings.id)
        XCTAssertEqual(settings.currencyCode, "USD")
        XCTAssertTrue(settings.weeklyReminderEnabled)
        XCTAssertTrue(settings.monthlyReminderEnabled)
        XCTAssertFalse(settings.passcodeEnabled)
        XCTAssertNil(settings.passcodeKeychainKey)
        XCTAssertEqual(settings.taxRate, .zero)
    }

    func testLoadAppSettings_CalledTwice_ReturnsSameInstance() throws {
        // When
        let settings1 = try sut.loadAppSettings()
        let settings2 = try sut.loadAppSettings()

        // Then
        XCTAssertEqual(settings1.id, settings2.id)
    }

    // MARK: - Currency Code

    func testUpdateCurrencyCode_UpdatesSuccessfully() throws {
        // Given
        _ = try sut.loadAppSettings()

        // When
        try sut.updateCurrencyCode("EUR")

        // Then
        let settings = try sut.loadAppSettings()
        XCTAssertEqual(settings.currencyCode, "EUR")
    }

    func testUpdateCurrencyCode_ToCAD_Persists() throws {
        // Given
        _ = try sut.loadAppSettings()

        // When
        try sut.updateCurrencyCode("CAD")

        // Then
        let settings = try sut.loadAppSettings()
        XCTAssertEqual(settings.currencyCode, "CAD")
    }

    // MARK: - Tax Rate

    func testUpdateTaxRate_UpdatesSuccessfully() throws {
        // Given
        _ = try sut.loadAppSettings()

        // When
        try sut.updateTaxRate(Decimal(0.10)) // 10%

        // Then
        let settings = try sut.loadAppSettings()
        XCTAssertEqual(settings.taxRate.decimalValue, Decimal(0.10))
    }

    func testUpdateTaxRate_VariousRates_AllPersist() throws {
        // Given
        _ = try sut.loadAppSettings()

        // When/Then - Test multiple rates
        let testRates = [
            Decimal(0),      // 0%
            Decimal(0.05),   // 5%
            Decimal(0.13),   // 13% (Canadian HST)
            Decimal(0.20),   // 20% (European VAT)
            Decimal(0.0875)  // 8.75% (NYC sales tax)
        ]

        for rate in testRates {
            try sut.updateTaxRate(rate)
            let settings = try sut.loadAppSettings()
            XCTAssertEqual(settings.taxRate.decimalValue, rate, "Tax rate \(rate) should persist")
        }
    }

    func testUpdateTaxRate_ZeroRate_Valid() throws {
        // Given
        _ = try sut.loadAppSettings()
        try sut.updateTaxRate(Decimal(0.10))

        // When - Change back to zero
        try sut.updateTaxRate(Decimal(0))

        // Then
        let settings = try sut.loadAppSettings()
        XCTAssertEqual(settings.taxRate.decimalValue, Decimal(0))
    }

    // MARK: - Passcode

    func testUpdatePasscode_Enable_SavesState() throws {
        // Given
        _ = try sut.loadAppSettings()

        // When
        try sut.updatePasscodeEnabled(true, key: "test-keychain-key")

        // Then
        let settings = try sut.loadAppSettings()
        XCTAssertTrue(settings.passcodeEnabled)
        XCTAssertEqual(settings.passcodeKeychainKey, "test-keychain-key")
    }

    func testUpdatePasscode_Disable_ClearsKey() throws {
        // Given
        _ = try sut.loadAppSettings()
        try sut.updatePasscodeEnabled(true, key: "test-key")

        // When
        try sut.updatePasscodeEnabled(false, key: nil)

        // Then
        let settings = try sut.loadAppSettings()
        XCTAssertFalse(settings.passcodeEnabled)
        XCTAssertNil(settings.passcodeKeychainKey)
    }

    func testUpdatePasscode_ChangeKey_Updates() throws {
        // Given
        _ = try sut.loadAppSettings()
        try sut.updatePasscodeEnabled(true, key: "old-key")

        // When
        try sut.updatePasscodeEnabled(true, key: "new-key")

        // Then
        let settings = try sut.loadAppSettings()
        XCTAssertTrue(settings.passcodeEnabled)
        XCTAssertEqual(settings.passcodeKeychainKey, "new-key")
    }

    // MARK: - Reminders

    func testUpdateReminderPrefs_BothEnabled_Persists() throws {
        // Given
        _ = try sut.loadAppSettings()

        // When
        try sut.updateReminderPrefs(weekly: true, monthly: true)

        // Then
        let settings = try sut.loadAppSettings()
        XCTAssertTrue(settings.weeklyReminderEnabled)
        XCTAssertTrue(settings.monthlyReminderEnabled)
    }

    func testUpdateReminderPrefs_BothDisabled_Persists() throws {
        // Given
        _ = try sut.loadAppSettings()

        // When
        try sut.updateReminderPrefs(weekly: false, monthly: false)

        // Then
        let settings = try sut.loadAppSettings()
        XCTAssertFalse(settings.weeklyReminderEnabled)
        XCTAssertFalse(settings.monthlyReminderEnabled)
    }

    func testUpdateReminderPrefs_MixedState_Persists() throws {
        // Given
        _ = try sut.loadAppSettings()

        // When
        try sut.updateReminderPrefs(weekly: true, monthly: false)

        // Then
        let settings = try sut.loadAppSettings()
        XCTAssertTrue(settings.weeklyReminderEnabled)
        XCTAssertFalse(settings.monthlyReminderEnabled)
    }

    // MARK: - Data Validation

    func testLoadAppSettings_FixesInvalidTaxRate() throws {
        // Given - Manually create settings with NaN tax rate
        let settings = AppSettingsEntity(context: context)
        settings.id = UUID()
        settings.currencyCode = "USD"
        settings.taxRate = .notANumber
        try context.save()

        // When
        let loadedSettings = try sut.loadAppSettings()

        // Then - Should fix NaN to zero
        XCTAssertEqual(loadedSettings.taxRate, .zero)
    }

    // MARK: - Persistence

    func testSettings_SurviveContextRefresh() throws {
        // Given
        _ = try sut.loadAppSettings()
        try sut.updateCurrencyCode("GBP")
        try sut.updateTaxRate(Decimal(0.20))

        // When - Refresh context (simulates app restart)
        context.refreshAllObjects()

        // Then - Settings should persist
        let settings = try sut.loadAppSettings()
        XCTAssertEqual(settings.currencyCode, "GBP")
        XCTAssertEqual(settings.taxRate.decimalValue, Decimal(0.20))
    }
}
