import SwiftUI
import UIKit

struct HistoryView: View {
    @StateObject private var viewModel: HistoryViewModel
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
            ZStack {
                // Match Dashboard background gradient
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
                .ignoresSafeArea()

                content
            }
            .navigationTitle("History")
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
                // Just dismiss - keep status as .redeemed
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
    var content: some View {
        Group {
            if viewModel.sections.isEmpty {
                ScrollView {
                    VStack(spacing: Spacing.xl) {
                        EmptyStateView(title: "No entries yet",
                                       message: "Every time you resist an impulse it will show up here, grouped by the day you logged it.")
                            .padding(.top, 80)
                    }
                    .padding(.horizontal, Spacing.sideGutter)
                }
            } else {
                List {
                    // Monthly Summaries Section
                    if !viewModel.summaries.isEmpty {
                        Section("Monthly History") {
                            ForEach(viewModel.summaries.prefix(6)) { summary in
                                Button {
                                    selectedMonthSummary = summary
                                } label: {
                                    monthSummaryRow(summary: summary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    ForEach(viewModel.sections) { section in
                        Section(header: sectionHeader(for: section)) {
                            ForEach(section.items) { item in
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
                        }
                        .textCase(nil)
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
        }
    }

    func sectionHeader(for section: HistoryViewModel.HistorySection) -> some View {
        HStack {
            Text(section.title)
                .font(.headline)
            Spacer()
            Text(CurrencyFormatter.string(from: section.subtotal))
                .font(.subheadline)
                .foregroundStyle(Color.secondary)
        }
    }

    @ViewBuilder
    func monthSummaryRow(summary: MonthSummaryDisplay) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(MonthFormatter.displayName(for: summary.monthKey))
                    .font(.headline)
                    .foregroundStyle(Color.appPrimary)

                HStack(spacing: 12) {
                    Label("\(summary.itemCount)", systemImage: "list.bullet")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if summary.closedAt != nil {
                        Label("Closed", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(Color.appSuccess)
                    } else {
                        Label("Active", systemImage: "clock")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(CurrencyFormatter.string(from: summary.totalSaved))
                    .font(.headline)
                    .foregroundStyle(Color.appSuccess)

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
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
                        .foregroundStyle(isWinner ? Color.orange : Color(red: 0.0, green: 0.5, blue: 0.33))
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
                .fill(isWinner ?
                    LinearGradient(colors: [Color.orange.opacity(0.1), Color.orange.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing) :
                    LinearGradient(colors: [Color(.systemBackground).opacity(0.95), Color(.systemBackground).opacity(0.95)], startPoint: .topLeading, endPoint: .bottomTrailing))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(isWinner ? Color.orange.opacity(0.3) : Color.black.opacity(0.05), lineWidth: isWinner ? 2 : 1)
        )
        .shadow(color: isWinner ? Color.orange.opacity(0.15) : Color.black.opacity(0.04), radius: isWinner ? 10 : 6, x: 0, y: 4)
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
