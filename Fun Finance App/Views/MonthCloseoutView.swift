import CoreData
import SwiftUI

struct MonthCloseoutView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: MonthCloseoutViewModel
    let imageProvider: (WantedItemDisplay) -> UIImage?
    @State private var isDrawing = false
    @State private var showConfetti = false
    @State private var revealedItems: Set<UUID> = []
    @State private var isShimmering = false
    @State private var showWinnerSpotlight = false
    @Namespace private var animation

    init(viewModel: MonthCloseoutViewModel, imageProvider: @escaping (WantedItemDisplay) -> UIImage?) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.imageProvider = imageProvider
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Background dimming when winner is shown
                if showWinnerSpotlight {
                    Color.black.opacity(0.7)
                        .ignoresSafeArea()
                        .transition(.opacity)
                }

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        Text(viewModel.title)
                            .font(.largeTitle)
                            .bold()

                        if showWinnerSpotlight, let winner = viewModel.winner {
                            // Winner spotlight takes center stage
                            EmptyView()
                        } else if !isDrawing && viewModel.winner != nil {
                            // Post-celebration state
                            if let winner = viewModel.winner {
                                winnerSection(for: winner)
                            }
                        } else {
                            // Drawing or initial state
                            revealGridSection
                        }

                        if !showWinnerSpotlight {
                            allItemsSection
                            if !isDrawing && viewModel.winner == nil {
                                drawSection
                            }
                        }
                    }
                    .padding()
                }

                // Winner spotlight overlay
                if showWinnerSpotlight, let winner = viewModel.winner {
                    winnerSpotlight(for: winner)
                }

                if showConfetti {
                    ConfettiView()
                        .allowsHitTesting(false)
                }
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
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Image(systemName: "trophy.fill")
                    .font(.title)
                    .foregroundStyle(.yellow)
                Text("🎉 Winner! 🎉")
                    .font(.title.weight(.bold))
                    .foregroundStyle(.primary)
                Image(systemName: "trophy.fill")
                    .font(.title)
                    .foregroundStyle(.yellow)
            }
            .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: 16) {
                ItemCardView(item: item, image: imageProvider(item))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                LinearGradient(colors: [.yellow, .orange, .yellow], startPoint: .topLeading, endPoint: .bottomTrailing),
                                lineWidth: 4
                            )
                    )
                    .shadow(color: .yellow.opacity(0.5), radius: 20, x: 0, y: 10)

                if !item.tags.isEmpty {
                    TagListView(tags: item.tags)
                }
            }
        }
        .padding(24)
        .background(
            LinearGradient(colors: [Color.yellow.opacity(0.15), Color.orange.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.yellow.opacity(0.3), lineWidth: 2)
        )
    }

    var revealGridSection: some View {
        let activeItems = viewModel.items.filter { $0.status == .active }
        let _ = print("🎨 RevealGrid - Total items: \(viewModel.items.count), Active items: \(activeItems.count)")
        let _ = viewModel.items.forEach { print("  - \($0.title): \($0.status)") }

        return VStack(alignment: .leading, spacing: 16) {
            Text(isDrawing ? "Drawing..." : "Ready to spin")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(isDrawing ? Color.successFallback : Color.primaryFallback)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                ForEach(activeItems) { item in
                    revealGridItem(item)
                }
            }
        }
    }

    func revealGridItem(_ item: WantedItemDisplay) -> some View {
        let isRevealed = revealedItems.contains(item.id)
        let isWinner = viewModel.winner?.id == item.id

        return ZStack {
            ItemCardView(item: item, image: imageProvider(item))
                .blur(radius: isRevealed ? 0 : 12)
                .opacity(isDrawing ? (isRevealed && !isWinner ? 0.3 : 1.0) : 1.0)
                .scaleEffect(isRevealed ? 1.0 : 0.95)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            isShimmering ? Color.accentFallback.opacity(0.6) : Color.clear,
                            lineWidth: 2
                        )
                )
                .shadow(
                    color: isShimmering ? Color.accentFallback.opacity(0.3) : Color.clear,
                    radius: isShimmering ? 8 : 0
                )

            // Frosted overlay when not revealed
            if !isRevealed {
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        Image(systemName: "questionmark")
                            .font(.system(size: 40, weight: .bold))
                            .foregroundStyle(Color.secondaryFallback.opacity(0.5))
                    )
            }
        }
        .animation(.spring(response: 0.6, dampingFraction: 0.7), value: isRevealed)
        .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isShimmering)
    }

    var allItemsSection: some View {
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
        Button {
            print("🎯 Draw Winner button tapped")
            print("🎯 canDraw: \(viewModel.canDraw)")
            print("🎯 isDrawing: \(isDrawing)")
            print("🎯 Active items count: \(viewModel.items.filter { $0.status == .active }.count)")
            startRevealAnimation()
        } label: {
            HStack {
                Image(systemName: "gift.fill")
                    .font(.title2)
                Text("DRAW WINNER")
                    .font(.title3)
                    .fontWeight(.bold)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 64)
            .background(
                LinearGradient(
                    colors: [Color.orange, Color.red],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .foregroundColor(.white)
            .cornerRadius(CornerRadius.button)
            .shadow(color: Color.orange.opacity(0.5), radius: 12, y: 6)
        }
        .disabled(!viewModel.canDraw || isDrawing)
        .opacity((!viewModel.canDraw || isDrawing) ? 0.5 : 1.0)
    }

    func winnerSpotlight(for item: WantedItemDisplay) -> some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 16) {
                // Trophy icon
                Image(systemName: "trophy.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.yellow, .orange],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: .yellow.opacity(0.6), radius: 20)

                Text("🎉 Winner! 🎉")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)

                // Winner card
                ItemCardView(item: item, image: imageProvider(item))
                    .frame(maxWidth: 300)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                LinearGradient(
                                    colors: [.yellow, .orange, .yellow],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 4
                            )
                    )
                    .shadow(color: .yellow.opacity(0.6), radius: 30)
                    .scaleEffect(1.1)
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.yellow.opacity(0.2),
                                Color.orange.opacity(0.15)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(Color.yellow.opacity(0.4), lineWidth: 2)
                    )
            )

            Spacer()
        }
        .transition(.scale.combined(with: .opacity))
    }

    func startRevealAnimation() {
        print("🚀 startRevealAnimation called")

        guard viewModel.canDraw else {
            print("❌ Cannot draw - viewModel.canDraw is false")
            return
        }

        let candidates = viewModel.items.filter { $0.status == .active }
        print("✅ Found \(candidates.count) active candidates")

        guard !candidates.isEmpty else {
            print("❌ No candidates available")
            return
        }

        print("✅ Starting animation sequence")

        // Reset state
        revealedItems.removeAll()
        isDrawing = true
        HapticManager.shared.heavyImpact()

        // Phase 1: Shimmer (1.5 seconds)
        withAnimation {
            isShimmering = true
        }
        print("✨ Shimmer phase started")

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            print("✨ Shimmer phase ended")
            withAnimation {
                isShimmering = false
            }

            // Phase 2: Sequential reveals
            print("🎲 Starting sequential reveals")
            self.revealItemsSequentially(candidates: candidates)
        }
    }

    func revealItemsSequentially(candidates: [WantedItemDisplay]) {
        // First, draw the actual winner in the ViewModel
        guard let winnerCandidate = candidates.randomElement() else { return }

        // Prepare reveal order: shuffle all items, then ensure winner is last
        var shuffled = candidates.shuffled()
        if let winnerIndex = shuffled.firstIndex(where: { $0.id == winnerCandidate.id }) {
            let winner = shuffled.remove(at: winnerIndex)
            shuffled.append(winner)
        }

        let delayIncrement = 0.3

        for (index, item) in shuffled.enumerated() {
            let delay = Double(index) * delayIncrement
            let isLast = index == shuffled.count - 1

            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                    revealedItems.insert(item.id)
                }
                HapticManager.shared.lightImpact()

                if isLast {
                    // This is the winner - trigger celebration
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                        // Actually save the winner to Core Data
                        viewModel.setWinner(winnerCandidate)
                        HapticManager.shared.success()
                        HapticManager.shared.heavyImpact()

                        withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                            showWinnerSpotlight = true
                        }

                        showConfetti = true

                        // Hide spotlight after 3 seconds
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            withAnimation {
                                showWinnerSpotlight = false
                                showConfetti = false
                                isDrawing = false
                            }
                        }
                    }
                }
            }
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
    item1.tags = ["style", "fitness"]
    item1.createdAt = Date()
    item1.monthKey = summary.monthKey
    item1.status = .active

    let item2 = WantedItemEntity(context: context)
    item2.id = UUID()
    item2.title = "Headphones"
    item2.price = NSDecimalNumber(value: 40)
    item2.imagePath = ""
    item2.tags = ["audio"]
    item2.createdAt = Date()
    item2.monthKey = summary.monthKey
    item2.status = .active

    summary.items = NSSet(array: [item1, item2])

    return MonthCloseoutView(viewModel: MonthCloseoutViewModel(summary: summary,
                                                               haptics: container.hapticManager,
                                                               settingsRepository: container.settingsRepository)) { _ in
        nil
    }
}
#endif
