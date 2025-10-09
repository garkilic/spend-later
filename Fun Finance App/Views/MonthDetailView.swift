import SwiftUI
import UIKit

struct MonthDetailView: View {
    let summary: MonthSummaryDisplay
    @ObservedObject var viewModel: HistoryViewModel
    @State private var filter: Filter = .all
    @State private var showingComparison = false

    enum Filter: String, CaseIterable, Identifiable {
        case all = "All"
        case saved = "Saved"
        case bought = "Bought"
        case won = "Won"

        var id: String { rawValue }

        var status: ItemStatus? {
            switch self {
            case .all: return nil
            case .saved: return .saved
            case .bought: return .bought
            case .won: return .won
            }
        }
    }

    private var allItems: [WantedItemDisplay] {
        viewModel.items(for: summary.id, filter: nil)
    }

    private var averageItemPrice: Decimal {
        guard !allItems.isEmpty else { return .zero }
        let total = allItems.reduce(Decimal.zero) { $0 + $1.priceWithTax }
        return total / Decimal(allItems.count)
    }

    private var winnerItem: WantedItemDisplay? {
        guard let winnerId = summary.winnerItemId else { return nil }
        return allItems.first(where: { $0.id == winnerId })
    }

    var body: some View {
        List {
            Section {
                VStack(spacing: Spacing.md) {
                    // Primary stats
                    HStack(spacing: Spacing.md) {
                        statCard(title: "Total Saved", value: CurrencyFormatter.string(from: summary.totalSaved), color: .appSuccess)
                        statCard(title: "Items Resisted", value: "\(summary.itemCount)", color: .appAccent)
                    }

                    HStack(spacing: Spacing.md) {
                        statCard(title: "Avg. Item Price", value: CurrencyFormatter.string(from: averageItemPrice), color: .appSecondary)
                        if let closedAt = summary.closedAt {
                            statCard(title: "Closed", value: closedAt.formatted(date: .abbreviated, time: .omitted), color: .appSecondary)
                        } else {
                            statCard(title: "Status", value: "In Progress", color: .orange)
                        }
                    }
                }
                .padding(.vertical, Spacing.sm)
            }

            // Winner section
            if let winner = winnerItem {
                Section("Month Winner") {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(winner.title)
                                .font(.headline)
                            Text(CurrencyFormatter.string(from: winner.priceWithTax))
                                .font(.subheadline)
                                .foregroundStyle(Color.appSuccess)
                            if !winner.tags.isEmpty {
                                TagListView(tags: winner.tags)
                            }
                        }
                        Spacer()
                        if let image = viewModel.image(for: winner) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 60, height: 60)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            Section("Filter") {
                Picker("Filter", selection: $filter) {
                    ForEach(Filter.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("Items") {
                let items = viewModel.items(for: summary.id, filter: filter.status)
                ForEach(items) { item in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(item.title)
                                .font(.headline)
                            Text(CurrencyFormatter.string(from: item.priceWithTax))
                                .font(.subheadline)
                                .foregroundStyle(Color.accentColor)
                            if item.priceWithTax != item.price {
                                Text("Base: \(CurrencyFormatter.string(from: item.price))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if !item.tags.isEmpty {
                                TagListView(tags: item.tags)
                            }
                        }
                        Spacer()
                        if let image = viewModel.image(for: item) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 60, height: 60)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
            }
        }
        .navigationTitle(MonthFormatter.displayName(for: summary.monthKey))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingComparison = true
                } label: {
                    Label("Compare", systemImage: "chart.bar.xaxis")
                }
            }
        }
        .sheet(isPresented: $showingComparison) {
            MonthComparisonView(currentMonth: summary, viewModel: viewModel)
        }
    }

    @ViewBuilder
    private func statCard(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.md)
        .background(Color.appSurfaceElevated)
        .cornerRadius(CornerRadius.card)
    }
}

#if DEBUG && canImport(PreviewsMacros)
#Preview {
    let container = PreviewSupport.container
    let summary = MonthSummaryDisplay(id: UUID(), monthKey: "2025,08", totalSaved: 200, itemCount: 3, winnerItemId: nil, closedAt: nil)
    return NavigationStack {
        MonthDetailView(summary: summary,
                        viewModel: HistoryViewModel(monthRepository: container.monthRepository,
                                                    itemRepository: container.itemRepository,
                                                    imageStore: container.imageStore,
                                                    settingsRepository: container.settingsRepository))
    }
}
#endif
