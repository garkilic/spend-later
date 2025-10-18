import SwiftUI

enum StatType: Identifiable {
    case temptationsResisted
    case averagePrice
    case buyersRemorse
    case carbonFootprint

    var id: String {
        switch self {
        case .temptationsResisted: return "temptations"
        case .averagePrice: return "average"
        case .buyersRemorse: return "remorse"
        case .carbonFootprint: return "carbon"
        }
    }
}

struct StatDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let type: StatType
    let viewModel: DashboardViewModel
    @State private var showingSharePreview = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.xl) {
                    headerSection
                    explanationSection
                    tipsSection
                }
                .padding(.horizontal, Spacing.sideGutter)
                .padding(.vertical, Spacing.xl)
            }
            .background(Color.surfaceFallback)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingSharePreview) {
                ShareCardPreviewView(cardType: currentCardType)
            }
        }
    }

    private var title: String {
        switch type {
        case .temptationsResisted:
            return "Temptations Resisted"
        case .averagePrice:
            return "Average Price"
        case .buyersRemorse:
            return "Buyer's Remorse"
        case .carbonFootprint:
            return "Carbon Footprint"
        }
    }

    @ViewBuilder
    private var headerSection: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 60))
                .foregroundColor(color)

            Text(mainValue)
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundColor(color)
                .monospacedDigit()

            Text(subtitle)
                .font(.subheadline)
                .foregroundColor(Color.secondaryFallback)
                .multilineTextAlignment(.center)

            // Share button
            Button {
                shareCard()
                HapticManager.shared.lightImpact()
            } label: {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.subheadline)
                    Text("Share This Stat")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.sm)
                .background(color)
                .cornerRadius(CornerRadius.button)
            }
            .padding(.top, Spacing.xs)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.lg)
    }

    @ViewBuilder
    private var explanationSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("What This Means")
                .sectionHeaderStyle()

            Text(explanation)
                .font(.body)
                .foregroundColor(Color.primaryFallback)
                .padding()
                .cardStyle()
        }
    }

    @ViewBuilder
    private var tipsSection: some View {
        if !tips.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Keep It Up")
                    .sectionHeaderStyle()

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    ForEach(tips, id: \.self) { tip in
                        HStack(alignment: .top, spacing: Spacing.sm) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.body)
                                .foregroundColor(Color.successFallback)
                            Text(tip)
                                .font(.body)
                                .foregroundColor(Color.primaryFallback)
                        }
                    }
                }
                .padding()
                .cardStyle()
            }
        }
    }

    private var icon: String {
        switch type {
        case .temptationsResisted:
            return "flame.fill"
        case .averagePrice:
            return "dollarsign.circle.fill"
        case .buyersRemorse:
            return "hand.raised.fill"
        case .carbonFootprint:
            return "leaf.fill"
        }
    }

    private var color: Color {
        switch type {
        case .temptationsResisted:
            return .red
        case .averagePrice:
            return Color.successFallback
        case .buyersRemorse:
            return .purple
        case .carbonFootprint:
            return .green
        }
    }

    private var mainValue: String {
        switch type {
        case .temptationsResisted:
            return "\(viewModel.itemCount)"
        case .averagePrice:
            return CurrencyFormatter.string(from: viewModel.averageItemPrice)
        case .buyersRemorse:
            return "\(viewModel.buyersRemorsePrevented)"
        case .carbonFootprint:
            return viewModel.stats.formatCarbonFootprint(viewModel.carbonFootprintSaved)
        }
    }

    private var subtitle: String {
        switch type {
        case .temptationsResisted:
            return "Impulses you've resisted this month"
        case .averagePrice:
            return "Typical cost per temptation"
        case .buyersRemorse:
            return viewModel.stats.buyersRemorseContext(
                prevented: viewModel.buyersRemorsePrevented,
                total: viewModel.itemCount
            )
        case .carbonFootprint:
            return viewModel.stats.carbonFootprintContext(viewModel.carbonFootprintSaved)
        }
    }

    private var explanation: String {
        switch type {
        case .temptationsResisted:
            return "Every time you track an impulse instead of buying it, you're building stronger willpower. Each resistance makes the next one easier."
        case .averagePrice:
            return "This shows the average cost of items you've resisted. Knowing your typical temptation price helps you understand your spending patterns."
        case .buyersRemorse:
            return "Research shows that 60% of impulse purchases are regretted within 24 hours. By tracking instead of buying, you've prevented these regrets from ever happening."
        case .carbonFootprint:
            return "Every product has a carbon footprint from manufacturing, shipping, and packaging. By not buying, you've prevented this CO₂ from entering the atmosphere."
        }
    }

    private var tips: [String] {
        switch type {
        case .temptationsResisted:
            return [
                "Try to resist one more impulse this week",
                "Share your progress with a friend for accountability",
                "Celebrate small wins along the way"
            ]
        case .averagePrice:
            return [
                "Notice patterns in your spending temptations",
                "Set a monthly budget for impulse items",
                "Track higher-value items to see bigger savings"
            ]
        case .buyersRemorse:
            return [
                "Wait 24 hours before any impulse purchase",
                "Ask yourself: Will I still want this tomorrow?",
                "Keep tracking to prevent future regrets"
            ]
        case .carbonFootprint:
            return [
                "The best purchase is the one not made",
                "Consider borrowing or buying secondhand",
                "Every item saved helps the planet"
            ]
        }
    }

    private var currentCardType: ShareCardType {
        switch type {
        case .temptationsResisted:
            return .temptationsResisted(viewModel.itemCount)
        case .averagePrice:
            return .averagePrice(viewModel.averageItemPrice)
        case .buyersRemorse:
            return .buyersRemorse(viewModel.buyersRemorsePrevented)
        case .carbonFootprint:
            return .carbonFootprint(viewModel.carbonFootprintSaved)
        }
    }

    private func shareCard() {
        showingSharePreview = true
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
    return StatDetailView(type: .carbonFootprint, viewModel: dashboardVM)
}
#endif
