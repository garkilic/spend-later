import SwiftUI
import UIKit

/// Simple utility for sharing stats as text
@MainActor
struct ShareCardRenderer {

    // App link - update with actual App Store URL when published
    private static let appLink = "https://apps.apple.com/app/fun-finance" // TODO: Replace with actual App Store URL

    /// Presents a share sheet with a simple text message
    static func share(_ cardType: ShareCardType, from viewController: UIViewController) {
        let message = generateShareMessage(for: cardType)

        let activityVC = UIActivityViewController(
            activityItems: [message],
            applicationActivities: nil
        )

        // For iPad support
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = viewController.view
            popover.sourceRect = CGRect(x: viewController.view.bounds.midX,
                                       y: viewController.view.bounds.midY,
                                       width: 0, height: 0)
            popover.permittedArrowDirections = []
        }

        viewController.present(activityVC, animated: true)
    }

    /// Generates a clean, engaging share message with app link
    private static func generateShareMessage(for cardType: ShareCardType) -> String {
        let mainMessage: String
        let emoji: String

        switch cardType {
        case .totalSaved(let amount):
            emoji = "💰"
            mainMessage = "I've saved \(CurrencyFormatter.string(from: amount)) this month by resisting impulse purchases!"
        case .temptationsResisted(let count):
            emoji = "🔥"
            mainMessage = "I've resisted \(count) temptation\(count == 1 ? "" : "s") this month!"
        case .averagePrice(let amount):
            emoji = "📊"
            mainMessage = "My average impulse buy is \(CurrencyFormatter.string(from: amount)). Tracking helps me save!"
        case .buyersRemorse(let count):
            emoji = "✨"
            mainMessage = "I've prevented \(count) potential regret\(count == 1 ? "" : "s") this month!"
        case .carbonFootprint(let kg):
            emoji = "🌍"
            let formatted = kg >= 1000 ? String(format: "%.1ft", kg / 1000) : String(format: "%.0fkg", kg)
            mainMessage = "I've saved \(formatted) of CO₂ by not buying unnecessary items!"
        }

        // Clean, simple format with app link
        return """
        \(emoji) \(mainMessage)

        Track your impulse purchases and build better habits:
        \(appLink)
        """
    }
}

/// Types of shareable stats
enum ShareCardType {
    case totalSaved(Decimal)
    case temptationsResisted(Int)
    case averagePrice(Decimal)
    case buyersRemorse(Int)
    case carbonFootprint(Double)
}

/// Helper to get the root view controller for presenting share sheet
extension UIApplication {
    var keyWindowPresentedController: UIViewController? {
        var viewController = connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }?
            .rootViewController

        // Walk the hierarchy to find the topmost presented controller
        while let presentedViewController = viewController?.presentedViewController {
            viewController = presentedViewController
        }

        return viewController
    }
}
