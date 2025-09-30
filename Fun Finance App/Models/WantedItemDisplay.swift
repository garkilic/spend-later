import UIKit

struct WantedItemDisplay: Identifiable {
    let id: UUID
    let title: String
    let price: Decimal
    let notes: String?
    let productText: String?
    let productURL: String?
    let imagePath: String
    let status: ItemStatus
    let createdAt: Date
}
