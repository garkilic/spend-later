import SwiftUI
import Combine

struct TestView: View {
    @StateObject private var viewModel: TestViewModel
    @State private var showingCloseout = false
    @State private var timeRemaining: String = ""
    @State private var daysRemaining: Int = 0
    @State private var canSpin: Bool = false
    let imageProvider: (WantedItemDisplay) -> UIImage?
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

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
                        countdownHero
                        currentMonthCard

                        if viewModel.itemCount == 0 {
                            developerToolsCard
                        } else {
                            testingToolsCard
                        }
                    }
                    .padding(.horizontal, Spacing.sideGutter)
                    .padding(.top, Spacing.safeAreaTop)
                    .padding(.bottom, Spacing.xl)
                }
            }
            .navigationTitle("Monthly Reward")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showingCloseout) {
                if let summary = viewModel.testSummary {
                    MonthCloseoutView(viewModel: MonthCloseoutViewModel(
                        summary: summary,
                        haptics: HapticManager.shared,
                        settingsRepository: viewModel.settingsRepository
                    ), autoStart: true) { item in
                        imageProvider(item)
                    }
                }
            }
            .onAppear {
                viewModel.refresh()
                updateCountdown()
            }
            .onReceive(timer) { _ in
                updateCountdown()
            }
        }
    }

    private func updateCountdown() {
        let now = Date()
        let calendar = Calendar.current

        // Get the last day of current month at 11:59:59 PM
        guard let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: calendar.startOfDay(for: now)),
              let lastSecondOfMonth = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: endOfMonth) else {
            return
        }

        let components = calendar.dateComponents([.day, .hour, .minute, .second], from: now, to: lastSecondOfMonth)

        if let days = components.day, let hours = components.hour, let minutes = components.minute, let seconds = components.second {
            if days > 1 {
                timeRemaining = "\(days) days"
                daysRemaining = days
                canSpin = false
            } else if days == 1 {
                timeRemaining = "\(days) day"
                daysRemaining = days
                canSpin = false
            } else if hours > 0 {
                timeRemaining = "\(hours)h \(minutes)m"
                daysRemaining = 0
                canSpin = false
            } else if minutes > 0 {
                timeRemaining = "\(minutes)m \(seconds)s"
                daysRemaining = 0
                canSpin = false
            } else {
                timeRemaining = "Ready!"
                daysRemaining = 0
                canSpin = true
            }
        } else {
            timeRemaining = "Ready!"
            daysRemaining = 0
            canSpin = true
        }
    }
}

private extension TestView {
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
            // Gift icon with pulsing effect
            ZStack {
                // Outer pulsing ring
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.orange.opacity(0.15), Color.red.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 140, height: 140)
                    .scaleEffect(canSpin ? 1.1 : 1.0)
                    .opacity(canSpin ? 0.5 : 0.8)
                    .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: canSpin)

                // Middle ring
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.orange.opacity(0.25), Color.red.opacity(0.15)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)

                // Gift icon
                Image(systemName: canSpin ? "gift.fill" : "lock.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(
                        LinearGradient(
                            colors: canSpin ? [.yellow, .orange] : [.orange, .red],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: canSpin ? .yellow.opacity(0.5) : .clear, radius: 20)
            }
            .frame(maxWidth: .infinity)

            // Countdown display
            VStack(spacing: Spacing.xs) {
                Text(canSpin ? "🎉 Ready to Spin!" : "Reward unlocks in")
                    .font(.subheadline)
                    .foregroundColor(Color.secondaryFallback)
                    .fontWeight(.medium)

                Text(timeRemaining)
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(
                        LinearGradient(
                            colors: canSpin ? [Color.successFallback, Color.successFallback.opacity(0.8)] : [Color.primaryFallback, Color.primaryFallback.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .shadow(color: canSpin ? Color.successFallback.opacity(0.2) : .clear, radius: 8)
            }

            // Spin button integrated in hero card
            if viewModel.itemCount > 0 {
                Button {
                    viewModel.createTestSummary()
                    showingCloseout = true
                    HapticManager.shared.success()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: canSpin ? "gift.fill" : "lock.fill")
                            .font(.title3)
                        if canSpin {
                            Text("🎉 Spin for Your Reward!")
                                .fontWeight(.bold)
                        } else {
                            Text(daysRemaining > 0 ? "Locked for \(daysRemaining) \(daysRemaining == 1 ? "Day" : "Days")" : "Locked Until Month End")
                                .fontWeight(.bold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                }
                .buttonStyle(.borderedProminent)
                .tint(canSpin ? Color.successFallback : Color.gray)
                .disabled(!canSpin)
                .shadow(
                    color: canSpin ? Color.successFallback.opacity(0.3) : Color.clear,
                    radius: 8,
                    y: 4
                )
            }
        }
        .padding(Spacing.xl)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.card)
                .fill(
                    LinearGradient(
                        colors: canSpin ?
                            [Color.successFallback.opacity(0.08), Color.successFallback.opacity(0.04)] :
                            [Color.surfaceElevatedFallback, Color.surfaceElevatedFallback.opacity(0.5)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.card)
                .stroke(
                    canSpin ? Color.successFallback.opacity(0.3) : Color.clear,
                    lineWidth: 2
                )
        )
        .shadow(
            color: canSpin ? Color.successFallback.opacity(0.2) : Color.black.opacity(0.04),
            radius: canSpin ? 16 : 8,
            y: 4
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Monthly reward unlocks in \(timeRemaining)")
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
                    title: "Build your savings",
                    description: "Every item you skip adds to your total saved"
                )

                HowItWorksRow(
                    number: "3",
                    title: "Win a reward",
                    description: "At month's end, spin to win ONE item—you saved money on all the rest!"
                )
            }

            // Highlight savings
            if viewModel.totalSaved > 0 {
                HStack(spacing: 8) {
                    Image(systemName: "star.fill")
                        .foregroundStyle(Color.yellow)
                        .font(.caption)
                    Text("You've already saved \(CurrencyFormatter.string(from: viewModel.totalSaved)) by skipping \(viewModel.itemCount) \(viewModel.itemCount == 1 ? "purchase" : "purchases")!")
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
                    Text("CURRENT MONTH")
                        .sectionHeaderStyle()
                    if viewModel.itemCount > 0 {
                        Text("\(viewModel.itemCount) items in the pool")
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
                    color: Color(red: 1.0, green: 0.3, blue: 0.3),
                    isHighlighted: viewModel.itemCount > 0
                )
            }

            // Action buttons
            if viewModel.itemCount > 0 {
                if viewModel.testSummary != nil {
                    Button {
                        viewModel.resetTestSummary()
                        HapticManager.shared.lightImpact()
                    } label: {
                        Label("Reset Draw", systemImage: "arrow.counterclockwise")
                            .font(.subheadline)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                    }
                    .buttonStyle(.bordered)
                }
            } else {
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

    var developerToolsCard: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Image(systemName: "wrench.and.screwdriver.fill")
                    .font(.title3)
                    .foregroundStyle(Color.secondaryFallback)
                Text("Developer Tools")
                    .font(.headline)
                    .foregroundColor(Color.primaryFallback)
            }

            Divider()

            Button(role: .destructive) {
                viewModel.clearAllData()
                HapticManager.shared.mediumImpact()
            } label: {
                Label("Clear All Data", systemImage: "trash.fill")
                    .font(.subheadline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
            }
            .buttonStyle(.bordered)
            .tint(.red)
        }
        .padding(Spacing.xl)
        .cardStyle()
    }

    var testingToolsCard: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Image(systemName: "ladybug.fill")
                    .font(.title3)
                    .foregroundStyle(Color.orange)
                Text("Testing Tools")
                    .font(.headline)
                    .foregroundColor(Color.primaryFallback)
            }

            Divider()

            Button {
                viewModel.createTestSummary()
                showingCloseout = true
                HapticManager.shared.success()
            } label: {
                Label("🧪 Force Spin (Test)", systemImage: "sparkles")
                    .font(.subheadline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
            }
            .buttonStyle(.bordered)
            .tint(.orange)

            if viewModel.testSummary != nil {
                Button {
                    viewModel.resetTestSummary()
                    HapticManager.shared.lightImpact()
                } label: {
                    Label("Reset Draw", systemImage: "arrow.counterclockwise")
                        .font(.subheadline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(Spacing.xl)
        .cardStyle()
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
                .background(
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.accentFallback, Color.accentFallback.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )

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
