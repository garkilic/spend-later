import SwiftUI

/// Visual card designs for sharing stats on social media
struct ShareCardView: View {
    let type: ShareCardType

    var body: some View {
        ZStack {
            // Gradient background
            LinearGradient(
                colors: type.gradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: 24) {
                Spacer()

                // Icon
                Image(systemName: type.icon)
                    .font(.system(size: 80, weight: .bold))
                    .foregroundColor(.white)

                // Main value
                Text(type.value)
                    .font(.system(size: 72, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .monospacedDigit()
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)

                // Label
                Text(type.label)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(.white.opacity(0.95))
                    .multilineTextAlignment(.center)

                // Tagline
                Text(type.tagline)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                Spacer()

                // App branding
                HStack(spacing: 8) {
                    Image(systemName: "hand.raised.fill")
                        .font(.system(size: 20))
                    Text("Fun Finance")
                        .font(.system(size: 18, weight: .semibold))
                }
                .foregroundColor(.white.opacity(0.9))
                .padding(.bottom, 32)
            }
            .padding(40)
        }
        .frame(width: 600, height: 800)
    }
}

enum ShareCardType {
    case totalSaved(Decimal)
    case temptationsResisted(Int)
    case averagePrice(Decimal)
    case buyersRemorse(Int)
    case carbonFootprint(Double)

    var icon: String {
        switch self {
        case .totalSaved: return "chart.line.uptrend.xyaxis"
        case .temptationsResisted: return "flame.fill"
        case .averagePrice: return "dollarsign.circle.fill"
        case .buyersRemorse: return "hand.raised.fill"
        case .carbonFootprint: return "leaf.fill"
        }
    }

    var value: String {
        switch self {
        case .totalSaved(let amount):
            return CurrencyFormatter.string(from: amount)
        case .temptationsResisted(let count):
            return "\(count)"
        case .averagePrice(let amount):
            return CurrencyFormatter.string(from: amount)
        case .buyersRemorse(let count):
            return "\(count)"
        case .carbonFootprint(let kg):
            return formatCO2(kg)
        }
    }

    var label: String {
        switch self {
        case .totalSaved: return "Saved This Month"
        case .temptationsResisted: return "Temptations Resisted"
        case .averagePrice: return "Average Per Impulse"
        case .buyersRemorse: return "Regrets Prevented"
        case .carbonFootprint: return "CO₂ Saved"
        }
    }

    var tagline: String {
        switch self {
        case .totalSaved: return "💪 Willpower Wins"
        case .temptationsResisted: return "🔥 Building Stronger Habits"
        case .averagePrice: return "💰 Money Stays In My Pocket"
        case .buyersRemorse: return "😌 No More Buyer's Remorse"
        case .carbonFootprint: return "🌱 Saving The Planet Too"
        }
    }

    var gradientColors: [Color] {
        switch self {
        case .totalSaved:
            return [Color(red: 0.2, green: 0.8, blue: 0.4), Color(red: 0.1, green: 0.6, blue: 0.3)]
        case .temptationsResisted:
            return [Color(red: 1.0, green: 0.3, blue: 0.3), Color(red: 0.8, green: 0.1, blue: 0.1)]
        case .averagePrice:
            return [Color(red: 0.2, green: 0.7, blue: 0.9), Color(red: 0.1, green: 0.5, blue: 0.7)]
        case .buyersRemorse:
            return [Color(red: 0.7, green: 0.3, blue: 0.9), Color(red: 0.5, green: 0.1, blue: 0.7)]
        case .carbonFootprint:
            return [Color(red: 0.2, green: 0.8, blue: 0.5), Color(red: 0.1, green: 0.6, blue: 0.3)]
        }
    }

    private func formatCO2(_ kg: Double) -> String {
        if kg >= 1000 {
            let tonnes = kg / 1000
            return String(format: "%.1ft", tonnes)
        } else {
            return String(format: "%.0fkg", kg)
        }
    }
}

#if DEBUG && canImport(PreviewsMacros)
#Preview("Total Saved") {
    ShareCardView(type: .totalSaved(1234.56))
}

#Preview("Temptations") {
    ShareCardView(type: .temptationsResisted(12))
}

#Preview("Carbon") {
    ShareCardView(type: .carbonFootprint(66.5))
}
#endif
