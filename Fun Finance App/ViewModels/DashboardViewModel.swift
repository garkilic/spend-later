import Foundation
import Combine
import UIKit

@MainActor
final class DashboardViewModel: ObservableObject {
    @Published var items: [WantedItemDisplay] = []
    @Published var totalSaved: Decimal = .zero
    @Published var itemCount: Int = 0
    @Published var averageItemPrice: Decimal = .zero
    @Published var pendingUndoItem: WantedItemDisplay?
    @Published var canReviewLastMonth: Bool = false
    @Published var yearlyTotals: [MonthlyTrendPoint] = []
    @Published var errorMessage: String?
    @Published var isLoading: Bool = false

    private let itemRepository: ItemRepositoryProtocol
    private let monthRepository: MonthRepositoryProtocol
    private let settingsRepository: SettingsRepositoryProtocol
    private let imageStore: ImageStoring
    private var pendingDeletion: (snapshot: ItemSnapshot, workItem: DispatchWorkItem)?
    private let calendar: Calendar
    private let haptics = HapticManager.shared
    private var taxRate: Decimal = .zero

    init(itemRepository: ItemRepositoryProtocol,
         monthRepository: MonthRepositoryProtocol,
         settingsRepository: SettingsRepositoryProtocol,
         imageStore: ImageStoring,
         calendar: Calendar = .current) {
        self.itemRepository = itemRepository
        self.monthRepository = monthRepository
        self.settingsRepository = settingsRepository
        self.imageStore = imageStore
        self.calendar = calendar
    }

    func refresh(includeYearlyData: Bool = false) {
        do {
            errorMessage = nil
            try reloadTaxRate()
            let items = try itemRepository.items(for: itemRepository.currentMonthKey)
            // Filter to only show saved items on dashboard
            let savedItems = items.filter { $0.status == .saved }
            let displays = makeDisplays(from: savedItems)
            apply(displays: displays)
            updateReviewAvailability()

            // Only load yearly totals when needed (e.g., when viewing graph)
            if includeYearlyData {
                try updateYearlyTotals(currentMonthDisplays: displays)
            }
        } catch {
            errorMessage = "Failed to load items. Please try again."
            assertionFailure("Failed to fetch items: \(error)")
        }
    }

    func loadYearlyData() {
        do {
            try updateYearlyTotals(currentMonthDisplays: items)
        } catch {
            assertionFailure("Failed to load yearly data: \(error)")
        }
    }

    func delete(_ display: WantedItemDisplay) {
        do {
            guard let entity = try itemRepository.item(with: display.id) else { return }
            let snapshot = itemRepository.makeSnapshot(from: entity)
            try itemRepository.delete(entity)
            scheduleUndo(for: snapshot)
            refresh()
            haptics.mediumImpact()
        } catch {
            errorMessage = "Failed to delete item"
            haptics.error()
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
    func makeDisplays(from items: [WantedItemEntity]) -> [WantedItemDisplay] {
        items.map { entity in
            let tags = entity.tags.isEmpty ? (entity.productText.map { [$0] } ?? []) : entity.tags
            let basePrice = entity.price.decimalValue
            return WantedItemDisplay(id: entity.id,
                                     title: entity.title,
                                     price: basePrice,
                                     priceWithTax: includeTax(on: basePrice),
                                     notes: entity.notes,
                                     tags: tags,
                                     productURL: entity.productURL,
                                     imagePath: entity.imagePath,
                                     status: entity.status,
                                     createdAt: entity.createdAt)
        }
    }

    func apply(displays: [WantedItemDisplay]) {
        let newTotal = displays.reduce(.zero) { $0 + $1.priceWithTax }
        let newCount = displays.count
        let newAverage = newCount > 0 ? newTotal / Decimal(newCount) : .zero

        // Only update if values changed to avoid unnecessary UI updates
        if items.count != displays.count || items != displays {
            self.items = displays
        }
        if totalSaved != newTotal {
            self.totalSaved = newTotal
        }
        if itemCount != newCount {
            self.itemCount = newCount
        }
        if averageItemPrice != newAverage {
            self.averageItemPrice = newAverage
        }
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
                                         priceWithTax: includeTax(on: snapshot.price),
                                         notes: snapshot.notes,
                                         tags: snapshot.tags,
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

    func includeTax(on amount: Decimal) -> Decimal {
        guard taxRate > 0 else { return amount }
        var result = amount
        let multiplier = Decimal(1) + taxRate
        result *= multiplier
        return result
    }

    func reloadTaxRate() throws {
        let settings = try settingsRepository.loadAppSettings()
        taxRate = settings.taxRate.decimalValue
    }

    func updateYearlyTotals(currentMonthDisplays: [WantedItemDisplay]) throws {
        let summaries = try monthRepository.summaries()
        var summaryMap: [String: MonthSummaryEntity] = [:]
        for summary in summaries {
            if summaryMap[summary.monthKey] == nil {
                summaryMap[summary.monthKey] = summary
            }
        }
        var points: [MonthlyTrendPoint] = []
        let now = Date()

        for offset in (0..<12).reversed() {
            guard let date = calendar.date(byAdding: .month, value: -offset, to: now) else { continue }
            let key = itemRepository.monthKey(for: date)
            let baseTotal: Decimal
            if key == itemRepository.currentMonthKey {
                baseTotal = currentMonthDisplays.reduce(.zero) { $0 + $1.price }
            } else if let summary = summaryMap[key] {
                baseTotal = summary.totalSaved.decimalValue
            } else {
                baseTotal = .zero
            }
            let totalWithTax = includeTax(on: baseTotal)
            guard let normalizedDate = calendar.date(from: calendar.dateComponents([.year, .month], from: date)) else { continue }
            points.append(MonthlyTrendPoint(id: key, monthKey: key, date: normalizedDate, total: totalWithTax))
        }
        yearlyTotals = points
    }
}

extension DashboardViewModel {
    struct MonthlyTrendPoint: Identifiable {
        let id: String
        let monthKey: String
        let date: Date
        let total: Decimal
    }
}
