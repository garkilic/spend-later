import UIKit

struct WantedItemDisplay: Identifiable {
    let id: UUID
    let title: String
    let price: Decimal
    let priceWithTax: Decimal
    let notes: String?
    let tags: [String]
    let productURL: String?
    let imagePath: String
    let imageData: Data? // CloudKit-synced image data (CKAsset)
    let status: ItemStatus
    let createdAt: Date

    var isBought: Bool {
        return status == .bought
    }
}

extension WantedItemDisplay: Hashable {
    static func == (lhs: WantedItemDisplay, rhs: WantedItemDisplay) -> Bool {
        lhs.id == rhs.id &&
        lhs.title == rhs.title &&
        lhs.price == rhs.price &&
        lhs.notes == rhs.notes &&
        lhs.tags == rhs.tags &&
        lhs.productURL == rhs.productURL &&
        lhs.status == rhs.status
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
