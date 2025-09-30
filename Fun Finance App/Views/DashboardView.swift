import SwiftUI

struct DashboardView: View {
    @StateObject private var viewModel: DashboardViewModel
    @StateObject private var addItemViewModel: AddItemViewModel
    @State private var showingAddSheet = false
    let onOpenSettings: () -> Void
    let onShowCloseout: () -> Void

    private let savingsGoal: Decimal = 500

    init(viewModel: DashboardViewModel,
         addItemViewModel: AddItemViewModel,
         onOpenSettings: @escaping () -> Void,
         onShowCloseout: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: viewModel)
        _addItemViewModel = StateObject(wrappedValue: addItemViewModel)
        self.onOpenSettings = onOpenSettings
        self.onShowCloseout = onShowCloseout
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    itemsGrid
                }
                .padding(.horizontal)
                .padding(.bottom, 80)
            }
            .navigationTitle("This Month")
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        showingAddSheet = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                    .accessibilityLabel("Add item")

                    Button(action: onOpenSettings) {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Settings")
                }
            }
            .overlay(undoBanner, alignment: .bottom)
            .sheet(isPresented: $showingAddSheet) {
                AddItemSheet(viewModel: addItemViewModel)
            }
            .onAppear { viewModel.refresh() }
        }
    }
}

private extension DashboardView {
    var header: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Saved so far")
                .font(.headline)
            HStack(alignment: .center, spacing: 24) {
                ProgressRingView(progress: progressValue, label: CurrencyFormatter.string(from: viewModel.totalSaved))
                    .frame(width: 120, height: 120)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Items logged: \(viewModel.itemCount)")
                        .font(.title2)
                        .bold()
                    Button("Review last month", action: onShowCloseout)
                        .font(.subheadline)
                }
                Spacer()
            }
        }
    }

    var itemsGrid: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Temptations")
                .font(.headline)
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
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    ForEach(viewModel.items) { item in
                        ItemCardView(item: item, image: viewModel.image(for: item))
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

    var progressValue: Double {
        guard savingsGoal > 0 else { return 0 }
        let ratio = (viewModel.totalSaved as NSDecimalNumber).doubleValue / (savingsGoal as NSDecimalNumber).doubleValue
        return min(max(ratio, 0), 1)
    }
}

#if DEBUG && canImport(PreviewsMacros)
#Preview {
    let container = PreviewSupport.container
    return DashboardView(viewModel: DashboardViewModel(itemRepository: container.itemRepository, imageStore: container.imageStore),
                         addItemViewModel: AddItemViewModel(itemRepository: container.itemRepository),
                         onOpenSettings: {},
                         onShowCloseout: {})
}
#endif
