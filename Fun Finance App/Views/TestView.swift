import SwiftUI
import Combine

struct TestView: View {
    @StateObject private var viewModel: TestViewModel
    @State private var showingCloseout = false
    @State private var timeRemaining: String = ""
    @State private var daysRemaining: Int = 0
    @State private var canSpin: Bool = false
    @State private var countdownTimer: Timer?
    @State private var pulseAnimation: Bool = false
    @State private var rotationAnimation: Double = 0
    let imageProvider: (WantedItemDisplay) -> UIImage?

    init(viewModel: TestViewModel, imageProvider: @escaping (WantedItemDisplay) -> UIImage?) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.imageProvider = imageProvider
    }

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundGradient.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: Spacing.cardSpacing) {
                        // #if DEBUG
                        // debugDateControls
                        // #endif
                        countdownHero
                    }
                    .padding(.horizontal, Spacing.sideGutter)
                    .padding(.top, Spacing.safeAreaTop)
                    .padding(.bottom, Spacing.xl)
                }
            }
            .navigationTitle("Monthly Spin")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showingCloseout) {
                if let summary = viewModel.pendingCloseout {
                    MonthCloseoutView(viewModel: MonthCloseoutViewModel(
                        summary: summary,
                        haptics: HapticManager.shared,
                        settingsRepository: viewModel.settingsRepository
                    ), autoStart: true) { item in
                        imageProvider(item)
                    }
                }
            }
            .onChange(of: showingCloseout) { _, isShowing in
                if !isShowing {
                    // Refresh after closeout to update pending state
                    viewModel.refresh()
                    updateCountdown()
                }
            }
            .onChange(of: viewModel.pendingCloseout) { _, _ in
                // Update countdown when pending closeout changes
                updateCountdown()
            }
            .onAppear {
                viewModel.refresh()
                updateCountdown()
                // Start timer to update countdown every hour
                countdownTimer = Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { _ in
                    Task { @MainActor in
                        viewModel.refresh()
                        updateCountdown()
                    }
                }
            }
            .onDisappear {
                countdownTimer?.invalidate()
                countdownTimer = nil
            }
        }
    }

    private func countdownToNextMonth() -> String {
        #if DEBUG
        let now = RolloverService.debugDate ?? Date()
        #else
        let now = Date()
        #endif
        let calendar = Calendar.current

        // Get first day of next month
        guard let startOfNextMonth = calendar.date(byAdding: .month, value: 1, to: now),
              let firstDayOfNextMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: startOfNextMonth)) else {
            return "N/A"
        }

        let components = calendar.dateComponents([.day], from: now, to: firstDayOfNextMonth)
        guard let days = components.day else { return "N/A" }

        if days > 1 {
            return "\(days) days"
        } else if days == 1 {
            return "1 day"
        } else {
            return "< 1 day"
        }
    }

    private func updateCountdown() {
        // Check if we have a pending closeout (month ready to spin)
        guard viewModel.pendingCloseout != nil else {
            // No pending closeout - calculate time until month end
            #if DEBUG
            let now = RolloverService.debugDate ?? Date()
            #else
            let now = Date()
            #endif
            let calendar = Calendar.current

            // Get the last day of the current month
            guard let startOfMonth = calendar.dateInterval(of: .month, for: now)?.start,
                  let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth) else {
                timeRemaining = "Not Available"
                daysRemaining = 0
                canSpin = false
                return
            }

            // Unlock time is the start of the last day of the month
            let unlockTime = calendar.startOfDay(for: endOfMonth)

            // Calculate time remaining
            let components = calendar.dateComponents([.day], from: now, to: unlockTime)

            guard let days = components.day else {
                timeRemaining = "Not Available"
                daysRemaining = 0
                canSpin = false
                return
            }

            if days > 1 {
                timeRemaining = "\(days) days"
                daysRemaining = days
            } else if days == 1 {
                timeRemaining = "1 day"
                daysRemaining = days
            } else {
                timeRemaining = "< 1 day"
                daysRemaining = 0
            }
            canSpin = false
            return
        }

        // We have a pending closeout - button is ready!
        timeRemaining = "Ready!"
        daysRemaining = 0
        canSpin = true
    }
}

private extension TestView {
    #if DEBUG
    var debugDateControls: some View {
        VStack(spacing: Spacing.sm) {
            Text("🔧 DEBUG: Date Override")
                .font(.caption)
                .foregroundColor(.orange)
                .fontWeight(.bold)
                .textCase(.uppercase)

            HStack(spacing: Spacing.sm) {
                Button("Oct 31, 2025") {
                    let components = DateComponents(year: 2025, month: 10, day: 31, hour: 23, minute: 0, second: 0)
                    RolloverService.debugDate = Calendar.current.date(from: components)
                    viewModel.refresh()
                    updateCountdown()
                    HapticManager.shared.success()
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)

                Button("Nov 1, 2025") {
                    let components = DateComponents(year: 2025, month: 11, day: 1, hour: 12, minute: 0, second: 0)
                    RolloverService.debugDate = Calendar.current.date(from: components)
                    viewModel.refresh()
                    updateCountdown()
                    HapticManager.shared.success()
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)

                Button("Reset All") {
                    // Reset debug date
                    RolloverService.debugDate = nil

                    // Clear all test data
                    viewModel.clearTestData()

                    // Refresh UI
                    viewModel.refresh()
                    updateCountdown()
                    HapticManager.shared.mediumImpact()
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            }
            .font(.caption)

            if let debugDate = RolloverService.debugDate {
                VStack(spacing: 4) {
                    Text("Active Date Override:")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(debugDate.formatted(date: .complete, time: .shortened))
                        .font(.caption)
                        .foregroundColor(.orange)
                        .fontWeight(.semibold)
                }
                .padding(.top, 4)
            } else {
                Text("Using real date")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            }
        }
        .padding()
        .background(
            LinearGradient(
                colors: [Color.orange.opacity(0.15), Color.yellow.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(CornerRadius.card)
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.card)
                .stroke(Color.orange.opacity(0.3), lineWidth: 2)
        )
    }
    #endif

    var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color.surfaceFallback,
                Color.surfaceElevatedFallback
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .opacity(0.06)
        .background(Color.surfaceFallback)
    }

    var countdownHero: some View {
        VStack(spacing: Spacing.lg) {
            if let pendingCloseout = viewModel.pendingCloseout,
               pendingCloseout.winnerItemId != nil,
               let winner = viewModel.items.first(where: { $0.id == pendingCloseout.winnerItemId }) {
                // Claimed reward - show winner with countdown
                claimedRewardContent(winner: winner)
            } else if canSpin {
                readyToSpinContent
            } else {
                lockedStateContent
            }
        }
        .frame(maxWidth: .infinity)
        .background(heroBackground)
        .overlay(heroOverlay)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(canSpin ? "Ready to spin for your reward" : "Monthly reward unlocks in \(timeRemaining)")
    }

    private func claimedRewardContent(winner: WantedItemDisplay) -> some View {
        VStack(spacing: Spacing.lg) {
            // Trophy header
            VStack(spacing: Spacing.sm) {
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

                Text("Your Reward!")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(Color.primaryFallback)

                Text("Claim this guilt-free purchase")
                    .font(.subheadline)
                    .foregroundColor(Color.secondaryFallback)
            }

            // Winner card
            ItemCardView(item: winner, image: imageProvider(winner))
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
                .shadow(color: .yellow.opacity(0.5), radius: 16, x: 0, y: 8)

            // Countdown to next spin
            VStack(spacing: Spacing.xs) {
                Text("Next Spin Available")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(Color.secondaryFallback)
                    .textCase(.uppercase)

                Text(countdownToNextMonth())
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(Color.appPrimary)
                    .monospacedDigit()
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.surfaceElevatedFallback)
            .cornerRadius(CornerRadius.card)
        }
        .padding(Spacing.xl)
    }

    private var readyToSpinContent: some View {
        VStack(spacing: Spacing.xl) {
            animatedGiftIcon
            readyToSpinText
            spinButton
        }
        .padding(Spacing.xl)
    }

    private var animatedGiftIcon: some View {
        ZStack {
            pulsingGlowRings
            giftIconBackground
            giftIcon
            rotatingSparkles
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            pulseAnimation = true
            withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
                rotationAnimation = 360
            }
        }
    }

    private var pulsingGlowRings: some View {
        ForEach(0..<3) { index in
            let ringGradient = LinearGradient(
                colors: [.yellow.opacity(0.3), .orange.opacity(0.2)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Circle()
                .stroke(ringGradient, lineWidth: 2)
                .frame(width: 140 + CGFloat(index * 20), height: 140 + CGFloat(index * 20))
                .opacity(0.6 - Double(index) * 0.2)
                .scaleEffect(pulseAnimation ? 1.1 : 1.0)
                .animation(
                    .easeInOut(duration: 1.5)
                    .repeatForever(autoreverses: true)
                    .delay(Double(index) * 0.2),
                    value: pulseAnimation
                )
        }
    }

    private var giftIconBackground: some View {
        let backgroundGradient = LinearGradient(
            colors: [.yellow.opacity(0.3), .orange.opacity(0.4)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        return Circle()
            .fill(backgroundGradient)
            .frame(width: 120, height: 120)
            .scaleEffect(pulseAnimation ? 1.05 : 1.0)
            .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: pulseAnimation)
    }

    private var giftIcon: some View {
        let iconGradient = LinearGradient(
            colors: [.yellow, .orange],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        return Image(systemName: "gift.fill")
            .font(.system(size: 56))
            .foregroundStyle(iconGradient)
            .shadow(color: .yellow.opacity(0.5), radius: 8, x: 0, y: 4)
            .rotationEffect(.degrees(pulseAnimation ? 5 : -5))
            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: pulseAnimation)
    }

    private var rotatingSparkles: some View {
        ForEach(0..<8) { index in
            let angle = Double(index) * .pi / 4 + rotationAnimation * .pi / 180
            let xOffset = cos(angle) * 80
            let yOffset = sin(angle) * 80

            Image(systemName: "sparkle")
                .font(.system(size: 12))
                .foregroundStyle(.yellow)
                .offset(x: xOffset, y: yOffset)
                .opacity(0.8)
                .scaleEffect(pulseAnimation ? 1.2 : 1.0)
                .animation(
                    .easeInOut(duration: 1.0)
                    .repeatForever(autoreverses: true)
                    .delay(Double(index) * 0.1),
                    value: pulseAnimation
                )
        }
    }

    private var readyToSpinText: some View {
        VStack(spacing: Spacing.xs) {
            Text("🎉 IT'S TIME!")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(.orange)
                .textCase(.uppercase)
                .tracking(2)

            let textGradient = LinearGradient(
                colors: [.orange, .yellow, .orange],
                startPoint: .leading,
                endPoint: .trailing
            )
            Text("Pick Your Reward")
                .font(.system(size: 38, weight: .black, design: .rounded))
                .foregroundStyle(textGradient)
                .shadow(color: .orange.opacity(0.3), radius: 4, x: 0, y: 2)

            Text("Spin to buy ONE item guilt-free")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.top, 2)

            // Days remaining indicator
            if let daysRemaining = viewModel.daysRemainingInWindow {
                HStack(spacing: 4) {
                    Image(systemName: "clock.fill")
                        .font(.caption2)
                    Text("Available for \(daysRemaining) more \(daysRemaining == 1 ? "day" : "days")")
                        .font(.caption)
                        .fontWeight(.semibold)
                }
                .foregroundStyle(.orange.opacity(0.8))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Color.orange.opacity(0.15))
                )
                .padding(.top, 4)
            }
        }
    }

    private var spinButton: some View {
        Button {
            showingCloseout = true
            HapticManager.shared.success()
        } label: {
            let buttonGradient = LinearGradient(
                colors: [.orange, .yellow, .orange],
                startPoint: .leading,
                endPoint: .trailing
            )
            VStack(spacing: 6) {
                HStack(spacing: 12) {
                    Image(systemName: "sparkles")
                        .font(.title2)
                    Text("Spin the Wheel")
                        .font(.title3)
                        .fontWeight(.bold)
                    Image(systemName: "sparkles")
                        .font(.title2)
                }

                if viewModel.itemCount > 0 {
                    Text("Pick 1 of \(viewModel.itemCount) items to buy")
                        .font(.caption)
                        .fontWeight(.medium)
                        .opacity(0.9)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(buttonGradient)
            .foregroundColor(.white)
            .cornerRadius(CornerRadius.button)
            .shadow(color: .orange.opacity(0.5), radius: 12, x: 0, y: 6)
        }
    }

    private var lockedStateContent: some View {
        VStack(spacing: Spacing.lg) {
            ZStack {
                Circle()
                    .fill(Color.gray.opacity(0.1))
                    .frame(width: 120, height: 120)
                Image(systemName: "lock.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)

            VStack(spacing: Spacing.xs) {
                Text(timeRemaining)
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(Color.primaryFallback)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text("until month end")
                    .font(.subheadline)
                    .foregroundColor(Color.secondaryFallback)
            }

            Text("At month end, spin to randomly pick one item you saved this month to buy guilt-free")
                .font(.caption)
                .foregroundColor(Color.secondaryFallback)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.xs)

            if viewModel.itemCount == 0 {
                Text("Add items this month to unlock")
                    .font(.subheadline)
                    .foregroundColor(Color.secondaryFallback)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .padding(.top, Spacing.sm)
            }
        }
        .padding(Spacing.xl)
    }

    private var heroBackground: some View {
        let readyGradient = LinearGradient(
            colors: [Color.orange.opacity(0.15), Color.yellow.opacity(0.1), Color.orange.opacity(0.15)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        let lockedGradient = LinearGradient(
            colors: [Color.surfaceElevatedFallback, Color.surfaceElevatedFallback],
            startPoint: .top,
            endPoint: .bottom
        )
        return RoundedRectangle(cornerRadius: CornerRadius.card)
            .fill(canSpin ? readyGradient : lockedGradient)
    }

    private var heroOverlay: some View {
        let readyStroke = LinearGradient(
            colors: [.yellow.opacity(0.5), .orange.opacity(0.5)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        let lockedStroke = LinearGradient(
            colors: [Color.clear, Color.clear],
            startPoint: .top,
            endPoint: .bottom
        )
        return RoundedRectangle(cornerRadius: CornerRadius.card)
            .stroke(canSpin ? readyStroke : lockedStroke, lineWidth: canSpin ? 2 : 0)
    }

    var ruleExplainerCard: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "sparkles.rectangle.stack.fill")
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.yellow, .orange],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .font(.title2)

                Text("How it Works")
                    .font(.headline)
                    .foregroundColor(Color.primaryFallback)
            }

            VStack(alignment: .leading, spacing: Spacing.sm) {
                HowItWorksRow(
                    number: "1",
                    title: "Log every temptation",
                    description: "Add items you're tempted to buy throughout the month"
                )

                HowItWorksRow(
                    number: "2",
                    title: "Resist & save",
                    description: "Skip buying them and watch your savings grow"
                )

                HowItWorksRow(
                    number: "3",
                    title: "Spin to pick ONE",
                    description: "At month end, randomly pick ONE item to buy guilt-free—you saved on all the rest!"
                )
            }

            // Highlight savings
            if viewModel.totalSaved > 0 {
                HStack(spacing: 8) {
                    Image(systemName: "star.fill")
                        .foregroundStyle(Color.yellow)
                        .font(.caption)
                    Text("You've already saved \(CurrencyFormatter.string(from: viewModel.totalSaved)) by resisting \(viewModel.itemCount) \(viewModel.itemCount == 1 ? "impulse" : "impulses")!")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(Color.successFallback)
                }
                .padding(Spacing.sm)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.successFallback.opacity(0.1))
                .cornerRadius(CornerRadius.listRow)
            }
        }
        .padding(Spacing.lg)
        .cardStyle()
    }

    var currentMonthCard: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            // Header with progress indicator
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("THIS MONTH'S POOL")
                        .sectionHeaderStyle()
                    if viewModel.itemCount > 0 {
                        Text("\(viewModel.itemCount) \(viewModel.itemCount == 1 ? "item" : "items") • Resets next month")
                            .font(.caption)
                            .foregroundColor(Color.secondaryFallback)
                    } else {
                        Text("Pool resets each month")
                            .font(.caption)
                            .foregroundColor(Color.secondaryFallback)
                    }
                }
                Spacer()
            }

            // Stats grid with enhanced visuals
            VStack(spacing: Spacing.sm) {
                monthStatRow(
                    title: "Total saved",
                    value: CurrencyFormatter.string(from: viewModel.totalSaved),
                    icon: "dollarsign.circle.fill",
                    color: Color.successFallback,
                    isHighlighted: viewModel.totalSaved > 0
                )

                monthStatRow(
                    title: "Impulses resisted",
                    value: "\(viewModel.itemCount)",
                    icon: "flame.fill",
                    color: .red,
                    isHighlighted: viewModel.itemCount > 0
                )
            }

            // Empty state
            if viewModel.itemCount == 0 {
                emptyMonthState
            }
        }
        .padding(Spacing.xl)
        .cardStyle()
    }

    func monthStatRow(title: String, value: String, icon: String, color: Color, isHighlighted: Bool) -> some View {
        HStack(spacing: Spacing.md) {
            // Icon circle
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(color)
            }

            // Text
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(Color.secondaryFallback)
                    .textCase(.uppercase)

                Text(value)
                    .font(.system(.title3, design: .rounded))
                    .fontWeight(.bold)
                    .monospacedDigit()
                    .foregroundColor(Color.primaryFallback)
            }

            Spacer()

            // Trend indicator (optional visual flourish)
            if isHighlighted {
                Image(systemName: "arrow.up.right")
                    .font(.caption)
                    .foregroundStyle(color)
            }
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.listRow)
                .fill(isHighlighted ? color.opacity(0.05) : Color.surfaceElevatedFallback)
        )
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.listRow)
                .stroke(isHighlighted ? color.opacity(0.2) : Color.clear, lineWidth: 1)
        )
    }


    var emptyMonthState: some View {
        VStack(spacing: Spacing.sm) {
            Image(systemName: "tray")
                .font(.system(size: 32))
                .foregroundStyle(Color.secondaryFallback.opacity(0.5))
            Text("No items this month")
                .font(.subheadline)
                .foregroundColor(Color.secondaryFallback)
            Text("Add temptations from the Dashboard")
                .font(.caption)
                .foregroundColor(Color.secondaryFallback)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.lg)
    }

}

private struct HowItWorksRow: View {
    let number: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            // Number badge
            Text(number)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(Circle().fill(Color.accentFallback))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(Color.primaryFallback)

                Text(description)
                    .font(.caption)
                    .foregroundColor(Color.secondaryFallback)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

#if DEBUG && canImport(PreviewsMacros)
#Preview {
    let container = PreviewSupport.container
    let viewModel = TestViewModel(
        itemRepository: container.itemRepository,
        monthRepository: container.monthRepository,
        settingsRepository: container.settingsRepository,
        imageStore: container.imageStore,
        haptics: container.hapticManager
    )
    return TestView(viewModel: viewModel) { item in
        container.imageStore.loadImage(named: item.imagePath)
    }
}
#endif
