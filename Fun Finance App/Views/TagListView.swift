import SwiftUI

struct TagListView: View {
    let tags: [String]

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 80), spacing: 8)], spacing: 8) {
            ForEach(tags, id: \.self) { tag in
                Text(tag)
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.accentColor.opacity(0.15))
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, 4)
    }
}

#if DEBUG && canImport(PreviewsMacros)
#Preview {
    TagListView(tags: ["mindful", "self-care", "treat"])
        .padding()
}
#endif
