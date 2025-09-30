import Combine
import Foundation

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var weeklyReminderEnabled: Bool = true
    @Published var monthlyReminderEnabled: Bool = true
    @Published var passcodeEnabled: Bool = false
    @Published var errorMessage: String?

    private let settingsRepository: SettingsRepositoryProtocol
    private let notificationScheduler: NotificationScheduling
    private let passcodeManager: PasscodeManager

    init(settingsRepository: SettingsRepositoryProtocol,
         notificationScheduler: NotificationScheduling,
         passcodeManager: PasscodeManager) {
        self.settingsRepository = settingsRepository
        self.notificationScheduler = notificationScheduler
        self.passcodeManager = passcodeManager
    }

    func load() {
        do {
            let settings = try settingsRepository.loadAppSettings()
            weeklyReminderEnabled = settings.weeklyReminderEnabled
            monthlyReminderEnabled = settings.monthlyReminderEnabled
            passcodeEnabled = settings.passcodeEnabled
            passcodeManager.setActiveKey(settings.passcodeKeychainKey)
        } catch {
            errorMessage = "Unable to load settings."
        }
    }

    func toggleWeeklyReminder(_ enabled: Bool) {
        weeklyReminderEnabled = enabled
        notificationScheduler.updateWeeklyReminder(enabled: enabled)
        do {
            try settingsRepository.updateReminderPrefs(weekly: weeklyReminderEnabled, monthly: monthlyReminderEnabled)
        } catch {
            errorMessage = "Could not save reminder preference."
        }
    }

    func toggleMonthlyReminder(_ enabled: Bool) {
        monthlyReminderEnabled = enabled
        notificationScheduler.updateMonthlyReminder(enabled: enabled)
        do {
            try settingsRepository.updateReminderPrefs(weekly: weeklyReminderEnabled, monthly: monthlyReminderEnabled)
        } catch {
            errorMessage = "Could not save reminder preference."
        }
    }

    func enablePasscode(with passcode: String) {
        do {
            let key = try passcodeManager.setPasscode(passcode)
            try settingsRepository.updatePasscodeEnabled(true, key: key)
            passcodeEnabled = true
        } catch {
            errorMessage = "Failed to set passcode."
        }
    }

    func disablePasscode() {
        passcodeManager.clear()
        do {
            try settingsRepository.updatePasscodeEnabled(false, key: nil)
            passcodeEnabled = false
        } catch {
            errorMessage = "Failed to update passcode."
        }
    }
}
