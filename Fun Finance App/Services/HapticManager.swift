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

    func success() {
        notificationGenerator.notificationOccurred(.success)
    }

    func warning() {
        notificationGenerator.notificationOccurred(.warning)
    }

    func error() {
        notificationGenerator.notificationOccurred(.error)
    }

    func lightImpact() {
        impactLight.impactOccurred()
    }

    func mediumImpact() {
        impactMedium.impactOccurred()
    }

    func heavyImpact() {
        impactHeavy.impactOccurred()
    }
}
