import Foundation

struct MonthSummaryDisplay: Identifiable, Hashable {
    let id: UUID
    let monthKey: String
    let totalSaved: Decimal
    let itemCount: Int
    let winnerItemId: UUID?
    let closedAt: Date?
}
