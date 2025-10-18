import Foundation
import Combine

/// Tracks total savings and enforces free tier limits
@MainActor
final class SavingsTracker: ObservableObject {
    @Published private(set) var totalSavings: Decimal = 0
    @Published private(set) var isAtCap: Bool = false
    @Published private(set) var showWarning: Bool = false
    @Published private(set) var warningMessage: String = ""

    private let itemRepository: ItemRepositoryProtocol
    let purchaseManager: PurchaseManager

    // Free tier cap - $1500 total value
    static let freeTierCap: Decimal = 1500
    static let warningThreshold: Decimal = 1000  // Show warning at $1000
    static let urgentThreshold: Decimal = 1400   // Show urgent warning at $1400

    init(itemRepository: ItemRepositoryProtocol, purchaseManager: PurchaseManager) {
        self.itemRepository = itemRepository
        self.purchaseManager = purchaseManager
    }

    // MARK: - Public Methods

    /// Calculate total value of all items
    func calculateTotalSavings() {
        do {
            let allItems = try itemRepository.allItems()
            totalSavings = allItems.reduce(Decimal(0)) { total, item in
                total + item.price.decimalValue
            }

            updateStatus()
        } catch {
            print("Failed to calculate savings: \(error)")
        }
    }

    /// Check if user can add new items (returns true if allowed, false if blocked)
    func canAddItems() -> Bool {
        // Premium users can always add items
        if purchaseManager.hasPremiumAccess {
            return true
        }

        // Free users are blocked at cap
        return !isAtCap
    }

    /// Get progress toward the cap (0.0 to 1.0)
    var progressTowardCap: Double {
        guard Self.freeTierCap > 0 else { return 0 }
        let progress = NSDecimalNumber(decimal: totalSavings).doubleValue / NSDecimalNumber(decimal: Self.freeTierCap).doubleValue
        return min(progress, 1.0)
    }

    /// Get remaining amount before hitting cap
    var remainingBeforeCap: Decimal {
        let remaining = Self.freeTierCap - totalSavings
        return max(remaining, 0)
    }

    // MARK: - Private Methods

    private func updateStatus() {
        // Premium users never hit the cap
        if purchaseManager.hasPremiumAccess {
            isAtCap = false
            showWarning = false
            warningMessage = ""
            return
        }

        // Check if at cap
        isAtCap = totalSavings >= Self.freeTierCap

        // Determine warning level
        if totalSavings >= Self.freeTierCap {
            showWarning = true
            isAtCap = true
            let overage = totalSavings - Self.freeTierCap
            if overage > 0 {
                warningMessage = "You're $\(formatAmount(overage)) over the free limit. Upgrade to continue tracking."
            } else {
                warningMessage = "You've hit the free limit. Upgrade to continue tracking."
            }
        } else if totalSavings >= Self.urgentThreshold {
            showWarning = true
            let remaining = Self.freeTierCap - totalSavings
            warningMessage = "$\(formatAmount(remaining)) left before hitting the free limit"
        } else if totalSavings >= Self.warningThreshold {
            showWarning = true
            let remaining = Self.freeTierCap - totalSavings
            warningMessage = "$\(formatAmount(remaining)) left in your free tier"
        } else {
            showWarning = false
            warningMessage = ""
        }
    }

    private func formatAmount(_ amount: Decimal) -> String {
        let number = NSDecimalNumber(decimal: amount)
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        return formatter.string(from: number) ?? "0"
    }
}
