import Foundation

final class RolloverService {
    private let monthRepository: MonthRepositoryProtocol
    private let itemRepository: ItemRepositoryProtocol
    private let calendar: Calendar

    init(monthRepository: MonthRepositoryProtocol,
         itemRepository: ItemRepositoryProtocol,
         calendar: Calendar = .current) {
        self.monthRepository = monthRepository
        self.itemRepository = itemRepository
        self.calendar = calendar
    }

    func evaluateIfNeeded(at date: Date = Date()) throws -> MonthSummaryEntity? {
        _ = try monthRepository.rollIfNeeded(currentDate: date)
        guard let previousDate = calendar.date(byAdding: .month, value: -1, to: date) else { return nil }
        let monthKey = itemRepository.monthKey(for: previousDate)
        guard let summary = try monthRepository.summary(for: monthKey), summary.winnerItemId == nil else { return nil }
        return summary
    }
}
