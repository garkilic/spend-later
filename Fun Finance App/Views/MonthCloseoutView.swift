import CoreData
import SwiftUI

struct MonthCloseoutView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: MonthCloseoutViewModel
    let imageProvider: (WantedItemDisplay) -> UIImage?
    let autoStart: Bool
    @State private var scrollOffset: CGFloat = 0
    @State private var isSpinning = false
    @State private var showWinner = false
    @Namespace private var animation

    init(viewModel: MonthCloseoutViewModel, autoStart: Bool = false, imageProvider: @escaping (WantedItemDisplay) -> UIImage?) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.autoStart = autoStart
        self.imageProvider = imageProvider
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.surfaceFallback
                    .ignoresSafeArea()

                if showWinner, let winner = viewModel.winner {
                    // Winner revealed - show card centered
                    winnerDisplay(for: winner)
                } else if isSpinning {
                    // Spinning carousel
                    spinningCarousel
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Your Reward")
                        .font(.headline)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if showWinner {
                        Button("Done") { dismiss() }
                    }
                }
            }
            .onAppear {
                if autoStart && !isSpinning && viewModel.winner == nil {
                    startSpin()
                }
            }
        }
    }
}

private extension MonthCloseoutView {
    var spinningCarousel: some View {
        let activeItems = viewModel.items.filter { $0.status == .active }
        let cardWidth: CGFloat = 200
        let spacing: CGFloat = 20
        let totalWidth = CGFloat(activeItems.count) * (cardWidth + spacing)

        return GeometryReader { geometry in
            HStack(spacing: spacing) {
                // Repeat items multiple times for continuous effect
                ForEach(0..<5) { _ in
                    ForEach(activeItems) { item in
                        ItemCardView(item: item, image: imageProvider(item))
                            .frame(width: cardWidth)
                            .blur(radius: 10)
                    }
                }
            }
            .offset(x: scrollOffset)
            .frame(width: totalWidth * 5, alignment: .leading)
        }
        .frame(height: 250)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    func winnerDisplay(for item: WantedItemDisplay) -> some View {
        VStack(spacing: Spacing.xl) {
            Spacer()

            // Celebration header
            VStack(spacing: Spacing.sm) {
                // Trophy icon with particles
                ZStack {
                    // Glow effect
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [.yellow.opacity(0.4), .clear],
                                center: .center,
                                startRadius: 15,
                                endRadius: 50
                            )
                        )
                        .frame(width: 100, height: 100)

                    Image(systemName: "trophy.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.yellow, .orange],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: .yellow.opacity(0.6), radius: 15)
                }

                Text("🎉 Congratulations!")
                    .font(.system(.title, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundColor(Color.primaryFallback)
            }

            // Winner card
            VStack(spacing: Spacing.md) {
                ItemCardView(item: item, image: imageProvider(item))
                    .frame(maxWidth: 320)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                LinearGradient(
                                    colors: [.yellow, .orange, .yellow],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 3
                            )
                    )
                    .shadow(color: .yellow.opacity(0.5), radius: 24, y: 12)

                if !item.tags.isEmpty {
                    TagListView(tags: item.tags)
                }
            }
            .scaleEffect(showWinner ? 1.0 : 0.8)
            .opacity(showWinner ? 1.0 : 0.0)
            .animation(.spring(response: 0.6, dampingFraction: 0.7), value: showWinner)

            // KPI Stats
            // Items that were skipped (not selected as winner)
            let skippedItems = viewModel.items.filter { $0.status == .skipped }
            let skippedCount = skippedItems.count
            let totalSaved = skippedItems.reduce(Decimal.zero) { $0 + $1.priceWithTax }

            // Total items in the month
            let totalItemsLogged = viewModel.items.count

            // Savings rate: percentage of items not purchased (skipped + notPurchased)
            let itemsNotPurchased = viewModel.items.filter { $0.status == .skipped || $0.status == .notPurchased }
            let savingsRate = totalItemsLogged > 0 ? (Double(itemsNotPurchased.count) / Double(totalItemsLogged)) * 100 : 0

            HStack(spacing: Spacing.md) {
                // Money Saved
                WinnerKPI(
                    icon: "dollarsign.circle.fill",
                    value: CurrencyFormatter.string(from: totalSaved),
                    label: "Total Saved",
                    color: Color.successFallback
                )

                // Temptations Resisted
                WinnerKPI(
                    icon: "hand.raised.fill",
                    value: "\(skippedCount)",
                    label: skippedCount == 1 ? "Temptation Resisted" : "Temptations Resisted",
                    color: Color.orange
                )

                // Savings Rate
                WinnerKPI(
                    icon: "chart.line.uptrend.xyaxis",
                    value: String(format: "%.0f%%", savingsRate),
                    label: "Savings Rate",
                    color: Color.blue
                )
            }
            .padding(.horizontal, Spacing.md)

            Spacer()
        }
        .padding(Spacing.xl)
    }

    func startSpin() {
        guard viewModel.canDraw else { return }

        let candidates = viewModel.items.filter { $0.status == .active }
        guard !candidates.isEmpty else { return }

        // Pick winner
        guard let winnerCandidate = candidates.randomElement() else { return }
        let winnerIndex = candidates.firstIndex(where: { $0.id == winnerCandidate.id }) ?? 0

        // Reset state
        isSpinning = true
        scrollOffset = 0
        HapticManager.shared.heavyImpact()

        // Calculate target offset to center winner
        let cardWidth: CGFloat = 200
        let spacing: CGFloat = 20
        let cardPlusSpacing = cardWidth + spacing

        // We repeat items 5 times, so use middle repetition (index 2)
        let targetRepetition = 2
        let totalCardsBeforeTarget = (targetRepetition * candidates.count) + winnerIndex
        let centerScreen = UIScreen.main.bounds.width / 2
        let finalOffset = centerScreen - (CGFloat(totalCardsBeforeTarget) * cardPlusSpacing) - (cardWidth / 2)

        // Fast spin: move through many cards quickly
        let spinDistance: CGFloat = -3000

        // Phase 1: Fast spin (0.8 seconds)
        withAnimation(.linear(duration: 0.8)) {
            scrollOffset = spinDistance
        }

        // Phase 2: Slow down and land on winner (1.5 seconds with easeOut)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.easeOut(duration: 1.5)) {
                self.scrollOffset = finalOffset
            }

            // Haptic feedback during slowdown
            HapticManager.shared.lightImpact()

            // Final celebration - show winner
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                self.isSpinning = false
                self.viewModel.setWinner(winnerCandidate)
                HapticManager.shared.success()

                withAnimation {
                    self.showWinner = true
                }
            }
        }
    }
}

private struct WinnerKPI: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: Spacing.sm) {
            // Icon
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 56, height: 56)

                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)
            }

            // Value
            Text(value)
                .font(.system(.title, design: .rounded))
                .fontWeight(.bold)
                .monospacedDigit()
                .foregroundColor(Color.primaryFallback)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            // Label
            Text(label)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(Color.secondaryFallback)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.lg)
        .padding(.horizontal, Spacing.xs)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.listRow)
                .fill(Color.surfaceElevatedFallback)
        )
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.listRow)
                .stroke(color.opacity(0.3), lineWidth: 1.5)
        )
    }
}

#if DEBUG && canImport(PreviewsMacros)
#Preview {
    let container = PreviewSupport.container
    let context = container.viewContext

    let summary = MonthSummaryEntity(context: context)
    summary.id = UUID()
    summary.monthKey = "2025,09"
    summary.totalSaved = NSDecimalNumber(value: 120)
    summary.itemCount = 2

    let item1 = WantedItemEntity(context: context)
    item1.id = UUID()
    item1.title = "Sneakers"
    item1.price = NSDecimalNumber(value: 80)
    item1.imagePath = ""
    item1.tags = ["style", "fitness"]
    item1.createdAt = Date()
    item1.monthKey = summary.monthKey
    item1.status = .active

    let item2 = WantedItemEntity(context: context)
    item2.id = UUID()
    item2.title = "Headphones"
    item2.price = NSDecimalNumber(value: 40)
    item2.imagePath = ""
    item2.tags = ["audio"]
    item2.createdAt = Date()
    item2.monthKey = summary.monthKey
    item2.status = .active

    summary.items = NSSet(array: [item1, item2])

    return MonthCloseoutView(viewModel: MonthCloseoutViewModel(summary: summary,
                                                               haptics: container.hapticManager,
                                                               settingsRepository: container.settingsRepository),
                            autoStart: true) { _ in
        nil
    }
}
#endif
