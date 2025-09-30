import Foundation

enum MonthFormatter {
    static func displayName(for monthKey: String) -> String {
        let components = monthKey.split(separator: ",")
        guard components.count == 2,
              let year = Int(components[0]),
              let month = Int(components[1]) else { return monthKey }
        var dateComponents = DateComponents()
        dateComponents.year = year
        dateComponents.month = month
        let calendar = Calendar.current
        if let date = calendar.date(from: dateComponents) {
            let formatter = DateFormatter()
            formatter.dateFormat = "LLLL yyyy"
            return formatter.string(from: date)
        }
        return monthKey
    }
}
