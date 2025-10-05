import UIKit

protocol HapticFeedback {
    func success()
    func warning()
    func error()
    func lightImpact()
    func mediumImpact()
    func heavyImpact()
}

final class HapticManager: HapticFeedback {
    static let shared = HapticManager()
    private let notificationGenerator = UINotificationFeedbackGenerator()
    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)

    // Check if running on simulator to suppress haptic errors
    private var isSimulator: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }

    func success() {
        guard !isSimulator else { return }
        notificationGenerator.notificationOccurred(.success)
    }

    func warning() {
        guard !isSimulator else { return }
        notificationGenerator.notificationOccurred(.warning)
    }

    func error() {
        guard !isSimulator else { return }
        notificationGenerator.notificationOccurred(.error)
    }

    func lightImpact() {
        guard !isSimulator else { return }
        impactLight.impactOccurred()
    }

    func mediumImpact() {
        guard !isSimulator else { return }
        impactMedium.impactOccurred()
    }

    func heavyImpact() {
        guard !isSimulator else { return }
        impactHeavy.impactOccurred()
    }
}
