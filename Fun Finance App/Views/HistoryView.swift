import SwiftUI

struct HistoryView: View {
    @StateObject private var viewModel: HistoryViewModel
    let onSelectSummary: (MonthSummaryDisplay) -> Void

    init(viewModel: HistoryViewModel, onSelectSummary: @escaping (MonthSummaryDisplay) -> Void) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.onSelectSummary = onSelectSummary
    }

    var body: some View {
        NavigationStack {
            List(viewModel.summaries) { summary in
                Button(action: { onSelectSummary(summary) }) {
                    HStack {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(MonthFormatter.displayName(for: summary.monthKey))
                                .font(.headline)
                            Text("Saved: \(CurrencyFormatter.string(from: summary.totalSaved))")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if summary.winnerItemId != nil {
                            Label("Winner", systemImage: "star.fill")
                                .foregroundStyle(.yellow)
                                .labelStyle(.iconOnly)
                                .accessibilityLabel("Winner selected")
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            .listStyle(.insetGrouped)
            .navigationTitle("History")
            .onAppear { viewModel.refresh() }
        }
    }
}

#if DEBUG && canImport(PreviewsMacros)
#Preview {
    let container = PreviewSupport.container
    return HistoryView(viewModel: HistoryViewModel(monthRepository: container.monthRepository, imageStore: container.imageStore)) { _ in }
}
#endif
