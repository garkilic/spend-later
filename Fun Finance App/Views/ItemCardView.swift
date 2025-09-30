import SwiftUI
import UIKit

struct ItemCardView: View {
    let item: WantedItemDisplay
    let image: UIImage?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.accentColor.opacity(0.12))
                        .overlay(
                            Image(systemName: "sparkles.rectangle.stack")
                                .font(.largeTitle)
                                .foregroundStyle(Color.accentColor)
                        )
                }
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(1, contentMode: .fill)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .clipped()

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.headline)
                    .lineLimit(1)
                Text(CurrencyFormatter.string(from: item.priceWithTax))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(
            LinearGradient(colors: [Color(.secondarySystemBackground), Color.accentColor.opacity(0.08)], startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.title), \(CurrencyFormatter.string(from: item.price))")
    }
}

#if DEBUG && canImport(PreviewsMacros)
#Preview {
    let item = WantedItemDisplay(id: UUID(),
                                 title: "Fancy Jacket",
                                 price: 149.99,
                                 priceWithTax: 162.44,
                                 notes: "On sale",
                                 tags: ["clothes", "sale"],
                                 productURL: nil,
                                 imagePath: "",
                                 status: .active,
                                 createdAt: Date())
    return ItemCardView(item: item, image: nil)
        .padding()
}
#endif
