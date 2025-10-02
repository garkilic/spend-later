import Foundation

enum ItemStatus: String, CaseIterable {
    case active
    case redeemed       // Won the spin, pending confirmation
    case purchased      // Confirmed: user bought it
    case notPurchased   // Confirmed: user didn't buy it
    case skipped
}
