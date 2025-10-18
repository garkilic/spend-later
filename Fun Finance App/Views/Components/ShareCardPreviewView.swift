import SwiftUI

/// Preview view that shows the share card before sharing
struct ShareCardPreviewView: View {
    @Environment(\.dismiss) private var dismiss
    let cardType: ShareCardType

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: Spacing.xl) {
                    Spacer()

                    // Card preview
                    ShareCardView(type: cardType)
                        .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)

                    Spacer()

                    // Share button
                    Button {
                        shareCard()
                        HapticManager.shared.lightImpact()
                    } label: {
                        HStack(spacing: Spacing.sm) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.title3)
                            Text("Share This Card")
                                .font(.headline)
                        }
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(.white)
                        .cornerRadius(CornerRadius.button)
                    }
                    .padding(.horizontal, Spacing.xl)
                    .padding(.bottom, Spacing.xl)
                }
            }
            .navigationTitle("Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
    }

    private func shareCard() {
        guard let viewController = UIApplication.shared.keyWindowPresentedController else { return }
        ShareCardRenderer.share(cardType, from: viewController)
    }
}

#if DEBUG && canImport(PreviewsMacros)
#Preview {
    ShareCardPreviewView(cardType: .totalSaved(1234.56))
}
#endif
