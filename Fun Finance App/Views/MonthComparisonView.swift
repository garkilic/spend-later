import SwiftUI
import Charts

struct MonthComparisonView: View {
    @Environment(\.dismiss) private var dismiss
    let currentMonth: MonthSummaryDisplay
    @ObservedObject var viewModel: HistoryViewModel
    @State private var selectedComparison: MonthSummaryDisplay?

    private var currentItems: [WantedItemDisplay] {
        viewModel.items(for: currentMonth.id, filter: nil)
    }

    private var currentAverage: Decimal {
        guard !currentItems.isEmpty else { return .zero }
        return currentItems.reduce(Decimal.zero) { $0 + $1.priceWithTax } / Decimal(currentItems.count)
    }

    private var comparisonItems: [WantedItemDisplay] {
        guard let comparison = selectedComparison else { return [] }
        return viewModel.items(for: comparison.id, filter: nil)
    }

    private var comparisonAverage: Decimal {
        guard !comparisonItems.isEmpty else { return .zero }
        return comparisonItems.reduce(Decimal.zero) { $0 + $1.priceWithTax } / Decimal(comparisonItems.count)
    }

    private var availableMonths: [MonthSummaryDisplay] {
        // Extract month summaries from monthSections
        viewModel.monthSections.compactMap { monthSection in
            // Calculate total for this month
            let totalSaved = monthSection.statusSections.first { $0.status == .saved }?.subtotal ?? .zero
            let totalBought = monthSection.statusSections.first { $0.status == .bought }?.subtotal ?? .zero
            let wonItem = monthSection.statusSections.first { $0.status == .won }?.items.first

            // Count all items in this month
            let itemCount = monthSection.statusSections.reduce(0) { $0 + $1.items.count }

            return MonthSummaryDisplay(
                id: UUID(), // We'll use monthKey as unique identifier
                monthKey: monthSection.monthKey,
                totalSaved: totalSaved - totalBought,
                itemCount: itemCount,
                winnerItemId: wonItem?.id,
                closedAt: wonItem != nil ? Date() : nil
            )
        }.filter { $0.monthKey != currentMonth.monthKey }
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Select Month to Compare") {
                    Picker("Compare with", selection: $selectedComparison) {
                        Text("Select a month...").tag(nil as MonthSummaryDisplay?)
                        ForEach(availableMonths) { month in
                            Text(MonthFormatter.displayName(for: month.monthKey))
                                .tag(month as MonthSummaryDisplay?)
                        }
                    }
                }

                if let comparison = selectedComparison {
                    Section("Total Saved Comparison") {
                        comparisonChart
                    }

                    Section("Side-by-Side Stats") {
                        statsComparison(comparison: comparison)
                    }

                    Section("Performance Metrics") {
                        performanceMetrics(comparison: comparison)
                    }
                }
            }
            .navigationTitle("Compare Months")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private var comparisonChart: some View {
        Chart {
            BarMark(
                x: .value("Month", MonthFormatter.displayName(for: currentMonth.monthKey)),
                y: .value("Total", NSDecimalNumber(decimal: currentMonth.totalSaved).doubleValue)
            )
            .foregroundStyle(Color.appSuccess)

            if let comparison = selectedComparison {
                BarMark(
                    x: .value("Month", MonthFormatter.displayName(for: comparison.monthKey)),
                    y: .value("Total", NSDecimalNumber(decimal: comparison.totalSaved).doubleValue)
                )
                .foregroundStyle(Color.appAccent)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { mark in
                if let total = mark.as(Double.self) {
                    AxisValueLabel(CurrencyFormatter.string(from: Decimal(total)))
                }
            }
        }
        .frame(height: 200)
        .padding(.vertical, Spacing.md)
    }

    @ViewBuilder
    private func statsComparison(comparison: MonthSummaryDisplay) -> some View {
        statRow(
            label: "Total Saved",
            current: CurrencyFormatter.string(from: currentMonth.totalSaved),
            comparison: CurrencyFormatter.string(from: comparison.totalSaved),
            difference: currentMonth.totalSaved - comparison.totalSaved,
            isPositiveGood: true
        )

        statRow(
            label: "Items Resisted",
            current: "\(currentMonth.itemCount)",
            comparison: "\(comparison.itemCount)",
            difference: Decimal(currentMonth.itemCount - comparison.itemCount),
            isPositiveGood: true
        )

        statRow(
            label: "Avg. Item Price",
            current: CurrencyFormatter.string(from: currentAverage),
            comparison: CurrencyFormatter.string(from: comparisonAverage),
            difference: currentAverage - comparisonAverage,
            isPositiveGood: false
        )
    }

    @ViewBuilder
    private func statRow(label: String, current: String, comparison: String, difference: Decimal, isPositiveGood: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(MonthFormatter.displayName(for: currentMonth.monthKey))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(current)
                        .font(.headline)
                        .foregroundStyle(Color.appSuccess)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(MonthFormatter.displayName(for: selectedComparison?.monthKey ?? ""))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(comparison)
                        .font(.headline)
                        .foregroundStyle(Color.appAccent)
                }
            }

            // Difference indicator
            if difference != .zero {
                let isPositive = difference > 0
                let showAsGood = isPositiveGood ? isPositive : !isPositive

                HStack(spacing: 4) {
                    Image(systemName: isPositive ? "arrow.up" : "arrow.down")
                        .font(.caption)
                    Text("\(abs(difference).formatted()) \(isPositive ? "more" : "less")")
                        .font(.caption)
                }
                .foregroundStyle(showAsGood ? Color.appSuccess : Color.red)
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func performanceMetrics(comparison: MonthSummaryDisplay) -> some View {
        let percentChange = calculatePercentChange(
            current: currentMonth.totalSaved,
            previous: comparison.totalSaved
        )

        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Performance vs \(MonthFormatter.displayName(for: comparison.monthKey))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                if let percent = percentChange {
                    Text(percent >= 0 ? "+\(Int(percent))%" : "\(Int(percent))%")
                        .font(.headline)
                        .foregroundStyle(percent >= 0 ? Color.appSuccess : Color.red)
                }
            }

            // Trend analysis
            if let percent = percentChange {
                Text(trendMessage(percent: percent))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Winner comparison
            if currentMonth.winnerItemId != nil && comparison.winnerItemId != nil {
                Text("Both months had winners selected")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if currentMonth.winnerItemId != nil {
                Text("This month is closed, comparison month is still in progress")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if comparison.winnerItemId != nil {
                Text("This month is still in progress, comparison month is closed")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func calculatePercentChange(current: Decimal, previous: Decimal) -> Double? {
        guard previous > 0 else { return nil }
        let change = current - previous
        let percent = (change / previous) * 100
        return NSDecimalNumber(decimal: percent).doubleValue
    }

    private func trendMessage(percent: Double) -> String {
        let absPercent = abs(percent)
        if percent > 0 {
            if absPercent > 50 {
                return "Outstanding improvement! You saved significantly more this month."
            } else if absPercent > 20 {
                return "Great progress! Your savings increased nicely."
            } else {
                return "Steady improvement. Keep it up!"
            }
        } else {
            if absPercent > 50 {
                return "Savings decreased significantly. Consider reviewing your resistance strategies."
            } else if absPercent > 20 {
                return "Savings dipped this month. Stay focused!"
            } else {
                return "Slight decrease in savings. You're still doing well!"
            }
        }
    }
}

#if DEBUG && canImport(PreviewsMacros)
#Preview {
    let container = PreviewSupport.container
    let summary1 = MonthSummaryDisplay(id: UUID(), monthKey: "2025,09", totalSaved: 500, itemCount: 10, winnerItemId: UUID(), closedAt: Date())
    let historyVM = HistoryViewModel(monthRepository: container.monthRepository,
                                     itemRepository: container.itemRepository,
                                     imageStore: container.imageStore,
                                     settingsRepository: container.settingsRepository)
    return MonthComparisonView(currentMonth: summary1, viewModel: historyVM)
}
#endif
