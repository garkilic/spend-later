import Foundation
import Combine
import UIKit

@MainActor
final class DashboardViewModel: ObservableObject {
    @Published var items: [WantedItemDisplay] = []
    @Published var totalSaved: Decimal = .zero
    @Published var itemCount: Int = 0
    @Published var pendingUndoItem: WantedItemDisplay?
    @Published var canReviewLastMonth: Bool = false

    private let itemRepository: ItemRepositoryProtocol
    private let imageStore: ImageStoring
    private var pendingDeletion: (snapshot: ItemSnapshot, workItem: DispatchWorkItem)?
    private let calendar: Calendar

    init(itemRepository: ItemRepositoryProtocol,
         imageStore: ImageStoring,
         calendar: Calendar = .current) {
        self.itemRepository = itemRepository
        self.imageStore = imageStore
        self.calendar = calendar
    }

    func refresh() {
        do {
            let items = try itemRepository.items(for: itemRepository.currentMonthKey)
            apply(items: items)
            updateReviewAvailability()
        } catch {
            assertionFailure("Failed to fetch items: \(error)")
        }
    }

    func delete(_ display: WantedItemDisplay) {
        do {
            guard let entity = try itemRepository.item(with: display.id) else { return }
            let snapshot = itemRepository.makeSnapshot(from: entity)
            try itemRepository.delete(entity)
            scheduleUndo(for: snapshot)
            refresh()
        } catch {
            assertionFailure("Delete failed: \(error)")
        }
    }

    func undoDelete() {
        guard let pendingDeletion else { return }
        pendingDeletion.workItem.cancel()
        do {
            try itemRepository.restore(pendingDeletion.snapshot)
            pendingUndoItem = nil
            self.pendingDeletion = nil
            refresh()
        } catch {
            assertionFailure("Undo failed: \(error)")
        }
    }

    func image(for item: WantedItemDisplay) -> UIImage? {
        imageStore.loadImage(named: item.imagePath)
    }
}

private extension DashboardViewModel {
    func apply(items: [WantedItemEntity]) {
        let displays = items.map { entity in
            WantedItemDisplay(id: entity.id,
                              title: entity.title,
                              price: entity.price.decimalValue,
                              notes: entity.notes,
                              productText: entity.productText,
                              productURL: entity.productURL,
                              imagePath: entity.imagePath,
                              status: entity.status,
                              createdAt: entity.createdAt)
        }
        self.items = displays
        totalSaved = displays.reduce(.zero) { $0 + $1.price }
        itemCount = displays.count
    }

    func updateReviewAvailability() {
        guard let previousMonthDate = calendar.date(byAdding: .month, value: -1, to: Date()) else {
            canReviewLastMonth = false
            return
        }

        let previousKey = itemRepository.monthKey(for: previousMonthDate)
        do {
            let previousItems = try itemRepository.items(for: previousKey)
            canReviewLastMonth = !previousItems.isEmpty
        } catch {
            canReviewLastMonth = false
        }
    }

    func scheduleUndo(for snapshot: ItemSnapshot) {
        let display = WantedItemDisplay(id: snapshot.id,
                                         title: snapshot.title,
                                         price: snapshot.price,
                                         notes: snapshot.notes,
                                         productText: snapshot.productText,
                                         productURL: snapshot.productURL,
                                         imagePath: snapshot.imagePath,
                                         status: snapshot.status,
                                         createdAt: snapshot.createdAt)
        pendingUndoItem = display
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.pendingUndoItem = nil
            self.pendingDeletion = nil
            self.imageStore.deleteImage(named: snapshot.imagePath)
        }
        pendingDeletion = (snapshot, workItem)
        DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: workItem)
    }
}
