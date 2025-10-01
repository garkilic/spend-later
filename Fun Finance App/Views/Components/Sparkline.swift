import SwiftUI

struct Sparkline: View {
    let data: [Double]
    let accentColor: Color
    let height: CGFloat

    init(data: [Double], accentColor: Color = .accentFallback, height: CGFloat = 44) {
        self.data = data
        self.accentColor = accentColor
        self.height = height
    }

    var body: some View {
        GeometryReader { geometry in
            Path { path in
                guard !data.isEmpty else { return }

                let maxValue = data.max() ?? 1
                let minValue = data.min() ?? 0
                let range = maxValue - minValue
                let scale = range > 0 ? range : 1

                let stepX = geometry.size.width / CGFloat(max(data.count - 1, 1))
                let stepY = geometry.size.height

                for (index, value) in data.enumerated() {
                    let x = CGFloat(index) * stepX
                    let normalizedValue = (value - minValue) / scale
                    let y = stepY - (CGFloat(normalizedValue) * stepY)

                    if index == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
            }
            .stroke(accentColor, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
        }
        .frame(height: height)
        .accessibilityLabel(accessibilityDescription)
    }

    private var accessibilityDescription: String {
        guard !data.isEmpty else { return "No data available" }
        let total = data.reduce(0, +)
        let average = total / Double(data.count)
        let trend = data.count > 1 && data.last! > data.first! ? "trending up" : "trending down"
        return "Sparkline showing average of \(Int(average)) dollars, \(trend)"
    }
}

#if DEBUG
#Preview {
    VStack(spacing: 20) {
        Sparkline(data: [10, 20, 15, 30, 25, 40, 35])
            .padding()

        Sparkline(data: [40, 35, 30, 25, 20, 15, 10])
            .padding()

        Sparkline(data: [])
            .padding()
    }
}
#endif
