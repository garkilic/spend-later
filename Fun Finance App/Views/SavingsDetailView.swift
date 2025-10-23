import SwiftUI

struct SavingsDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let viewModel: DashboardViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.xl) {
                    headerSection
                    monthBreakdownSection
                    insightsSection
                    tipsSection
                }
                .padding(.horizontal, Spacing.sideGutter)
                .padding(.vertical, Spacing.xl)
            }
            .background(Color.surfaceFallback)
            .navigationTitle("Savings Overview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var headerSection: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 60))
                .foregroundColor(Color.successFallback)

            Text(CurrencyFormatter.string(from: viewModel.totalSaved))
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundColor(Color.successFallback)
                .monospacedDigit()

            Text("Saved this month")
                .font(.subheadline)
                .foregroundColor(Color.secondaryFallback)

            // Share button
            Button {
                shareCard()
                HapticManager.shared.lightImpact()
            } label: {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.subheadline)
                    Text("Share Your Win")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.sm)
                .background(Color.successFallback)
                .cornerRadius(CornerRadius.button)
            }
            .padding(.top, Spacing.xs)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.lg)
    }

    @ViewBuilder
    private var monthBreakdownSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("This Month's Breakdown")
                .sectionHeaderStyle()

            VStack(spacing: Spacing.xs) {
                breakdownRow(
                    icon: "flame.fill",
                    label: "Temptations Resisted",
                    value: "\(viewModel.itemCount)",
                    color: .red
                )

                Divider()

                breakdownRow(
                    icon: "dollarsign.circle.fill",
                    label: "Average Per Item",
                    value: CurrencyFormatter.string(from: viewModel.averageItemPrice),
                    color: Color.successFallback
                )

                Divider()

                breakdownRow(
                    icon: "hand.raised.fill",
                    label: "Regrets Prevented",
                    value: "\(viewModel.buyersRemorsePrevented)",
                    color: .purple
                )

                Divider()

                breakdownRow(
                    icon: "leaf.fill",
                    label: "CO₂ Emissions Saved",
                    value: viewModel.stats.formatCarbonFootprint(viewModel.carbonFootprintSaved),
                    color: .green
                )
            }
            .padding()
            .cardStyle()
        }
    }

    @ViewBuilder
    private var insightsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Insights")
                .sectionHeaderStyle()

            VStack(alignment: .leading, spacing: Spacing.md) {
                if viewModel.itemCount > 0 {
                    insightCard(
                        icon: "sparkles",
                        title: "Willpower Strength",
                        message: "You've resisted \(viewModel.itemCount) temptation\(viewModel.itemCount == 1 ? "" : "s") this month. Each time you resist, you're building stronger habits.",
                        color: .orange
                    )
                }

                if viewModel.totalSaved > 100 {
                    insightCard(
                        icon: "trophy.fill",
                        title: "Real Money Saved",
                        message: "That's \(CurrencyFormatter.string(from: viewModel.totalSaved)) back in your pocket. Imagine what you could do with that money!",
                        color: Color.successFallback
                    )
                }

                if viewModel.buyersRemorsePrevented > 0 {
                    insightCard(
                        icon: "heart.fill",
                        title: "Peace of Mind",
                        message: "You've avoided \(viewModel.buyersRemorsePrevented) potential regret\(viewModel.buyersRemorsePrevented == 1 ? "" : "s"). That's priceless emotional savings.",
                        color: .pink
                    )
                }
            }
        }
    }

    @ViewBuilder
    private var tipsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Keep The Momentum")
                .sectionHeaderStyle()

            VStack(alignment: .leading, spacing: Spacing.xs) {
                tipRow(tip: "Review your wins weekly to stay motivated")
                tipRow(tip: "Share your progress with a friend for accountability")
                tipRow(tip: "Celebrate small victories along the way")
                tipRow(tip: "Use saved money for meaningful goals")
            }
        }
    }

    @ViewBuilder
    private func breakdownRow(icon: String, label: String, value: String, color: Color) -> some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
                .frame(width: 28)

            Text(label)
                .font(.body)
                .foregroundColor(Color.primaryFallback)

            Spacer()

            Text(value)
                .font(.body)
                .fontWeight(.semibold)
                .foregroundColor(Color.primaryFallback)
                .monospacedDigit()
        }
    }

    @ViewBuilder
    private func insightCard(icon: String, title: String, message: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(Color.primaryFallback)

                Text(message)
                    .font(.subheadline)
                    .foregroundColor(Color.secondaryFallback)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(CornerRadius.card)
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.card)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func tipRow(tip: String) -> some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Image(systemName: "checkmark.circle.fill")
                .font(.body)
                .foregroundColor(Color.successFallback)
            Text(tip)
                .font(.body)
                .foregroundColor(Color.primaryFallback)
        }
    }

    private func shareCard() {
        guard let viewController = UIApplication.shared.keyWindowPresentedController else { return }
        ShareCardRenderer.share(.totalSaved(viewModel.totalSaved), from: viewController)
    }
}

#if DEBUG && canImport(PreviewsMacros)
#Preview {
    let container = PreviewSupport.container
    let dashboardVM = DashboardViewModel(
        itemRepository: container.itemRepository,
        monthRepository: container.monthRepository,
        settingsRepository: container.settingsRepository,
        imageStore: container.imageStore
    )
    return SavingsDetailView(viewModel: dashboardVM)
}
#endif
