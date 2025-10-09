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
                    VStack(spacing: 2) {
                        Text("Pick Your Item")
                            .font(.headline)
                        Text(viewModel.title)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
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
        let activeItems = viewModel.items.filter { $0.status == .saved }
        let cardWidth: CGFloat = 200
        let spacing: CGFloat = 20
        let totalWidth = CGFloat(activeItems.count) * (cardWidth + spacing)

        return GeometryReader { geometry in
            HStack(spacing: spacing) {
                // Repeat items 3 times (reduced from 5)
                ForEach(0..<3) { _ in
                    ForEach(activeItems) { item in
                        ItemCardView(item: item, image: imageProvider(item))
                            .frame(width: cardWidth)
                            .opacity(0.6)
                    }
                }
            }
            .offset(x: scrollOffset)
            .frame(width: totalWidth * 3, alignment: .leading)
        }
        .frame(height: 250)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    func winnerDisplay(for item: WantedItemDisplay) -> some View {
        VStack(spacing: Spacing.xl) {
            Spacer()

            // Celebration header with enhanced animations
            VStack(spacing: Spacing.sm) {
                // Trophy icon with animated particles
                ZStack {
                    // Multiple pulsing glow rings
                    ForEach(0..<3) { index in
                        Circle()
                            .fill(Color.yellow.opacity(0.2 - Double(index) * 0.06))
                            .frame(width: 100 + CGFloat(index * 20), height: 100 + CGFloat(index * 20))
                            .scaleEffect(showWinner ? 1.2 : 1.0)
                            .opacity(showWinner ? 0.0 : 1.0)
                            .animation(
                                .easeOut(duration: 1.0)
                                .delay(Double(index) * 0.1),
                                value: showWinner
                            )
                    }

                    // Rotating stars/sparkles
                    ForEach(0..<8) { index in
                        Image(systemName: "star.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.yellow, .orange],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .offset(
                                x: cos(Double(index) * .pi / 4) * 70,
                                y: sin(Double(index) * .pi / 4) * 70
                            )
                            .scaleEffect(showWinner ? 1.0 : 0.0)
                            .opacity(showWinner ? 1.0 : 0.0)
                            .animation(
                                .spring(response: 0.6, dampingFraction: 0.5)
                                .delay(0.2 + Double(index) * 0.05),
                                value: showWinner
                            )
                    }

                    // Trophy icon
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.yellow, .orange],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .shadow(color: .yellow.opacity(0.6), radius: 12, x: 0, y: 4)
                        .scaleEffect(showWinner ? 1.0 : 0.5)
                        .rotationEffect(.degrees(showWinner ? 0 : -180))
                        .animation(.spring(response: 0.8, dampingFraction: 0.6), value: showWinner)
                }
                .frame(height: 150)

                // Month indicator
                Text(viewModel.title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Color.orange.opacity(0.15))
                    )
                    .scaleEffect(showWinner ? 1.0 : 0.8)
                    .opacity(showWinner ? 1.0 : 0.0)
                    .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.25), value: showWinner)

                Text("You Can Buy This!")
                    .font(.system(.title, design: .rounded))
                    .fontWeight(.black)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.orange, .yellow, .orange],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .scaleEffect(showWinner ? 1.0 : 0.8)
                    .opacity(showWinner ? 1.0 : 0.0)
                    .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.3), value: showWinner)

                Text("Guilt-free purchase ✨")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .scaleEffect(showWinner ? 1.0 : 0.8)
                    .opacity(showWinner ? 1.0 : 0.0)
                    .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.35), value: showWinner)
            }

            // Winner card with bounce animation
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
                                lineWidth: 4
                            )
                    )
                    .shadow(color: .yellow.opacity(0.5), radius: 16, x: 0, y: 8)

                if !item.tags.isEmpty {
                    TagListView(tags: item.tags)
                }
            }
            .scaleEffect(showWinner ? 1.0 : 0.5)
            .opacity(showWinner ? 1.0 : 0.0)
            .animation(.spring(response: 0.8, dampingFraction: 0.6).delay(0.4), value: showWinner)

            // KPI Stats
            // Items that were not selected as winner (remain saved)
            let nonWinnerItems = viewModel.items.filter { $0.status == .saved }
            let resistedCount = nonWinnerItems.count
            let totalSaved = nonWinnerItems.reduce(Decimal.zero) { $0 + $1.priceWithTax }

            VStack(spacing: Spacing.sm) {
                Text("You saved on everything else!")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .scaleEffect(showWinner ? 1.0 : 0.8)
                    .opacity(showWinner ? 1.0 : 0.0)
                    .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.5), value: showWinner)

                HStack(spacing: Spacing.lg) {
                    // Money Saved
                    WinnerKPI(
                        icon: "dollarsign.circle.fill",
                        value: CurrencyFormatter.string(from: totalSaved),
                        label: "Money Saved",
                        color: Color.successFallback
                    )
                    .scaleEffect(showWinner ? 1.0 : 0.5)
                    .opacity(showWinner ? 1.0 : 0.0)
                    .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.6), value: showWinner)

                    // Temptations Resisted
                    WinnerKPI(
                        icon: "hand.raised.fill",
                        value: "\(resistedCount)",
                        label: resistedCount == 1 ? "Item Skipped" : "Items Skipped",
                        color: Color.orange
                    )
                    .scaleEffect(showWinner ? 1.0 : 0.5)
                    .opacity(showWinner ? 1.0 : 0.0)
                    .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.7), value: showWinner)
                }
            }
            .padding(.horizontal, Spacing.lg)

            Spacer()
        }
        .padding(Spacing.xl)
    }

    func startSpin() {
        guard viewModel.canDraw else { return }

        let candidates = viewModel.items.filter { $0.status == .saved }
        guard !candidates.isEmpty else { return }

        // Pick winner
        guard let winnerCandidate = candidates.randomElement() else { return }
        let winnerIndex = candidates.firstIndex(where: { $0.id == winnerCandidate.id }) ?? 0

        // Reset state
        isSpinning = true
        scrollOffset = 0
        HapticManager.shared.heavyImpact()

        // Calculate offsets
        let cardWidth: CGFloat = 200
        let spacing: CGFloat = 20
        let cardPlusSpacing = cardWidth + spacing
        let centerScreen = UIScreen.main.bounds.width / 2

        // Phase 1: Fast initial spin (1.5 seconds)
        let phase1Offset = -CGFloat(candidates.count * 2) * cardPlusSpacing
        withAnimation(.easeIn(duration: 1.5)) {
            scrollOffset = phase1Offset
        }

        // Phase 2: Medium speed spin (1.5 seconds)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            HapticManager.shared.mediumImpact()
            let phase2Offset = phase1Offset - (CGFloat(candidates.count) * cardPlusSpacing)
            withAnimation(.linear(duration: 1.5)) {
                self.scrollOffset = phase2Offset
            }
        }

        // Phase 3: Slow down to winner (2 seconds)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            HapticManager.shared.mediumImpact()
            let targetRepetition = 1
            let totalCardsBeforeTarget = (targetRepetition * candidates.count) + winnerIndex
            let finalOffset = centerScreen - (CGFloat(totalCardsBeforeTarget) * cardPlusSpacing) - (cardWidth / 2)

            withAnimation(.easeOut(duration: 2.0)) {
                self.scrollOffset = finalOffset
            }
        }

        // Show winner with celebration (after 5 seconds total)
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            self.isSpinning = false
            self.viewModel.setWinner(winnerCandidate)

            // Multiple haptic bursts for celebration
            HapticManager.shared.success()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                HapticManager.shared.lightImpact()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                HapticManager.shared.lightImpact()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                HapticManager.shared.success()
            }

            withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) {
                self.showWinner = true
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
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.md)
        .padding(.horizontal, Spacing.sm)
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
    item1.status = .saved

    let item2 = WantedItemEntity(context: context)
    item2.id = UUID()
    item2.title = "Headphones"
    item2.price = NSDecimalNumber(value: 40)
    item2.imagePath = ""
    item2.tags = ["audio"]
    item2.createdAt = Date()
    item2.monthKey = summary.monthKey
    item2.status = .saved

    summary.items = NSSet(array: [item1, item2])

    return MonthCloseoutView(viewModel: MonthCloseoutViewModel(summary: summary,
                                                               haptics: container.hapticManager,
                                                               settingsRepository: container.settingsRepository),
                            autoStart: true) { _ in
        nil
    }
}
#endif
