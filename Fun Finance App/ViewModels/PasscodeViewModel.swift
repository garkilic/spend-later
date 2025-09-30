import Combine
import Foundation

@MainActor
final class PasscodeViewModel: ObservableObject {
    @Published var digits: String = ""
    @Published var errorMessage: String?
    @Published var isUnlocked: Bool = false

    private let passcodeManager: PasscodeManager
    private let settingsRepository: SettingsRepositoryProtocol
    private let maxDigits = 4

    init(passcodeManager: PasscodeManager, settingsRepository: SettingsRepositoryProtocol) {
        self.passcodeManager = passcodeManager
        self.settingsRepository = settingsRepository
    }

    func load() {
        do {
            let settings = try settingsRepository.loadAppSettings()
            passcodeManager.setActiveKey(settings.passcodeKeychainKey)
        } catch {
            errorMessage = "Couldn't load passcode."
        }
    }

    func append(_ digit: Int) {
        guard digits.count < maxDigits else { return }
        digits.append(String(digit))
        if digits.count == maxDigits {
            validate()
        }
    }

    func backspace() {
        guard !digits.isEmpty else { return }
        digits.removeLast()
    }

    func reset() {
        digits = ""
        errorMessage = nil
        isUnlocked = false
    }
}

private extension PasscodeViewModel {
    func validate() {
        if passcodeManager.validate(digits) {
            isUnlocked = true
            errorMessage = nil
        } else {
            errorMessage = "Incorrect passcode"
            digits = ""
        }
    }
}
