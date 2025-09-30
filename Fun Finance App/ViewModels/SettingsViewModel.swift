import Combine
import Foundation

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var weeklyReminderEnabled: Bool = true
    @Published var passcodeEnabled: Bool = false
    @Published var errorMessage: String?
    @Published var taxRatePercent: Decimal = .zero {
        didSet { persistTaxRateIfNeeded() }
    }

    private let settingsRepository: SettingsRepositoryProtocol
    private let notificationScheduler: NotificationScheduling
    private let passcodeManager: PasscodeManager
    private var hasLoaded = false
    private var lastPersistedTaxRate: Decimal = .zero

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
            passcodeEnabled = settings.passcodeEnabled
            passcodeManager.setActiveKey(settings.passcodeKeychainKey)
            taxRatePercent = settings.taxRate.decimalValue * 100
            lastPersistedTaxRate = taxRatePercent
            notificationScheduler.cancelMonthlyReminder()
            hasLoaded = true
        } catch {
            errorMessage = "Unable to load settings."
        }
    }

    func toggleWeeklyReminder(_ enabled: Bool) {
        weeklyReminderEnabled = enabled
        notificationScheduler.updateWeeklyReminder(enabled: enabled)
        do {
            try settingsRepository.updateReminderPrefs(weekly: weeklyReminderEnabled, monthly: false)
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

    private func persistTaxRateIfNeeded() {
        guard hasLoaded else { return }
        guard taxRatePercent != lastPersistedTaxRate else { return }

        let clampedPercent = max(Decimal.zero, min(taxRatePercent, Decimal(100)))
        if clampedPercent != taxRatePercent {
            taxRatePercent = clampedPercent
            return
        }

        let normalizedRate = NSDecimalNumber(decimal: taxRatePercent).dividing(by: NSDecimalNumber(value: 100)).decimalValue
        do {
            try settingsRepository.updateTaxRate(normalizedRate)
            lastPersistedTaxRate = taxRatePercent
        } catch {
            errorMessage = "Failed to update tax rate."
        }
    }
}
