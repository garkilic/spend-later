import SwiftUI
import UIKit

/// Simple utility for sharing stats as text
@MainActor
struct ShareCardRenderer {

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

    /// Generates a simple share message
    private static func generateShareMessage(for cardType: ShareCardType) -> String {
        switch cardType {
        case .totalSaved(let amount):
            return "I've saved \(CurrencyFormatter.string(from: amount)) this month with Spend Later!"
        case .temptationsResisted(let count):
            return "I've resisted \(count) temptation\(count == 1 ? "" : "s") this month with Spend Later!"
        case .averagePrice(let amount):
            return "My average impulse purchase is \(CurrencyFormatter.string(from: amount)) - tracked with Spend Later!"
        case .buyersRemorse(let count):
            return "I've prevented \(count) potential regret\(count == 1 ? "" : "s") this month with Spend Later!"
        case .carbonFootprint(let kg):
            let formatted = kg >= 1000 ? String(format: "%.1ft", kg / 1000) : String(format: "%.0fkg", kg)
            return "I've saved \(formatted) of CO₂ this month with Spend Later!"
        }
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
