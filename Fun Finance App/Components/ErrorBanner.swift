import SwiftUI

struct ErrorBanner: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.white)
                .font(.title3)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()

            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.white.opacity(0.7))
                    .font(.title3)
            }
        }
        .padding()
        .background(Color.red)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: .red.opacity(0.3), radius: 8, x: 0, y: 4)
        .padding()
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}

struct ErrorBannerModifier: ViewModifier {
    @Binding var error: String?

    func body(content: Content) -> some View {
        ZStack(alignment: .top) {
            content

            if let error = error {
                ErrorBanner(message: error) {
                    withAnimation {
                        self.error = nil
                    }
                }
                .onAppear {
                    // Auto-dismiss after 5 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                        withAnimation {
                            self.error = nil
                        }
                    }
                }
            }
        }
        .animation(.spring(), value: error != nil)
    }
}

extension View {
    func errorBanner(_ error: Binding<String?>) -> some View {
        modifier(ErrorBannerModifier(error: error))
    }
}
