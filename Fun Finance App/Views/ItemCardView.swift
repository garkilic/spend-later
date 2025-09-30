import SwiftUI
import UIKit

struct ItemCardView: View {
    let item: WantedItemDisplay
    let image: UIImage?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 140)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .cornerRadius(12)
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.15))
                    .frame(height: 140)
                    .overlay(Text("No image").foregroundStyle(.secondary))
            }
            Text(item.title)
                .font(.headline)
                .lineLimit(1)
            Text(CurrencyFormatter.string(from: item.price))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.title), \(CurrencyFormatter.string(from: item.price))")
    }
}

#if DEBUG && canImport(PreviewsMacros)
#Preview {
    let item = WantedItemDisplay(id: UUID(), title: "Fancy Jacket", price: 149.99, notes: "On sale", productText: "Brand X", imagePath: "", status: .active, createdAt: Date())
    return ItemCardView(item: item, image: nil)
        .padding()
}
#endif
