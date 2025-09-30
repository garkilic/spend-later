import SwiftUI

struct ProgressRingView: View {
    let progress: Double
    let label: String

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: 12)
            Circle()
                .trim(from: 0, to: min(progress, 1.0))
                .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut, value: progress)
            VStack {
                Text(label)
                    .font(.headline)
                Text(String(format: "%.0f%%", min(progress, 1.0) * 100))
                    .font(.title3)
                    .bold()
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Savings progress")
        .accessibilityValue(label)
    }
}
