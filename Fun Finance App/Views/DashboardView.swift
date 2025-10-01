import SwiftUI

struct DashboardView: View {
    @StateObject private var viewModel: DashboardViewModel
    @StateObject private var addItemViewModel: AddItemViewModel
    @State private var showingAddSheet = false
    @State private var selectedItem: WantedItemDisplay?
    let onOpenSettings: () -> Void
    let makeDetailViewModel: (WantedItemDisplay) -> ItemDetailViewModel

    init(viewModel: DashboardViewModel,
         addItemViewModel: AddItemViewModel,
         onOpenSettings: @escaping () -> Void,
         makeDetailViewModel: @escaping (WantedItemDisplay) -> ItemDetailViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
        _addItemViewModel = StateObject(wrappedValue: addItemViewModel)
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
            .sheet(item: $selectedItem) { item in
                detailSheet(for: item)
            }
            .onChange(of: showingAddSheet) { _, isPresented in
                if !isPresented {
                    viewModel.refresh()
                    HapticManager.shared.success()
                }
            }
            .onAppear { viewModel.refresh() }
        }
    }
}

private extension DashboardView {
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

    var savingsHero: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            // Title with icon
            HStack(spacing: 8) {
                Image(systemName: "checkmark.shield.fill")
                    .font(.title3)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.successFallback, Color.successFallback.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Text("Willpower wins")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white.opacity(0.9))
            }

            // Large amount
            Text(CurrencyFormatter.string(from: viewModel.totalSaved))
                .font(.system(size: 52, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundColor(.white)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
                .shadow(color: .black.opacity(0.1), radius: 2, y: 1)

            // Subtitle
            Text("Saved this month by saying no to impulse buys")
                .font(.footnote)
                .foregroundColor(.white.opacity(0.85))
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.xl)
        .background(
            LinearGradient(
                colors: [
                    Color.successFallback,
                    Color.successFallback.opacity(0.85)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(CornerRadius.card)
        .shadow(
            color: Color.successFallback.opacity(0.3),
            radius: 16,
            y: 8
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Willpower wins: \(CurrencyFormatter.string(from: viewModel.totalSaved)) saved this month")
    }

    var statsRow: some View {
        HStack(spacing: Spacing.cardSpacing) {
            statCard(
                icon: "flame.fill",
                title: "Impulses resisted",
                value: "\(viewModel.itemCount)",
                subtitle: "this month",
                color: Color(red: 1.0, green: 0.3, blue: 0.3)
            )

            statCard(
                icon: "dollarsign.circle.fill",
                title: "Average avoided spend",
                value: CurrencyFormatter.string(from: viewModel.averageItemPrice),
                subtitle: "per purchase",
                color: Color.successFallback
            )
        }
    }

    func statCard(icon: String, title: String, value: String, subtitle: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(color)
                Spacer()
            }

            Spacer()

            Text(value)
                .font(.system(.title2, design: .rounded))
                .fontWeight(.bold)
                .monospacedDigit()
                .foregroundColor(Color.primaryFallback)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(subtitle)
                .font(.caption2)
                .foregroundColor(Color.secondaryFallback)
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 120)
        .cardStyle()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value), \(subtitle)")
    }

    var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("RECENT ACTIVITY")
                .sectionHeaderStyle()

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

            Text("Log your first resisted purchase below")
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
                .background(Color.accentFallback.opacity(0.1))
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
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                viewModel.delete(item)
                HapticManager.shared.mediumImpact()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
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
                Text("Log a Win")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(Color.accentFallback)
            .foregroundColor(.white)
            .cornerRadius(CornerRadius.button)
            .shadow(
                color: Color.black.opacity(0.15),
                radius: 12,
                y: 4
            )
        }
        .padding(.horizontal, Spacing.sideGutter)
        .padding(.bottom, Spacing.md)
        .accessibilityLabel("Log a win")
        .accessibilityHint("Opens form to log a resisted purchase")
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

    func detailSheet(for item: WantedItemDisplay) -> some View {
        let detailViewModel = makeDetailViewModel(item)
        return ItemDetailView(viewModel: detailViewModel,
                              imageProvider: { viewModel.image(for: $0) }) { deleted in
            viewModel.delete(deleted)
            selectedItem = nil
        } onUpdate: { updated in
            selectedItem = updated
            viewModel.refresh()
        }
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
                         addItemViewModel: AddItemViewModel(itemRepository: container.itemRepository),
                         onOpenSettings: {},
                         makeDetailViewModel: { item in
                             ItemDetailViewModel(item: item,
                                                 itemRepository: container.itemRepository,
                                                 settingsRepository: container.settingsRepository)
                         })
}
#endif
