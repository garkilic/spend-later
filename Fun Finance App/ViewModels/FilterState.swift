import Foundation
import Combine

enum FilterPeriod: String, CaseIterable, Codable {
    case week = "Week"
    case month = "Month"
    case year = "Year"
    case all = "All"

    var days: Int? {
        switch self {
        case .week: return 7
        case .month: return 30
        case .year: return 365
        case .all: return nil
        }
    }
}

@MainActor
final class FilterState: ObservableObject {
    @Published var selectedPeriod: FilterPeriod {
        didSet {
            UserDefaults.standard.set(selectedPeriod.rawValue, forKey: "selectedPeriod")
        }
    }

    init() {
        if let saved = UserDefaults.standard.string(forKey: "selectedPeriod"),
           let period = FilterPeriod(rawValue: saved) {
            self.selectedPeriod = period
        } else {
            self.selectedPeriod = .month
        }
    }

    func dateRange(from date: Date = Date()) -> (start: Date, end: Date)? {
        let calendar = Calendar.current

        switch selectedPeriod {
        case .week:
            let weekAgo = calendar.date(byAdding: .day, value: -7, to: date) ?? date
            return (weekAgo, date)

        case .month:
            let monthAgo = calendar.date(byAdding: .month, value: -1, to: date) ?? date
            return (monthAgo, date)

        case .year:
            let yearAgo = calendar.date(byAdding: .year, value: -1, to: date) ?? date
            return (yearAgo, date)

        case .all:
            return nil
        }
    }
}
