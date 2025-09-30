import SwiftUI

struct ReviewItemsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: ReviewItemsViewModel
    @State private var dragOffset: CGSize = .zero

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                if !viewModel.pendingCards.isEmpty {
                    ZStack {
                        ForEach(Array(viewModel.pendingCards.enumerated()), id: \.element.id) { index, card in
                            cardView(for: card)
                                .offset(y: CGFloat(index) * 6)
                                .scaleEffect(1 - CGFloat(index) * 0.03)
                                .opacity(index == 0 ? 1 : 0.5)
                                .allowsHitTesting(index == 0)
                        }
                    }
                    .offset(dragOffset)
                    .rotationEffect(.degrees(Double(dragOffset.width / 10)))
                    .gesture(dragGesture)
                    guidanceOverlay
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 56))
                            .foregroundStyle(Color.accentColor)
                        Text("All caught up")
                            .font(.title2.weight(.semibold))
                        Text("You’ve reviewed every item from last month.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                summaryFooter
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Review items")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    if !viewModel.pendingCards.isEmpty {
                        Button("Skip") { advance(with: .dismiss) }
                    }
                }
            }
        }
    }
}

private extension ReviewItemsView {
    var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                dragOffset = value.translation
            }
            .onEnded { value in
                let horizontal = value.translation.width
                if horizontal > 120 {
                    advance(with: .keep)
                } else if horizontal < -120 {
                    advance(with: .dismiss)
                } else {
                    withAnimation(.spring()) {
                        dragOffset = .zero
                    }
                }
            }
    }

    func advance(with status: ReviewItemsViewModel.Status) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            viewModel.markTop(as: status)
            dragOffset = .zero
        }
    }

    func cardView(for card: ReviewItemsViewModel.ReviewCard) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            ZStack {
                if let image = viewModel.image(for: card) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.accentColor.opacity(0.12))
                        .overlay(
                            Image(systemName: "sparkles")
                                .font(.system(size: 48, weight: .semibold))
                                .foregroundStyle(Color.accentColor)
                        )
                }
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(1, contentMode: .fill)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .clipped()

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(card.item.title)
                        .font(.title2.weight(.semibold))
                        .lineLimit(2)
                    Spacer()
                    Text(CurrencyFormatter.string(from: card.item.priceWithTax))
                        .font(.headline)
                        .foregroundStyle(Color.accentColor)
                }
                if card.item.priceWithTax != card.item.price {
                    Text("Base: \(CurrencyFormatter.string(from: card.item.price))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let notes = card.item.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                if !card.item.tags.isEmpty {
                    TagListView(tags: card.item.tags)
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: Color.black.opacity(0.1), radius: 12, x: 0, y: 8)
    }

    var guidanceOverlay: some View {
        HStack {
            Label("Swipe left to dismiss", systemImage: "arrowshape.turn.up.left")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Spacer()
            Label("Swipe right to keep", systemImage: "arrowshape.turn.up.right")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    var summaryFooter: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Progress")
                .font(.headline)
            HStack {
                Label("Kept: \(viewModel.kept.count)", systemImage: "hand.thumbsup.fill")
                    .foregroundStyle(Color.green)
                Spacer()
                Label("Dismissed: \(viewModel.dismissed.count)", systemImage: "hand.thumbsdown.fill")
                    .foregroundStyle(Color.red)
                Spacer()
                Label("Remaining: \(viewModel.pendingCards.count)", systemImage: "clock")
                    .foregroundStyle(.secondary)
            }
            .font(.subheadline)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color(.secondarySystemBackground)))
    }
}

#if DEBUG && canImport(PreviewsMacros)
#Preview {
    let container = PreviewSupport.container
    let vm = ReviewItemsViewModel(itemRepository: container.itemRepository,
                                  imageStore: container.imageStore,
                                  settingsRepository: container.settingsRepository)
    return ReviewItemsView(viewModel: vm)
}
#endif
