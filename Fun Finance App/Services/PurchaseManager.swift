import Foundation
import StoreKit
import Combine

/// Product identifiers for in-app purchases
enum ProductIdentifier: String, CaseIterable {
    case monthlySubscription = "com.funfinance.premium.monthly"

    var id: String { rawValue }
}

/// Represents the user's premium entitlement status
enum EntitlementStatus {
    case active
    case inactive
}

/// Manages in-app purchases using StoreKit 2
@MainActor
final class PurchaseManager: ObservableObject {
    @Published private(set) var products: [Product] = []
    @Published private(set) var purchasedProductIDs = Set<String>()
    @Published private(set) var entitlementStatus: EntitlementStatus = .inactive

    private var transactionListener: Task<Void, Error>?

    init() {
        // Start listening for transaction updates
        transactionListener = listenForTransactions()

        Task {
            await loadProducts()
            await updatePurchasedProducts()
        }
    }

    deinit {
        transactionListener?.cancel()
    }

    // MARK: - Public Methods

    /// Load available products from the App Store
    func loadProducts() async {
        do {
            let productIDs = ProductIdentifier.allCases.map { $0.id }
            print("🛒 Requesting products: \(productIDs)")

            let storeProducts = try await Product.products(for: productIDs)
            print("✅ Loaded \(storeProducts.count) products from App Store")

            for product in storeProducts {
                print("  📦 \(product.id): \(product.displayName) - \(product.displayPrice)")
            }

            products = storeProducts

            if products.isEmpty {
                print("⚠️ No products loaded. Check:")
                print("   1. Product ID matches App Store Connect: \(productIDs.first ?? "none")")
                print("   2. StoreKit Configuration enabled in scheme")
                print("   3. Product status is 'Ready to Submit' in App Store Connect")
            }
        } catch {
            print("❌ Failed to load products: \(error)")
            print("   Error details: \(error.localizedDescription)")
        }
    }

    /// Purchase a product
    func purchase(_ product: Product) async throws -> Bool {
        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await transaction.finish()
            await updatePurchasedProducts()
            return true

        case .userCancelled:
            return false

        case .pending:
            return false

        @unknown default:
            return false
        }
    }

    /// Restore previous purchases
    func restorePurchases() async {
        try? await AppStore.sync()
        await updatePurchasedProducts()
    }

    /// Check if user has premium access
    var hasPremiumAccess: Bool {
        // No monetization - everyone has premium access
        return true
    }

    // MARK: - Private Methods

    /// Listen for transaction updates
    private func listenForTransactions() -> Task<Void, Error> {
        Task.detached {
            for await result in Transaction.updates {
                do {
                    let transaction = try self.checkVerified(result)
                    await transaction.finish()
                    await self.updatePurchasedProducts()
                } catch {
                    print("Transaction verification failed: \(error)")
                }
            }
        }
    }

    /// Update the list of purchased products
    private func updatePurchasedProducts() async {
        var purchasedIDs = Set<String>()

        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)

                // Check if the transaction is valid
                if let expirationDate = transaction.expirationDate {
                    // Subscription - check if still active
                    if expirationDate > Date() {
                        purchasedIDs.insert(transaction.productID)
                    }
                } else {
                    // Non-consumable or lifetime purchase
                    purchasedIDs.insert(transaction.productID)
                }
            } catch {
                print("Failed to verify transaction: \(error)")
            }
        }

        purchasedProductIDs = purchasedIDs
        updateEntitlementStatus()
    }

    /// Update the entitlement status based on purchases
    private func updateEntitlementStatus() {
        // User has premium if they have any active purchase
        entitlementStatus = purchasedProductIDs.isEmpty ? .inactive : .active
    }

    /// Verify transaction is valid and not compromised
    private nonisolated func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw PurchaseError.failedVerification
        case .verified(let safe):
            return safe
        }
    }
}

// MARK: - Errors

enum PurchaseError: LocalizedError {
    case failedVerification

    var errorDescription: String? {
        switch self {
        case .failedVerification:
            return "Transaction verification failed"
        }
    }
}
