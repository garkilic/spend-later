import Charts
import SwiftUI

struct YearlySummaryView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: DashboardViewModel

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Chart(viewModel.yearlyTotals) { point in
                    LineMark(
                        x: .value("Month", point.date),
                        y: .value("Total", point.total)
                    )
                    .interpolationMethod(.catmullRom)
                    AreaMark(
                        x: .value("Month", point.date),
                        y: .value("Total", point.total)
                    )
                    .foregroundStyle(Color.accentColor.opacity(0.2))
                    PointMark(
                        x: .value("Month", point.date),
                        y: .value("Total", point.total)
                    )
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .month)) { value in
                        if let dateValue = value.as(Date.self) {
                            AxisValueLabel(DateFormatter.shortMonth.string(from: dateValue))
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { mark in
                        if let total = mark.as(Double.self) {
                            AxisValueLabel(CurrencyFormatter.string(from: Decimal(total)))
                        }
                    }
                }
                .frame(height: 240)

                summaryList

                Spacer()
            }
            .padding()
            .navigationTitle("Yearly savings")
           .toolbar {
               ToolbarItem(placement: .cancellationAction) {
                   Button("Done") { dismiss() }
               }
           }
        }
    }
}

private extension YearlySummaryView {
    var summaryList: some View {
        let totals = viewModel.yearlyTotals.map(\.total)
        let totalSaved = totals.reduce(Decimal.zero, +)
        let average = totals.isEmpty ? Decimal.zero : totalSaved / Decimal(totals.count)
        let best = viewModel.yearlyTotals.max(by: { $0.total < $1.total })

        return VStack(alignment: .leading, spacing: 12) {
            summaryRow(title: "Average per month", value: CurrencyFormatter.string(from: average))
            if let best {
                summaryRow(title: "Best month", value: CurrencyFormatter.string(from: best.total), subtitle: MonthFormatter.displayName(for: best.monthKey))
            }
            summaryRow(title: "12-month total", value: CurrencyFormatter.string(from: totalSaved))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    func summaryRow(title: String, value: String, subtitle: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack {
                Text(value)
                    .font(.headline)
                if let subtitle {
                    Spacer()
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color(.secondarySystemBackground)))
    }
}

private extension DateFormatter {
    static let shortMonth: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return formatter
    }()
}

#if DEBUG && canImport(PreviewsMacros)
#Preview {
    let container = PreviewSupport.container
    let dashboard = DashboardViewModel(itemRepository: container.itemRepository,
                                       monthRepository: container.monthRepository,
                                       settingsRepository: container.settingsRepository,
                                       imageStore: container.imageStore)
    return YearlySummaryView(viewModel: dashboard)
}
#endif
