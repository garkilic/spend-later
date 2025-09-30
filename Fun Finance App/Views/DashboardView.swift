import SwiftUI

struct DashboardView: View {
    @StateObject private var viewModel: DashboardViewModel
    @StateObject private var addItemViewModel: AddItemViewModel
    @State private var showingAddSheet = false
    let onOpenSettings: () -> Void
    let onShowCloseout: () -> Void

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
                    Button {
                        showingAddSheet = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(Color.white, Color.accentColor)
                    }
                    .accessibilityLabel("Add item")

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
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 16)], spacing: 16) {
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

    var backgroundGradient: LinearGradient {
        LinearGradient(colors: [Color(.systemBackground), Color.accentColor.opacity(0.12)], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    var totalCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Total saved")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.8))

            Text(CurrencyFormatter.string(from: viewModel.totalSaved))
                .font(.system(size: 46, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.5)

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
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(colors: [Color.accentColor, Color.purple.opacity(0.85)], startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: Color.accentColor.opacity(0.3), radius: 12, x: 0, y: 10)
    }

    var statsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                statPill(title: "Items logged", value: "\(viewModel.itemCount)", icon: "square.stack.3d.up")
                statPill(title: "Undo available", value: viewModel.pendingUndoItem == nil ? "No" : "Yes", icon: "arrow.uturn.backward")
            }
            .padding(.horizontal, 4)
        }
    }

    func statPill(title: String, value: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .padding(10)
                .background(Color.accentColor.opacity(0.15))
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
        .background(Color(.systemBackground).opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 4)
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
