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
        // Check if we're in the claim window (last day of month -> 5th of next month)
        guard isInClaimWindow(date: date) else { return nil }

        // Get the month key based on where we are in the claim window
        let monthKey = monthKeyForClaimWindow(date: date)
        guard let summary = try monthRepository.summary(for: monthKey) else { return nil }

        // Show if winner not yet selected
        guard summary.winnerItemId == nil else { return nil }

        return summary
    }

    private func isInClaimWindow(date: Date) -> Bool {
        let components = calendar.dateComponents([.day], from: date)
        guard let day = components.day else { return false }

        // 1st-5th of month (grace period for previous month)
        if day >= 1 && day <= 5 { return true }

        // Last day of month
        guard let range = calendar.range(of: .day, in: .month, for: date) else { return false }
        let lastDay = range.upperBound - 1
        return day == lastDay
    }

    private func monthKeyForClaimWindow(date: Date) -> String {
        let components = calendar.dateComponents([.day], from: date)
        guard let day = components.day else { return itemRepository.monthKey(for: date) }

        // If we're 1st-5th, this is for previous month's reward
        if day >= 1 && day <= 5 {
            guard let previousMonth = calendar.date(byAdding: .month, value: -1, to: date) else {
                return itemRepository.monthKey(for: date)
            }
            return itemRepository.monthKey(for: previousMonth)
        }

        // Otherwise (last day of month), this is for current month
        return itemRepository.monthKey(for: date)
    }
}
