import SwiftUI

/// A clickable stat card for displaying KPIs
struct StatCard: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    let onTap: () -> Void

    var body: some View {
        Button(action: {
            HapticManager.shared.lightImpact()
            onTap()
        }) {
            VStack(alignment: .leading, spacing: 4) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(color)

                Spacer()

                Text(value)
                    .font(.system(.title3, design: .rounded))
                    .fontWeight(.bold)
                    .monospacedDigit()
                    .foregroundColor(Color.primaryFallback)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                Text(label)
                    .font(.caption2)
                    .foregroundColor(Color.secondaryFallback)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            .padding(Spacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 80)
            .cardStyle()
        }
        .buttonStyle(.plain)
    }
}

#if DEBUG && canImport(PreviewsMacros)
#Preview {
    VStack(spacing: Spacing.cardSpacing) {
        HStack(spacing: Spacing.cardSpacing) {
            StatCard(
                icon: "flame.fill",
                value: "12",
                label: "Temptations Resisted",
                color: .red,
                onTap: {}
            )

            StatCard(
                icon: "dollarsign.circle.fill",
                value: "$145",
                label: "Avg. Price",
                color: Color.successFallback,
                onTap: {}
            )
        }

        HStack(spacing: Spacing.cardSpacing) {
            StatCard(
                icon: "hand.raised.fill",
                value: "7",
                label: "Regrets Prevented",
                color: Color.purple,
                onTap: {}
            )

            StatCard(
                icon: "leaf.fill",
                value: "66 kg",
                label: "CO₂ Saved",
                color: Color.green,
                onTap: {}
            )
        }
    }
    .padding()
    .background(Color.surfaceFallback)
}
#endif
