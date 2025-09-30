import SwiftUI

struct EmptyStateView: View {
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera")
                .font(.system(size: 54, weight: .medium))
                .symbolRenderingMode(.palette)
                .foregroundStyle(Color.accentColor.opacity(0.9), Color.accentColor.opacity(0.2))
            Text(title)
                .font(.title3)
                .bold()
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .background(Color(.systemBackground).opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}
