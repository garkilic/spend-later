import SwiftUI

struct DashboardView: View {
    @StateObject private var viewModel: DashboardViewModel
    @StateObject private var addItemViewModel: AddItemViewModel
    @State private var showingAddSheet = false
    @State private var selectedItem: WantedItemDisplay?
    @State private var showingSummary = false
    @State private var showingReview = false
    let onOpenSettings: () -> Void
    let onShowCloseout: () -> Void
    let makeDetailViewModel: (WantedItemDisplay) -> ItemDetailViewModel
    let makeReviewViewModel: () -> ReviewItemsViewModel

    init(viewModel: DashboardViewModel,
         addItemViewModel: AddItemViewModel,
         onOpenSettings: @escaping () -> Void,
         onShowCloseout: @escaping () -> Void,
         makeDetailViewModel: @escaping (WantedItemDisplay) -> ItemDetailViewModel,
         makeReviewViewModel: @escaping () -> ReviewItemsViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
        _addItemViewModel = StateObject(wrappedValue: addItemViewModel)
        self.onOpenSettings = onOpenSettings
        self.onShowCloseout = onShowCloseout
        self.makeDetailViewModel = makeDetailViewModel
        self.makeReviewViewModel = makeReviewViewModel
    }

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundGradient.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        header
                        itemsGrid
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 28)
                }
            }
            .navigationTitle("This Month")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button(action: onOpenSettings) {
                        Image(systemName: "gearshape.fill")
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
            .sheet(isPresented: $showingSummary) {
                YearlySummaryView(viewModel: viewModel)
            }
            .sheet(isPresented: $showingReview) {
                ReviewItemsView(viewModel: makeReviewViewModel())
            }
            .onChange(of: showingAddSheet) { isPresented in
                if !isPresented {
                    viewModel.refresh()
                }
            }
            .onAppear { viewModel.refresh() }
        }
    }
}

private extension DashboardView {
    var header: some View {
        VStack(alignment: .leading, spacing: 20) {
            totalCard
            statsRow
        }
    }

    var itemsGrid: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Temptations")
                .font(.headline)
                .foregroundStyle(Color.primary.opacity(0.85))
            if viewModel.items.isEmpty {
                VStack(spacing: 16) {
                    EmptyStateView(title: "Nothing logged yet", message: "Log something you skipped and note how much you saved. A photo is optional but keeps the memory.")
                        .frame(maxWidth: .infinity)
                    Button {
                        showingAddSheet = true
                    } label: {
                        Label("Start Tracking", systemImage: "plus.circle.fill")
                            .font(.headline)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                LazyVStack(alignment: .leading, spacing: 16) {
                    ForEach(viewModel.items) { item in
                        ItemCardView(item: item, image: viewModel.image(for: item))
                            .frame(maxWidth: .infinity)
                            .contentShape(Rectangle())
                            .onTapGesture { selectedItem = item }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    viewModel.delete(item)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                }
            }
        }
    }

    var undoBanner: some View {
        Group {
            if let pending = viewModel.pendingUndoItem {
                HStack {
                    Text("Deleted \(pending.title)")
                    Spacer()
                    Button("Undo") { viewModel.undoDelete() }
                }
                .padding()
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding()
                .transition(.move(edge: .bottom))
            }
        }
    }

    var backgroundGradient: LinearGradient {
        LinearGradient(colors: [Color(.systemGroupedBackground), Color(red: 0.9, green: 0.98, blue: 0.93)], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    var totalCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Money banked this month")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.85))

            Text(CurrencyFormatter.string(from: viewModel.totalSaved))
                .font(.system(size: 46, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.5)

            HStack(spacing: 12) {
                if viewModel.canReviewLastMonth {
                    Button {
                        onShowCloseout()
                    } label: {
                        Label("Review last month", systemImage: "sparkles")
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color.white.opacity(0.18))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.white)
                }

                Spacer()

                Label("Past year", systemImage: "chart.line.uptrend.xyaxis")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.85))
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(colors: [Color(red: 0.02, green: 0.65, blue: 0.41), Color(red: 0.0, green: 0.5, blue: 0.33)], startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
        .shadow(color: Color(red: 0.0, green: 0.5, blue: 0.33).opacity(0.35), radius: 14, x: 0, y: 10)
        .contentShape(Rectangle())
        .onTapGesture { showingSummary = true }
    }

    var statsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                statPill(title: "Items logged", value: "\(viewModel.itemCount)", icon: "square.stack.3d.up")
                Button {
                    showingReview = true
                } label: {
                    statPill(title: "Needs review", value: "\(viewModel.reviewCount)", icon: "hand.raised")
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 4)
        }
    }

    func statPill(title: String, value: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color(red: 0.0, green: 0.6, blue: 0.35))
                .padding(10)
                .background(Color(red: 0.0, green: 0.6, blue: 0.35).opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.headline)
            }
            Spacer()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(Color(.systemBackground).opacity(0.92))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 4)
    }
}

private extension DashboardView {
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
                         onShowCloseout: {},
                         makeDetailViewModel: { item in
                             ItemDetailViewModel(item: item,
                                                 itemRepository: container.itemRepository,
                                                 settingsRepository: container.settingsRepository)
                         },
                         makeReviewViewModel: {
                             ReviewItemsViewModel(itemRepository: container.itemRepository,
                                                  imageStore: container.imageStore,
                                                  settingsRepository: container.settingsRepository)
                         })
}
#endif
