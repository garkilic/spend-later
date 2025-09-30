import CoreData

protocol SettingsRepositoryProtocol {
    func loadAppSettings() throws -> AppSettingsEntity
    func updatePasscodeEnabled(_ enabled: Bool, key: String?) throws
    func updateReminderPrefs(weekly: Bool, monthly: Bool) throws
    func updateCurrencyCode(_ code: String) throws
}

final class SettingsRepository: SettingsRepositoryProtocol {
    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    func loadAppSettings() throws -> AppSettingsEntity {
        let request = NSFetchRequest<AppSettingsEntity>(entityName: "AppSettings")
        if let settings = try context.fetch(request).first {
            return settings
        }
        let settings = AppSettingsEntity(context: context)
        settings.id = UUID()
        settings.currencyCode = "USD"
        settings.weeklyReminderEnabled = true
        settings.monthlyReminderEnabled = true
        settings.passcodeEnabled = false
        settings.passcodeKeychainKey = nil
        try context.save()
        return settings
    }

    func updatePasscodeEnabled(_ enabled: Bool, key: String?) throws {
        let settings = try loadAppSettings()
        settings.passcodeEnabled = enabled
        settings.passcodeKeychainKey = key
        try saveIfNeeded()
    }

    func updateReminderPrefs(weekly: Bool, monthly: Bool) throws {
        let settings = try loadAppSettings()
        settings.weeklyReminderEnabled = weekly
        settings.monthlyReminderEnabled = monthly
        try saveIfNeeded()
    }

    func updateCurrencyCode(_ code: String) throws {
        let settings = try loadAppSettings()
        settings.currencyCode = code
        try saveIfNeeded()
    }
}

private extension SettingsRepository {
    func saveIfNeeded() throws {
        if context.hasChanges {
            try context.save()
        }
    }
}
