import SwiftUI

struct KPITile: View {
    let title: String
    let value: String
    let subtitle: String
    let trend: TrendDirection?
    let trendPercent: Double?

    enum TrendDirection {
        case up
        case down
        case flat
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            // Title
            Text(title)
                .font(.caption)
                .foregroundColor(Color.secondaryFallback)
                .lineLimit(1)

            // Value
            Text(value)
                .font(.system(.title2, design: .rounded))
                .fontWeight(.bold)
                .monospacedDigit()
                .foregroundColor(Color.primaryFallback)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            HStack(spacing: 4) {
                // Subtitle
                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(Color.secondaryFallback)

                Spacer()

                // Trend indicator
                if let trend = trend, let percent = trendPercent {
                    HStack(spacing: 2) {
                        Image(systemName: trendIcon(for: trend))
                            .font(.caption2)
                        Text("\(Int(abs(percent)))%")
                            .font(.caption2)
                            .monospacedDigit()
                    }
                    .foregroundColor(trendColor(for: trend))
                }
            }
        }
        .padding(Spacing.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value), \(subtitle)")
    }

    private func trendIcon(for direction: TrendDirection) -> String {
        switch direction {
        case .up: return "chevron.up"
        case .down: return "chevron.down"
        case .flat: return "minus"
        }
    }

    private func trendColor(for direction: TrendDirection) -> Color {
        switch direction {
        case .up: return Color.successFallback
        case .down: return Color.warningFallback
        case .flat: return Color.secondaryFallback
        }
    }
}

#if DEBUG
#Preview {
    VStack(spacing: 12) {
        HStack(spacing: 12) {
            KPITile(
                title: "Temptations resisted",
                value: "24",
                subtitle: "this month",
                trend: .up,
                trendPercent: 15
            )

            KPITile(
                title: "Average avoided spend",
                value: "$45",
                subtitle: "per temptation",
                trend: .down,
                trendPercent: -8
            )
        }

        HStack(spacing: 12) {
            KPITile(
                title: "Streak",
                value: "7 days",
                subtitle: "current",
                trend: .flat,
                trendPercent: 0
            )

            KPITile(
                title: "Total saved",
                value: "$1,234",
                subtitle: "all time",
                trend: nil,
                trendPercent: nil
            )
        }
    }
    .padding()
}
#endif
