import SwiftUI
import UIKit

struct MonthDetailView: View {
    let summary: MonthSummaryDisplay
    @ObservedObject var viewModel: HistoryViewModel
    @State private var filter: Filter = .all

    enum Filter: String, CaseIterable, Identifiable {
        case all = "All"
        case redeemed = "Redeemed"
        case skipped = "Not redeemed"

        var id: String { rawValue }

        var status: ItemStatus? {
            switch self {
            case .all: return nil
            case .redeemed: return .redeemed
            case .skipped: return .skipped
            }
        }
    }

    var body: some View {
        List {
            Section("Summary") {
                HStack {
                    Text("Total saved")
                    Spacer()
                    Text(CurrencyFormatter.string(from: summary.totalSaved))
                }
                HStack {
                    Text("Items")
                    Spacer()
                    Text("\(summary.itemCount)")
                }
                if let winner = summary.winnerItemId {
                    HStack {
                        Text("Winner")
                        Spacer()
                        Text(winner.uuidString.prefix(8) + "…")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
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
                            Text(CurrencyFormatter.string(from: item.price))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
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
    }
}

#if DEBUG && canImport(PreviewsMacros)
#Preview {
    let container = PreviewSupport.container
    let summary = MonthSummaryDisplay(id: UUID(), monthKey: "2025,08", totalSaved: 200, itemCount: 3, winnerItemId: nil, closedAt: nil)
    return NavigationStack {
        MonthDetailView(summary: summary, viewModel: HistoryViewModel(monthRepository: container.monthRepository, imageStore: container.imageStore))
    }
}
#endif
