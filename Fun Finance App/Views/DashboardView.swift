import SwiftUI

struct DashboardView: View {
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var viewModel: DashboardViewModel
    @StateObject private var addItemViewModel: AddItemViewModel
    @ObservedObject var savingsTracker: SavingsTracker
    @State private var showingAddSheet = false
    @State private var selectedItem: WantedItemDisplay?
    @State private var showingGraph = false
    @State private var itemToDelete: WantedItemDisplay?
    @State private var showingDeleteConfirmation = false
    @State private var showingPaywall = false
    @State private var selectedStat: StatType?
    let onOpenSettings: () -> Void
    let makeDetailViewModel: (WantedItemDisplay) -> ItemDetailViewModel

    init(viewModel: DashboardViewModel,
         addItemViewModel: AddItemViewModel,
         savingsTracker: SavingsTracker,
         onOpenSettings: @escaping () -> Void,
         makeDetailViewModel: @escaping (WantedItemDisplay) -> ItemDetailViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
        _addItemViewModel = StateObject(wrappedValue: addItemViewModel)
        self.savingsTracker = savingsTracker
        self.onOpenSettings = onOpenSettings
        self.makeDetailViewModel = makeDetailViewModel
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                backgroundGradient.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: Spacing.cardSpacing) {
                        savingsHero
                        warningCard
                        statsRow
                        recentActivitySection
                    }
                    .padding(.horizontal, Spacing.sideGutter)
                    .padding(.top, Spacing.safeAreaTop)
                    .padding(.bottom, 80) // Space for sticky button
                }

                // Sticky Add Button
                addButton
            }
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.large)
            .errorBanner($viewModel.errorMessage)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: onOpenSettings) {
                        Image(systemName: "gearshape")
                            .imageScale(.large)
                    }
                    .accessibilityLabel("Settings")
                }
            }
            .overlay(undoBanner, alignment: .bottom)
            .sheet(isPresented: $showingAddSheet) {
                AddItemSheet(viewModel: addItemViewModel)
            }
            .sheet(isPresented: $showingPaywall) {
                PaywallView(
                    viewModel: PaywallViewModel(purchaseManager: savingsTracker.purchaseManager),
                    totalSaved: savingsTracker.totalSavings
                )
            }
            .sheet(item: $selectedItem) { item in
                detailSheet(for: item)
            }
            .sheet(isPresented: $showingGraph) {
                graphSheet
                    .onAppear {
                        // Lazy load yearly data when graph is opened
                        viewModel.loadYearlyData()
                    }
            }
            .sheet(item: $selectedStat) { statType in
                StatDetailView(type: statType, viewModel: viewModel)
            }
            .alert("Delete Item?", isPresented: $showingDeleteConfirmation, presenting: itemToDelete) { item in
                Button("Delete", role: .destructive) {
                    viewModel.delete(item)
                    showingDeleteConfirmation = false
                    itemToDelete = nil
                }
                Button("Cancel", role: .cancel) {
                    showingDeleteConfirmation = false
                    itemToDelete = nil
                }
            } message: { item in
                Text("Are you sure you want to delete \"\(item.title)\"?")
            }
            .onChange(of: showingAddSheet) { _, isPresented in
                if !isPresented {
                    viewModel.refresh()
                }
            }
        }
    }
}

private extension DashboardView {
    var backgroundGradient: some View {
        Color.surfaceFallback
    }

    var savingsHero: some View {
        Button {
            showingGraph = true
            HapticManager.shared.lightImpact()
        } label: {
            heroContent
        }
        .buttonStyle(.plain)
    }

    var heroContent: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            // Title
            Text("Willpower wins")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.white.opacity(0.9))

            // Large amount
            Text(CurrencyFormatter.string(from: viewModel.totalSaved))
                .font(.system(size: 52, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundColor(.white)
                .minimumScaleFactor(0.7)
                .lineLimit(1)

            // Subtitle
            Text("Saved this month")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.75))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.xl)
        .background(Color.successFallback)
        .cornerRadius(CornerRadius.card)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Willpower wins, saved this month: \(CurrencyFormatter.string(from: viewModel.totalSaved))")
    }

    var statsRow: some View {
        VStack(spacing: Spacing.cardSpacing) {
            HStack(spacing: Spacing.cardSpacing) {
                StatCard(
                    icon: "flame.fill",
                    value: "\(viewModel.itemCount)",
                    label: "",
                    color: .red,
                    onTap: { selectedStat = .temptationsResisted }
                )

                StatCard(
                    icon: "dollarsign.circle.fill",
                    value: CurrencyFormatter.string(from: viewModel.averageItemPrice),
                    label: "",
                    color: Color.successFallback,
                    onTap: { selectedStat = .averagePrice }
                )
            }

            HStack(spacing: Spacing.cardSpacing) {
                StatCard(
                    icon: "hand.raised.fill",
                    value: "\(viewModel.buyersRemorsePrevented)",
                    label: "",
                    color: .purple,
                    onTap: { selectedStat = .buyersRemorse }
                )

                StatCard(
                    icon: "leaf.fill",
                    value: viewModel.stats.formatCarbonFootprint(viewModel.carbonFootprintSaved),
                    label: "",
                    color: .green,
                    onTap: { selectedStat = .carbonFootprint }
                )
            }
        }
    }

    var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("RECENT ACTIVITY")
                .sectionHeaderStyle()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, Spacing.xs)

            if viewModel.items.isEmpty {
                emptyState
            } else {
                itemsList
            }
        }
    }

    var emptyState: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 48))
                .foregroundColor(Color.secondaryFallback.opacity(0.5))

            Text("No wins yet")
                .font(.headline)
                .foregroundColor(Color.primaryFallback)

            Text("Log your first resisted impulse below")
                .font(.subheadline)
                .foregroundColor(Color.secondaryFallback)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.xxl)
        .padding(.horizontal, Spacing.xl)
        .cardStyle()
    }

    var itemsList: some View {
        VStack(spacing: Spacing.xs) {
            ForEach(viewModel.items) { item in
                itemRow(item)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedItem = item
                        HapticManager.shared.lightImpact()
                    }
                    .contextMenu {
                        Button(role: .destructive) {
                            itemToDelete = item
                            showingDeleteConfirmation = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }
        }
    }

    func itemRow(_ item: WantedItemDisplay) -> some View {
        HStack(spacing: Spacing.sm) {
            // Icon
            Image(systemName: "wallet.pass.fill")
                .font(.title3)
                .foregroundColor(Color.accentFallback)
                .frame(width: 32, height: 32)
                .background(Color.accentSurfaceFallback)
                .clipShape(Circle())

            // Content
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(Color.primaryFallback)
                    .lineLimit(1)

                Text(item.createdAt.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundColor(Color.secondaryFallback)
            }

            Spacer()

            // Amount
            Text(CurrencyFormatter.string(from: item.priceWithTax))
                .font(.body)
                .fontWeight(.semibold)
                .monospacedDigit()
                .foregroundColor(Color.successFallback)
        }
        .padding(Spacing.md)
        .background(Color.surfaceElevatedFallback)
        .cornerRadius(CornerRadius.listRow)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.title), saved \(CurrencyFormatter.string(from: item.priceWithTax)), \(item.createdAt.formatted(date: .abbreviated, time: .omitted))")
    }

    var addButton: some View {
        Button {
            showingAddSheet = true
            HapticManager.shared.lightImpact()
        } label: {
            HStack {
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
                Text("Record Impulse")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(Color.accentFallback)
            .foregroundColor(Color.onAccentFallback)
            .cornerRadius(CornerRadius.button)
        }
        .padding(.horizontal, Spacing.sideGutter)
        .padding(.bottom, Spacing.md)
        .accessibilityLabel("Record impulse")
        .accessibilityHint("Opens form to record an impulse you resisted")
    }

    var undoBanner: some View {
        Group {
            if let pending = viewModel.pendingUndoItem {
                HStack {
                    Text("Deleted \(pending.title)")
                        .font(.subheadline)
                    Spacer()
                    Button("Undo") {
                        viewModel.undoDelete()
                        HapticManager.shared.lightImpact()
                    }
                    .fontWeight(.semibold)
                }
                .padding()
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.listRow))
                .padding(.horizontal, Spacing.sideGutter)
                .padding(.bottom, 80) // Above sticky button
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring, value: viewModel.pendingUndoItem != nil)
    }

    @ViewBuilder
    var warningCard: some View {
        if savingsTracker.showWarning && !savingsTracker.purchaseManager.hasPremiumAccess {
            HStack(alignment: .center, spacing: Spacing.sm) {
                // Icon
                Image(systemName: warningIcon)
                    .font(.title3)
                    .foregroundColor(warningColor)

                // Message
                Text(savingsTracker.warningMessage)
                    .font(.subheadline)
                    .foregroundColor(Color.primaryFallback)
                    .lineLimit(2)

                Spacer()

                // Unlock button
                Button {
                    showingPaywall = true
                    HapticManager.shared.lightImpact()
                } label: {
                    Text("Unlock")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, Spacing.md)
                        .padding(.vertical, Spacing.xs)
                        .background(warningColor)
                        .cornerRadius(CornerRadius.button)
                }
            }
            .padding(Spacing.md)
            .background(warningBackgroundColor)
            .cornerRadius(CornerRadius.card)
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.card)
                    .stroke(warningBorderColor, lineWidth: 1.5)
            )
            .transition(.move(edge: .top).combined(with: .opacity))
            .animation(.spring, value: savingsTracker.showWarning)
        }
    }

    private var warningIcon: String {
        if savingsTracker.isAtCap {
            return "exclamationmark.triangle.fill"
        } else if savingsTracker.totalSavings >= SavingsTracker.urgentThreshold {
            return "exclamationmark.circle.fill"
        } else {
            return "info.circle.fill"
        }
    }

    private var warningColor: Color {
        if savingsTracker.isAtCap {
            return .red
        } else if savingsTracker.totalSavings >= SavingsTracker.urgentThreshold {
            return .orange
        } else {
            return .blue
        }
    }

    private var warningBackgroundColor: Color {
        if savingsTracker.isAtCap {
            return Color.red.opacity(0.1)
        } else if savingsTracker.totalSavings >= SavingsTracker.urgentThreshold {
            return Color.orange.opacity(0.1)
        } else {
            return Color.blue.opacity(0.1)
        }
    }

    private var warningBorderColor: Color {
        if savingsTracker.isAtCap {
            return Color.red.opacity(0.3)
        } else if savingsTracker.totalSavings >= SavingsTracker.urgentThreshold {
            return Color.orange.opacity(0.3)
        } else {
            return Color.blue.opacity(0.3)
        }
    }

    func detailSheet(for item: WantedItemDisplay) -> some View {
        let detailViewModel = makeDetailViewModel(item)
        return NavigationStack {
            ItemDetailView(viewModel: detailViewModel,
                          imageProvider: { viewModel.image(for: $0) }) { deleted in
                viewModel.delete(deleted)
                selectedItem = nil
            } onUpdate: { updated in
                selectedItem = updated
                viewModel.refresh()
            }
        }
    }

    var graphSheet: some View {
        // Simple placeholder with current month data for now
        MonthlySavingsGraphView(
            monthlyData: [
                (Calendar.current.monthSymbols[Calendar.current.component(.month, from: Date()) - 1], viewModel.totalSaved)
            ],
            totalSaved: viewModel.totalSaved
        )
    }
}

#if DEBUG && canImport(PreviewsMacros)
#Preview {
    let container = PreviewSupport.container
    let dashboardVM = DashboardViewModel(itemRepository: container.itemRepository,
                                         monthRepository: container.monthRepository,
                                         settingsRepository: container.settingsRepository,
                                         imageStore: container.imageStore)
    return DashboardView(viewModel: dashboardVM,
                         addItemViewModel: AddItemViewModel(itemRepository: container.itemRepository, savingsTracker: container.savingsTracker),
                         savingsTracker: container.savingsTracker,
                         onOpenSettings: {},
                         makeDetailViewModel: { item in
                             ItemDetailViewModel(item: item,
                                                 itemRepository: container.itemRepository,
                                                 settingsRepository: container.settingsRepository)
                         })
}
#endif
