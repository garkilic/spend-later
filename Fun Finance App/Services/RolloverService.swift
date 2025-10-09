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

    /// Returns the number of days remaining in the claim window, or nil if not in window
    func daysRemainingInWindow(at date: Date = Date()) -> Int? {
        guard isInClaimWindow(date: date) else { return nil }

        let components = calendar.dateComponents([.day], from: date)
        guard let day = components.day else { return nil }

        // If we're on 1st-5th, count down to 5th
        if day >= 1 && day <= 5 {
            return 5 - day + 1  // e.g., on 3rd: 5-3+1 = 3 days remaining
        }

        // If we're on last day of month, we have 6 more days (rest of today + 1st-5th)
        guard let range = calendar.range(of: .day, in: .month, for: date) else { return nil }
        let lastDay = range.upperBound - 1
        if day == lastDay {
            return 6  // Last day + 5 days in next month
        }

        return nil
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
