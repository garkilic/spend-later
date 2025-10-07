import SwiftUI
import UIKit

struct HistoryView: View {
    enum HistoryTab: String, CaseIterable, Identifiable {
        case months = "By Month"
        case allItems = "All Items"

        var id: String { rawValue }
    }

    @StateObject private var viewModel: HistoryViewModel
    @State private var selectedTab: HistoryTab = .months
    @State private var selectedItem: WantedItemDisplay?
    @State private var showingPurchaseConfirmation = false
    @State private var showingNotBuyDialog = false
    @State private var itemForConfirmation: WantedItemDisplay?
    @State private var selectedMonthSummary: MonthSummaryDisplay?
    private let timeFormatter: DateFormatter
    private let makeDetailViewModel: (WantedItemDisplay) -> ItemDetailViewModel
    private let onItemDeleted: (WantedItemDisplay) -> Void

    init(viewModel: HistoryViewModel,
         makeDetailViewModel: @escaping (WantedItemDisplay) -> ItemDetailViewModel,
         onItemDeleted: @escaping (WantedItemDisplay) -> Void) {
        _viewModel = StateObject(wrappedValue: viewModel)
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        self.timeFormatter = formatter
        self.makeDetailViewModel = makeDetailViewModel
        self.onItemDeleted = onItemDeleted
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Custom tab picker
                tabPicker

                ZStack {
                    backgroundGradient

                    // Tab content
                    TabView(selection: $selectedTab) {
                        monthsTabContent
                            .tag(HistoryTab.months)

                        allItemsTabContent
                            .tag(HistoryTab.allItems)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                }
            }
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.large)
        }
        .onAppear { viewModel.refresh() }
        .sheet(item: $selectedItem) { item in
            detailSheet(for: item)
        }
        .sheet(item: $selectedMonthSummary) { summary in
            NavigationStack {
                MonthDetailView(summary: summary, viewModel: viewModel)
            }
        }
        .alert("Not buying this item?", isPresented: $showingNotBuyDialog, presenting: itemForConfirmation) { item in
            Button("Keep Saved") {
                showingNotBuyDialog = false
                itemForConfirmation = nil
            }

            Button("Delete", role: .destructive) {
                viewModel.delete(item)
                onItemDeleted(item)
                showingNotBuyDialog = false
                itemForConfirmation = nil
            }

            Button("Cancel", role: .cancel) {
                showingNotBuyDialog = false
                itemForConfirmation = nil
            }
        } message: { item in
            Text("Choose whether to keep this item saved for later or delete it")
        }
    }
}

private extension HistoryView {
    var backgroundGradient: some View {
        LinearGradient(
            colors: [Color.surfaceFallback, Color.surfaceElevatedFallback],
            startPoint: .top,
            endPoint: .bottom
        )
        .opacity(0.06)
        .background(Color.surfaceFallback)
        .ignoresSafeArea()
    }

    var tabPicker: some View {
        HStack(spacing: 0) {
            ForEach(HistoryTab.allCases) { tab in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedTab = tab
                    }
                    HapticManager.shared.lightImpact()
                } label: {
                    VStack(spacing: 8) {
                        Text(tab.rawValue)
                            .font(.subheadline)
                            .fontWeight(selectedTab == tab ? .semibold : .regular)
                            .foregroundColor(selectedTab == tab ? Color.accentColor : Color.secondary)

                        Rectangle()
                            .fill(selectedTab == tab ? Color.accentColor : Color.clear)
                            .frame(height: 2)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.sm)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .background(Color.surfaceElevatedFallback)
    }

    var monthsTabContent: some View {
        Group {
            if viewModel.summaries.isEmpty {
                ScrollView {
                    VStack(spacing: Spacing.xl) {
                        EmptyStateView(title: "No monthly history yet",
                                       message: "Complete your first month to see monthly summaries here.")
                            .padding(.top, 80)
                    }
                    .padding(.horizontal, Spacing.sideGutter)
                }
            } else {
                List {
                    ForEach(viewModel.summaries) { summary in
                        Button {
                            selectedMonthSummary = summary
                        } label: {
                            monthSummaryRow(summary: summary)
                        }
                        .buttonStyle(.plain)
                        .listRowInsets(EdgeInsets(top: 8, leading: Spacing.sideGutter, bottom: 8, trailing: Spacing.sideGutter))
                        .listRowBackground(Color.clear)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
    }

    var allItemsTabContent: some View {
        Group {
            if viewModel.sections.isEmpty {
                ScrollView {
                    VStack(spacing: Spacing.xl) {
                        EmptyStateView(title: "No items yet",
                                       message: "Every impulse you resist will appear here, organized by date.")
                            .padding(.top, 80)
                    }
                    .padding(.horizontal, Spacing.sideGutter)
                }
            } else {
                List {
                    ForEach(viewModel.sections) { section in
                        Section(header: sectionHeader(for: section)) {
                            ForEach(section.items) { item in
                                itemRow(item)
                            }
                        }
                        .textCase(nil)
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
        }
    }

    func itemRow(_ item: WantedItemDisplay) -> some View {
        Button {
            selectedItem = item
        } label: {
            HistoryItemRow(item: item,
                           image: viewModel.image(for: item),
                           timeString: timeFormatter.string(from: item.createdAt),
                           isWinner: viewModel.winnerItemIds.contains(item.id),
                           needsConfirmation: item.status == .redeemed)
        }
        .buttonStyle(.plain)
        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
        .listRowBackground(Color.clear)
        .id(item.id)
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            if item.status == .redeemed {
                Button {
                    viewModel.confirmPurchase(item, purchased: true)
                } label: {
                    Label("Bought", systemImage: "checkmark")
                }
                .tint(.green)
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if item.status == .redeemed {
                Button {
                    itemForConfirmation = item
                    showingNotBuyDialog = true
                } label: {
                    Label("Not Buying", systemImage: "xmark")
                }
                .tint(.orange)
            } else if item.status != .skipped {
                Button(role: .destructive) {
                    viewModel.delete(item)
                    onItemDeleted(item)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }

    func sectionHeader(for section: HistoryViewModel.HistorySection) -> some View {
        HStack {
            Text(section.title)
                .font(.subheadline)
                .fontWeight(.semibold)
            Spacer()
            Text(CurrencyFormatter.string(from: section.subtotal))
                .font(.subheadline)
                .foregroundStyle(Color.successFallback)
        }
    }

    @ViewBuilder
    func monthSummaryRow(summary: MonthSummaryDisplay) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(MonthFormatter.displayName(for: summary.monthKey))
                    .font(.body)
                    .fontWeight(.medium)

                Text("\(summary.itemCount) items")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(CurrencyFormatter.string(from: summary.totalSaved))
                .font(.body)
                .fontWeight(.semibold)
                .foregroundStyle(Color.successFallback)
        }
        .padding(.vertical, 12)
    }
}

private extension HistoryView {
    func detailSheet(for item: WantedItemDisplay) -> some View {
        let detailViewModel = makeDetailViewModel(item)
        return NavigationStack {
            ItemDetailView(viewModel: detailViewModel,
                          imageProvider: { viewModel.image(for: $0) }) { deleted in
                viewModel.delete(deleted)
                onItemDeleted(deleted)
                selectedItem = nil
            } onUpdate: { updated in
                viewModel.refresh()
                selectedItem = nil
            }
        }
    }
}

private struct HistoryItemRow: View {
    let item: WantedItemDisplay
    let image: UIImage?
    let timeString: String
    let isWinner: Bool
    let needsConfirmation: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            thumbnail

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(item.title)
                        .font(.headline)
                    Spacer()
                    Text(CurrencyFormatter.string(from: item.priceWithTax))
                        .font(.headline)
                        .foregroundStyle(isWinner ? Color.orange : Color.successFallback)
                }
                if item.priceWithTax != item.price {
                    Text("Base: \(CurrencyFormatter.string(from: item.price))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text(timeString)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if isWinner {
                        Spacer()
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .font(.caption)
                            Text("Winner")
                                .font(.caption.weight(.semibold))
                        }
                        .foregroundStyle(Color.orange)
                    }
                }
                if needsConfirmation {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(.caption)
                        Text("Swipe to Confirm Purchase")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundStyle(Color.blue)
                    .padding(.top, 4)
                }
                if let notes = item.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                if !item.tags.isEmpty {
                    TagListView(tags: item.tags)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(isWinner ? Color.orange.opacity(0.08) : Color(.systemBackground).opacity(0.95))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(isWinner ? Color.orange.opacity(0.3) : Color.separatorFallback, lineWidth: isWinner ? 2 : 1)
        )
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let image, !item.imagePath.isEmpty {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 68, height: 68)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.accentColor.opacity(0.12))
                .frame(width: 68, height: 68)
                .overlay(
                    Image(systemName: "sparkles.rectangle.stack")
                        .font(.title3)
                        .foregroundStyle(Color.accentColor)
                )
        }
    }
}

#if DEBUG && canImport(PreviewsMacros)
#Preview {
    let container = PreviewSupport.container
    let vm = HistoryViewModel(monthRepository: container.monthRepository,
                              itemRepository: container.itemRepository,
                              imageStore: container.imageStore,
                              settingsRepository: container.settingsRepository)
    return HistoryView(viewModel: vm,
                       makeDetailViewModel: { item in
                           ItemDetailViewModel(item: item,
                                               itemRepository: container.itemRepository,
                                               settingsRepository: container.settingsRepository)
                       },
                       onItemDeleted: { _ in })
}
#endif
