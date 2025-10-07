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
        self.passcodeManager = PasscodeManager()
        self.hapticManager = HapticManager.shared
        self.rolloverService = RolloverService(monthRepository: monthRepository, itemRepository: itemRepository)

        // Load passcode key synchronously (fast, no I/O)
        if let settings = try? settingsRepository.loadAppSettings() {
            passcodeManager.setActiveKey(settings.passcodeKeychainKey)
        }
    }
}
