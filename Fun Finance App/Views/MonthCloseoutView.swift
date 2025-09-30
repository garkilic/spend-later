import CoreData
import SwiftUI

struct MonthCloseoutView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: MonthCloseoutViewModel
    let imageProvider: (WantedItemDisplay) -> UIImage?

    init(viewModel: MonthCloseoutViewModel, imageProvider: @escaping (WantedItemDisplay) -> UIImage?) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.imageProvider = imageProvider
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text(viewModel.title)
                        .font(.largeTitle)
                        .bold()
                    if let winner = viewModel.winner {
                        winnerSection(for: winner)
                    }
                    itemGrid
                    drawSection
                }
                .padding()
            }
            .navigationTitle("Closeout")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

private extension MonthCloseoutView {
    func winnerSection(for item: WantedItemDisplay) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Winner")
                .font(.headline)
            ItemCardView(item: item, image: imageProvider(item))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.green, lineWidth: 4))
            if let productText = item.productText {
                Text(productText)
                    .font(.body)
            }
        }
        .padding()
        .background(Color.green.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    var itemGrid: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("All items")
                .font(.headline)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                ForEach(viewModel.items) { item in
                    ItemCardView(item: item, image: imageProvider(item))
                        .overlay(alignment: .topTrailing) {
                            statusOverlay(for: item)
                        }
                }
            }
        }
    }

    @ViewBuilder
    func statusOverlay(for item: WantedItemDisplay) -> some View {
        switch item.status {
        case .redeemed:
            Label("Redeemed", systemImage: "checkmark.seal.fill")
                .padding(8)
                .background(Color.green.opacity(0.8))
                .clipShape(Capsule())
                .foregroundStyle(.white)
                .padding(6)
        case .skipped:
            Label("Skipped", systemImage: "xmark")
                .padding(8)
                .background(Color.gray.opacity(0.6))
                .clipShape(Capsule())
                .foregroundStyle(.white)
                .padding(6)
        case .active:
            EmptyView()
        }
    }

    var drawSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Manual draw")
                .font(.headline)
            Button {
                viewModel.drawWinner()
            } label: {
                Label("Draw reward", systemImage: "sparkles")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!viewModel.canDraw)
        }
    }
}

#if DEBUG && canImport(PreviewsMacros)
#Preview {
    let container = PreviewSupport.container
    let context = container.viewContext

    let summary = MonthSummaryEntity(context: context)
    summary.id = UUID()
    summary.monthKey = "2025,09"
    summary.totalSaved = NSDecimalNumber(value: 120)
    summary.itemCount = 2

    let item1 = WantedItemEntity(context: context)
    item1.id = UUID()
    item1.title = "Sneakers"
    item1.price = NSDecimalNumber(value: 80)
    item1.imagePath = ""
    item1.createdAt = Date()
    item1.monthKey = summary.monthKey
    item1.status = .active

    let item2 = WantedItemEntity(context: context)
    item2.id = UUID()
    item2.title = "Headphones"
    item2.price = NSDecimalNumber(value: 40)
    item2.imagePath = ""
    item2.createdAt = Date()
    item2.monthKey = summary.monthKey
    item2.status = .active

    summary.items = NSSet(array: [item1, item2])

    return MonthCloseoutView(viewModel: MonthCloseoutViewModel(summary: summary, haptics: container.hapticManager)) { _ in
        nil
    }
}
#endif
