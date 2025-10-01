import SwiftUI

struct ConfettiView: View {
    @State private var animate = false
    let colors: [Color] = [.red, .orange, .yellow, .green, .blue, .purple, .pink]

    var body: some View {
        ZStack {
            ForEach(0..<50, id: \.self) { index in
                ConfettiPiece(color: colors[index % colors.count])
                    .offset(x: randomX(), y: animate ? 800 : -100)
                    .rotationEffect(.degrees(animate ? Double.random(in: 0...720) : 0))
                    .animation(
                        .easeOut(duration: Double.random(in: 1.5...2.5))
                        .delay(Double(index) * 0.02),
                        value: animate
                    )
            }
        }
        .onAppear {
            animate = true
        }
    }

    private func randomX() -> CGFloat {
        CGFloat.random(in: -200...200)
    }
}

struct ConfettiPiece: View {
    let color: Color

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 10, height: 10)
    }
}
