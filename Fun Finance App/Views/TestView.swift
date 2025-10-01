import SwiftUI
import Combine

struct TestView: View {
    @StateObject private var viewModel: TestViewModel
    @State private var showingCloseout = false
    @State private var timeRemaining: String = ""
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
                        ruleExplainerCard
                        currentMonthCard

                        if viewModel.itemCount == 0 {
                            developerToolsCard
                        }
                    }
                    .padding(.horizontal, Spacing.sideGutter)
                    .padding(.top, Spacing.safeAreaTop)
                    .padding(.bottom, Spacing.xl)
                }
            }
            .navigationTitle("Monthly Reward")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        // TODO: Navigate to settings
                    }) {
                        Image(systemName: "gearshape")
                            .imageScale(.large)
                    }
                    .accessibilityLabel("Settings")
                }
            }
            .sheet(isPresented: $showingCloseout) {
                if let summary = viewModel.testSummary {
                    MonthCloseoutView(viewModel: MonthCloseoutViewModel(
                        summary: summary,
                        haptics: HapticManager.shared,
                        settingsRepository: viewModel.settingsRepository
                    )) { item in
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
                canSpin = false
            } else if days == 1 {
                timeRemaining = "\(days) day"
                canSpin = false
            } else if hours > 0 {
                timeRemaining = "\(hours)h \(minutes)m"
                canSpin = false
            } else if minutes > 0 {
                timeRemaining = "\(minutes)m \(seconds)s"
                canSpin = false
            } else {
                timeRemaining = "Ready!"
                canSpin = true
            }
        } else {
            timeRemaining = "Ready!"
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
        HStack(alignment: .center, spacing: Spacing.lg) {
            // Left: Countdown info
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Reward unlocks in")
                    .font(.subheadline)
                    .foregroundColor(Color.secondaryFallback)

                Text(timeRemaining)
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(canSpin ? Color.successFallback : Color.primaryFallback)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            Spacer()

            // Right: Gift icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.orange.opacity(0.2), Color.red.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)

                Image(systemName: "gift.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.orange, .red],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
        }
        .padding(Spacing.xl)
        .cardStyle()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Monthly reward unlocks in \(timeRemaining)")
    }

    var ruleExplainerCard: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "info.circle.fill")
                .foregroundColor(Color.accentFallback)
                .font(.title3)

            Text("Resist impulse purchases all month, redeem one item at month end")
                .font(.footnote)
                .foregroundColor(Color.secondaryFallback)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
        }
        .padding(Spacing.md)
        .background(Color.accentFallback.opacity(0.08))
        .cornerRadius(CornerRadius.listRow)
    }

    var currentMonthCard: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("CURRENT MONTH")
                .font(.footnote)
                .textCase(.uppercase)
                .tracking(0.02 * 12)
                .foregroundColor(Color.secondaryFallback)

            // Stats grid
            HStack(spacing: Spacing.cardSpacing) {
                monthStat(
                    title: "Total saved",
                    value: CurrencyFormatter.string(from: viewModel.totalSaved),
                    icon: "dollarsign.circle.fill",
                    color: Color.successFallback
                )

                monthStat(
                    title: "Impulses resisted",
                    value: "\(viewModel.itemCount)",
                    icon: "flame.fill",
                    color: Color(red: 1.0, green: 0.3, blue: 0.3)
                )
            }

            Divider()
                .padding(.vertical, Spacing.xs)

            // Action buttons
            if viewModel.itemCount > 0 {
                VStack(spacing: Spacing.xs) {
                    Button {
                        viewModel.createTestSummary()
                        showingCloseout = true
                        HapticManager.shared.success()
                    } label: {
                        HStack {
                            Image(systemName: canSpin ? "gift.fill" : "sparkles")
                            Text(canSpin ? "Spin for Reward!" : "Force Spin (Test)")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(canSpin ? Color.successFallback : Color.accentFallback)

                    if viewModel.testSummary != nil {
                        Button {
                            viewModel.resetTestSummary()
                            HapticManager.shared.lightImpact()
                        } label: {
                            Label("Reset Draw", systemImage: "arrow.counterclockwise")
                                .font(.subheadline)
                                .frame(maxWidth: .infinity)
                                .frame(height: 40)
                        }
                        .buttonStyle(.bordered)
                    }
                }
            } else {
                emptyMonthState
            }
        }
        .padding(Spacing.xl)
        .cardStyle()
    }

    func monthStat(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(color)
                Spacer()
            }

            Spacer()

            Text(value)
                .font(.system(.title3, design: .rounded))
                .fontWeight(.bold)
                .monospacedDigit()
                .foregroundColor(Color.primaryFallback)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(title)
                .font(.caption2)
                .foregroundColor(Color.secondaryFallback)
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 100)
        .background(Color.surfaceElevatedFallback)
        .cornerRadius(CornerRadius.listRow)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value)")
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
