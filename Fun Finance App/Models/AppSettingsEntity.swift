import CoreData

@objc(AppSettingsEntity)
final class AppSettingsEntity: NSManagedObject {
    @NSManaged var id: UUID
    @NSManaged var currencyCode: String
    @NSManaged var weeklyReminderEnabled: Bool
    @NSManaged var monthlyReminderEnabled: Bool
    @NSManaged var passcodeEnabled: Bool
    @NSManaged var passcodeKeychainKey: String?
    @NSManaged var taxRate: NSDecimalNumber
    @NSManaged var onboardingCompleted: Bool // Syncs via CloudKit
}
