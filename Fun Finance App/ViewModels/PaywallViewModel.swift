import Foundation
import StoreKit
import Combine

@MainActor
final class PaywallViewModel: ObservableObject {
    @Published private(set) var products: [Product] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isPurchasing = false
    @Published var errorMessage: String?
    @Published var showingError = false

    private let purchaseManager: PurchaseManager

    init(purchaseManager: PurchaseManager) {
        self.purchaseManager = purchaseManager
    }

    // MARK: - Computed Properties

    var subscriptionProduct: Product? {
        products.first { $0.type == .autoRenewable }
    }

    var lifetimeProduct: Product? {
        products.first { $0.type == .nonConsumable }
    }

    var hasPremiumAccess: Bool {
        purchaseManager.hasPremiumAccess
    }

    // MARK: - Public Methods

    func loadProducts() async {
        isLoading = true
        errorMessage = nil

        await purchaseManager.loadProducts()
        products = purchaseManager.products

        isLoading = false
    }

    func purchase(_ product: Product) async {
        isPurchasing = true
        errorMessage = nil
        showingError = false

        do {
            let success = try await purchaseManager.purchase(product)
            if success {
                // Purchase successful - view should dismiss
            }
        } catch {
            errorMessage = "Purchase failed: \(error.localizedDescription)"
            showingError = true
        }

        isPurchasing = false
    }

    func restorePurchases() async {
        isPurchasing = true
        errorMessage = nil
        showingError = false

        await purchaseManager.restorePurchases()

        if hasPremiumAccess {
            // Successfully restored
        } else {
            errorMessage = "No previous purchases found"
            showingError = true
        }

        isPurchasing = false
    }

    // MARK: - Helper Methods

    func formattedPrice(for product: Product) -> String {
        product.displayPrice
    }

    func subscriptionPeriod(for product: Product) -> String? {
        guard let subscription = product.subscription else { return nil }

        switch subscription.subscriptionPeriod.unit {
        case .day:
            return subscription.subscriptionPeriod.value == 1 ? "day" : "\(subscription.subscriptionPeriod.value) days"
        case .week:
            return subscription.subscriptionPeriod.value == 1 ? "week" : "\(subscription.subscriptionPeriod.value) weeks"
        case .month:
            return subscription.subscriptionPeriod.value == 1 ? "month" : "\(subscription.subscriptionPeriod.value) months"
        case .year:
            return subscription.subscriptionPeriod.value == 1 ? "year" : "\(subscription.subscriptionPeriod.value) years"
        @unknown default:
            return nil
        }
    }
}
