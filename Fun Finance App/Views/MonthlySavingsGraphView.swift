import SwiftUI
import Charts

struct MonthlySavingsGraphView: View {
    @Environment(\.dismiss) private var dismiss
    let monthlyData: [(month: String, amount: Decimal)]
    let totalSaved: Decimal

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.xl) {
                    // Total card
                    totalCard

                    // Chart
                    chartSection

                    // Data list
                    dataList
                }
                .padding(Spacing.sideGutter)
                .padding(.top, Spacing.md)
            }
            .background(Color.surfaceFallback)
            .navigationTitle("Savings Over Time")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

private extension MonthlySavingsGraphView {
    var totalCard: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("TOTAL SAVED")
                .sectionHeaderStyle()

            Text(CurrencyFormatter.string(from: totalSaved))
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundColor(Color.successFallback)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.lg)
        .cardStyle()
    }

    var chartSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("MONTHLY BREAKDOWN")
                .sectionHeaderStyle()

            if #available(iOS 16.0, *) {
                Chart {
                    ForEach(monthlyData, id: \.month) { data in
                        BarMark(
                            x: .value("Month", data.month),
                            y: .value("Amount", NSDecimalNumber(decimal: data.amount).doubleValue)
                        )
                        .foregroundStyle(Color.successFallback)
                        .cornerRadius(8)
                    }
                }
                .frame(height: 250)
                .padding(Spacing.md)
                .cardStyle()
            } else {
                Text("Charts require iOS 16 or later")
                    .foregroundColor(Color.secondaryFallback)
                    .padding(Spacing.lg)
                    .cardStyle()
            }
        }
    }

    var dataList: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("MONTHLY TOTALS")
                .sectionHeaderStyle()

            VStack(spacing: Spacing.xs) {
                ForEach(monthlyData, id: \.month) { data in
                    HStack {
                        Text(data.month)
                            .font(.body)
                            .foregroundColor(Color.primaryFallback)

                        Spacer()

                        Text(CurrencyFormatter.string(from: data.amount))
                            .font(.body)
                            .fontWeight(.semibold)
                            .monospacedDigit()
                            .foregroundColor(Color.successFallback)
                    }
                    .padding(Spacing.md)
                    .background(Color.surfaceElevatedFallback)
                    .cornerRadius(CornerRadius.listRow)
                }
            }
        }
    }
}

#if DEBUG
#Preview {
    MonthlySavingsGraphView(
        monthlyData: [
            ("Jan", 125.50),
            ("Feb", 234.75),
            ("Mar", 189.00),
            ("Apr", 310.25),
            ("May", 275.50),
            ("Jun", 198.75)
        ],
        totalSaved: 1333.75
    )
}
#endif
