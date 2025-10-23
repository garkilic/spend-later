import SwiftUI
import StoreKit

struct PaywallView: View {
    @StateObject private var viewModel: PaywallViewModel
    @Environment(\.dismiss) private var dismiss
    let totalSaved: Decimal?

    init(viewModel: PaywallViewModel, totalSaved: Decimal? = nil) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.totalSaved = totalSaved
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appSurface.ignoresSafeArea()

                if viewModel.isLoading {
                    loadingView
                } else {
                    contentView
                }
            }
            .navigationTitle("Premium")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: $viewModel.showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                }
            }
            .task {
                await viewModel.loadProducts()
            }
            .onChange(of: viewModel.hasPremiumAccess) { _, hasPremium in
                if hasPremium {
                    dismiss()
                }
            }
        }
    }

    // MARK: - Subviews

    private var loadingView: some View {
        VStack(spacing: Spacing.md) {
            ProgressView()
            Text("Loading products...")
                .font(.subheadline)
                .foregroundColor(.appSecondary)
        }
    }

    private var contentView: some View {
        ScrollView {
            VStack(spacing: Spacing.xl) {
                // Header
                headerSection

                // Nonprofit message
                nonprofitSection

                // Features
                featuresSection

                // Products
                productsSection

                // Restore button
                restoreButton

                // Footer
                footerText
            }
            .padding(.horizontal, Spacing.sideGutter)
            .padding(.vertical, Spacing.xl)
        }
    }

    private var headerSection: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "sparkles")
                .font(.system(size: 60))
                .foregroundColor(.appAccent)

            Text("Founder's Edition")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.appPrimary)

            if let saved = totalSaved, saved > 0 {
                // Value-based messaging showing how much they've saved
                VStack(spacing: Spacing.sm) {
                    Text("You've saved \(CurrencyFormatter.string(from: saved))!")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.appSuccess)

                    Text("That's real money back in your pocket. The app has already proven its value — unlock unlimited tracking to keep the momentum going.")
                        .font(.subheadline)
                        .foregroundColor(.appSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Spacing.md)
                }
            } else {
                // Default messaging
                Text("I love building cool and unique things, but I gotta get paid too. Your support helps me keep creating and shipping new features.")
                    .font(.subheadline)
                    .foregroundColor(.appSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.md)
            }
        }
        .padding(.top, Spacing.lg)
    }

    private var nonprofitSection: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: "heart.circle.fill")
                .font(.system(size: 32))
                .foregroundColor(.pink)

            VStack(alignment: .leading, spacing: 4) {
                Text("50% goes to nonprofits")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.appPrimary)

                Text("Half of every subscription supports amazing causes")
                    .font(.subheadline)
                    .foregroundColor(.appSecondary)
            }

            Spacer()
        }
        .padding(Spacing.md)
        .background(
            LinearGradient(
                colors: [Color.pink.opacity(0.15), Color.purple.opacity(0.15)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(CornerRadius.card)
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.card)
                .stroke(Color.pink.opacity(0.3), lineWidth: 2)
        )
    }

    private var featuresSection: some View {
        VStack(spacing: Spacing.sm) {
            FeatureRow(icon: "wrench.and.screwdriver.fill", title: "Support Development", description: "Help me keep building unique features")
            FeatureRow(icon: "star.fill", title: "All Current Features", description: "Everything available now, unlocked")
            FeatureRow(icon: "arrow.up.forward.circle.fill", title: "All Future Features", description: "New features coming regularly")
            FeatureRow(icon: "heart.fill", title: "Founder Pricing", description: "Lock in this price before it goes up")
        }
        .padding(.vertical, Spacing.md)
    }

    private var productsSection: some View {
        VStack(spacing: Spacing.md) {
            if let subscription = viewModel.subscriptionProduct {
                ProductCard(
                    product: subscription,
                    periodText: viewModel.subscriptionPeriod(for: subscription),
                    isPurchasing: viewModel.isPurchasing
                ) {
                    await viewModel.purchase(subscription)
                }
            }

            if let lifetime = viewModel.lifetimeProduct {
                ProductCard(
                    product: lifetime,
                    periodText: nil,
                    isPurchasing: viewModel.isPurchasing,
                    isRecommended: true
                ) {
                    await viewModel.purchase(lifetime)
                }
            }
        }
    }

    private var restoreButton: some View {
        Button {
            Task {
                await viewModel.restorePurchases()
            }
        } label: {
            Text("Restore Purchases")
                .font(.subheadline)
                .foregroundColor(.appSecondary)
        }
        .disabled(viewModel.isPurchasing)
    }

    private var footerText: some View {
        VStack(spacing: Spacing.xs) {
            Text("Subscriptions auto-renew unless cancelled 24 hours before the period ends.")
                .font(.caption2)
                .foregroundColor(.appSecondary)
                .multilineTextAlignment(.center)

            HStack(spacing: Spacing.md) {
                Link("Terms of Service", destination: URL(string: "https://example.com/terms")!)
                Text("•")
                Link("Privacy Policy", destination: URL(string: "https://example.com/privacy")!)
            }
            .font(.caption2)
            .foregroundColor(.appSecondary)
        }
        .padding(.top, Spacing.lg)
        .padding(.bottom, Spacing.xl)
    }
}

// MARK: - Supporting Views

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.appAccent)
                .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.appPrimary)

                Text(description)
                    .font(.caption)
                    .foregroundColor(.appSecondary)
            }

            Spacer()
        }
    }
}

struct ProductCard: View {
    let product: Product
    let periodText: String?
    let isPurchasing: Bool
    var isRecommended: Bool = false
    let onPurchase: () async -> Void

    var body: some View {
        VStack(spacing: Spacing.md) {
            if isRecommended {
                recommendedBadge
            }

            VStack(spacing: Spacing.xs) {
                Text(product.displayName)
                    .font(.headline)
                    .foregroundColor(.appPrimary)

                if let period = periodText {
                    Text("\(product.displayPrice) / \(period)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.appPrimary)
                } else {
                    Text(product.displayPrice)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.appPrimary)

                    Text("One-time payment")
                        .font(.subheadline)
                        .foregroundColor(.appSecondary)
                }

                if !product.description.isEmpty {
                    Text(product.description)
                        .font(.caption)
                        .foregroundColor(.appSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)
                }
            }
            .padding(.vertical, Spacing.sm)

            Button {
                Task {
                    await onPurchase()
                }
            } label: {
                if isPurchasing {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.appOnAccent)
                } else {
                    Text("Subscribe")
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(isPurchasing ? Color.appSecondary : Color.appAccent)
            .foregroundColor(.appOnAccent)
            .cornerRadius(CornerRadius.button)
            .disabled(isPurchasing)
        }
        .padding(Spacing.md)
        .background(Color.appSurfaceElevated)
        .cornerRadius(CornerRadius.card)
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.card)
                .stroke(isRecommended ? Color.appAccent : Color.appSeparator, lineWidth: isRecommended ? 2 : 1)
        )
    }

    private var recommendedBadge: some View {
        HStack {
            Spacer()
            Text("FOUNDER'S PRICE")
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundColor(.appOnAccent)
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, 4)
                .background(Color.appAccent)
                .cornerRadius(4)
            Spacer()
        }
    }
}

// MARK: - Preview

#if DEBUG && canImport(PreviewsMacros)
#Preview {
    let container = PreviewSupport.container
    let purchaseManager = PurchaseManager()
    let viewModel = PaywallViewModel(purchaseManager: purchaseManager)
    return PaywallView(viewModel: viewModel)
}
#endif
