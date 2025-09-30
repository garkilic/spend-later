import UIKit

final class HapticManager {
    static let shared = HapticManager()
    private let generator = UINotificationFeedbackGenerator()

    func success() {
        generator.notificationOccurred(.success)
    }
}
