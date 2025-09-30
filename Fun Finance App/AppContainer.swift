import Combine
import CoreData
import SwiftUI

@MainActor
final class AppContainer: ObservableObject {
    let objectWillChange = ObservableObjectPublisher()

    let persistenceController: PersistenceController
    let imageStore: ImageStore
    let itemRepository: ItemRepository
    let monthRepository: MonthRepository
    let settingsRepository: SettingsRepository
    let notificationScheduler: NotificationScheduler
    let passcodeManager: PasscodeManager
    let rolloverService: RolloverService
    let hapticManager: HapticManager

    var viewContext: NSManagedObjectContext { persistenceController.container.viewContext }

    init(persistenceController: PersistenceController? = nil) {
        let controller = persistenceController ?? PersistenceController.shared
        self.persistenceController = controller
        self.imageStore = ImageStore()
        self.itemRepository = ItemRepository(context: controller.container.viewContext, imageStore: imageStore)
        self.settingsRepository = SettingsRepository(context: controller.container.viewContext)
        self.monthRepository = MonthRepository(context: controller.container.viewContext, itemRepository: itemRepository)
        self.notificationScheduler = NotificationScheduler()
        self.passcodeManager = PasscodeManager()
        self.hapticManager = HapticManager.shared
        self.rolloverService = RolloverService(monthRepository: monthRepository, itemRepository: itemRepository)

        Task { await configureSettings() }
    }

    private func configureSettings() async {
        do {
            let settings = try settingsRepository.loadAppSettings()
            passcodeManager.setActiveKey(settings.passcodeKeychainKey)
            notificationScheduler.requestAuthorizationIfNeeded()
            notificationScheduler.updateWeeklyReminder(enabled: settings.weeklyReminderEnabled)
            notificationScheduler.updateMonthlyReminder(enabled: settings.monthlyReminderEnabled)
        } catch {
            assertionFailure("Failed to load settings: \(error)")
        }
    }
}
