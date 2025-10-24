import SwiftUI
import UIKit

struct HistoryView: View {
    @StateObject private var viewModel: HistoryViewModel
    @State private var selectedItem: WantedItemDisplay?
    private let timeFormatter: DateFormatter
    private let makeDetailViewModel: (WantedItemDisplay) -> ItemDetailViewModel
    private let onItemDeleted: (WantedItemDisplay) -> Void
    private let onItemUpdated: (WantedItemDisplay) -> Void

    init(viewModel: HistoryViewModel,
         makeDetailViewModel: @escaping (WantedItemDisplay) -> ItemDetailViewModel,
         onItemDeleted: @escaping (WantedItemDisplay) -> Void,
         onItemUpdated: @escaping (WantedItemDisplay) -> Void = { _ in }) {
        _viewModel = StateObject(wrappedValue: viewModel)
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        self.timeFormatter = formatter
        self.makeDetailViewModel = makeDetailViewModel
        self.onItemDeleted = onItemDeleted
        self.onItemUpdated = onItemUpdated
    }

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundGradient

                if viewModel.monthSections.isEmpty {
                    ScrollView {
                        VStack(spacing: Spacing.xl) {
                            EmptyStateView(title: "No history yet",
                                           message: "Every impulse you resist will appear here, organized by month.")
                                .padding(.top, 80)
                        }
                        .padding(.horizontal, Spacing.sideGutter)
                    }
                } else {
                    List {
                        ForEach(viewModel.monthSections) { monthSection in
                            Section {
                                ForEach(monthSection.statusSections) { statusSection in
                                    // Status subsection header
                                    statusSectionHeader(statusSection)
                                        .listRowInsets(EdgeInsets(top: 12, leading: 0, bottom: 4, trailing: 0))
                                        .listRowBackground(Color.clear)

                                    // Items in this status
                                    ForEach(statusSection.items) { item in
                                        itemRow(item)
                                            .id("\(item.id)-\(item.status.rawValue)")
                                    }
                                }
                            } header: {
                                monthSectionHeader(monthSection)
                            }
                            .textCase(nil)
                        }
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                    .id(viewModel.monthSections.flatMap { $0.statusSections.flatMap { $0.items.map { $0.id } } }.hashValue)
                }
            }
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.large)
        }
        .onAppear { viewModel.refresh() }
        .sheet(item: $selectedItem) { item in
            detailSheet(for: item)
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

    func monthSectionHeader(_ monthSection: HistoryViewModel.MonthSection) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(monthSection.monthName)
                    .font(.title3)
                    .fontWeight(.bold)
                Spacer()
                Text(CurrencyFormatter.string(from: monthSection.netSaved))
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.successFallback)
            }

            if monthSection.totalBought > 0 {
                HStack {
                    Text("Saved: \(CurrencyFormatter.string(from: monthSection.totalSaved))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("•")
                        .foregroundStyle(.secondary)
                    Text("Bought: \(CurrencyFormatter.string(from: monthSection.totalBought))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    func statusSectionHeader(_ statusSection: HistoryViewModel.StatusSection) -> some View {
        HStack {
            Text(statusSection.title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(colorForStatus(statusSection.status))
            Spacer()
            Text(CurrencyFormatter.string(from: statusSection.subtotal))
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(colorForStatus(statusSection.status))
        }
        .padding(.horizontal, 16)
    }

    func colorForStatus(_ status: ItemStatus) -> Color {
        switch status {
        case .saved:
            return Color.blue
        case .bought:
            return Color.red
        case .won:
            return Color.orange
        }
    }

    func itemRow(_ item: WantedItemDisplay) -> some View {
        Button {
            selectedItem = item
        } label: {
            HistoryItemRow(item: item,
                           image: viewModel.image(for: item),
                           timeString: timeFormatter.string(from: item.createdAt),
                           isWinner: item.status == .won)
        }
        .buttonStyle(.plain)
        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
        .listRowBackground(Color.clear)
        .id(item.id)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            if item.status == .saved {
                // Swipe to mark as bought
                Button {
                    HapticManager.shared.lightImpact()
                    viewModel.markAsBought(item)
                    onItemUpdated(item)
                } label: {
                    Label("Bought", systemImage: "checkmark.circle.fill")
                }
                .tint(.green)
            } else if item.status == .bought {
                // Swipe to undo (mark as saved)
                Button {
                    HapticManager.shared.lightImpact()
                    viewModel.markAsSaved(item)
                    onItemUpdated(item)
                } label: {
                    Label("Undo", systemImage: "arrow.uturn.backward")
                }
                .tint(.blue)
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            if item.status != .won {
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
                        .foregroundStyle(isWinner ? Color.orange : (item.status == .bought ? Color.red : Color.blue))
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
