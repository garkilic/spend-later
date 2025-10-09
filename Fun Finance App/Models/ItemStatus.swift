import Foundation

enum ItemStatus: String, CaseIterable {
    case saved      // Default: item uploaded/saved
    case bought     // User manually bought this item
    case won        // Item won the monthly spin
}
