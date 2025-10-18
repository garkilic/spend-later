import SwiftUI
import UIKit

/// Utility for rendering ShareCardView as UIImage for sharing
@MainActor
struct ShareCardRenderer {

    /// Renders a ShareCardView as a UIImage
    static func render(_ cardType: ShareCardType) -> UIImage? {
        let cardView = ShareCardView(type: cardType)
        let controller = UIHostingController(rootView: cardView)

        // Set the size to match the ShareCardView frame
        let targetSize = CGSize(width: 600, height: 800)
        controller.view.bounds = CGRect(origin: .zero, size: targetSize)
        controller.view.backgroundColor = .clear

        // Render the view
        let renderer = UIGraphicsImageRenderer(size: targetSize)

        return renderer.image { context in
            controller.view.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true)
        }
    }

    /// Presents a share sheet for the given card type
    static func share(_ cardType: ShareCardType, from viewController: UIViewController) {
        guard let image = render(cardType) else { return }

        let activityVC = UIActivityViewController(
            activityItems: [image],
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
