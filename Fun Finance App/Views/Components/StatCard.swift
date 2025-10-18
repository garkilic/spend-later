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
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)

                Text(value)
                    .font(.system(.body, design: .rounded))
                    .fontWeight(.semibold)
                    .monospacedDigit()
                    .foregroundColor(Color.primaryFallback)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 65)
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
