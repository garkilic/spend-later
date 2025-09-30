import CoreData

enum PreviewSeeder {
    static func seed(into context: NSManagedObjectContext) {
        let calendar = Calendar.current
        let now = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy,MM"
        let currentKey = formatter.string(from: now)
        let lastMonthKey: String
        if let lastMonth = calendar.date(byAdding: .month, value: -1, to: now) {
            lastMonthKey = formatter.string(from: lastMonth)
        } else {
            lastMonthKey = currentKey
        }

        for index in 0..<3 {
            let item = WantedItemEntity(context: context)
            item.id = UUID()
            item.title = "Preview Item \(index + 1)"
            item.price = NSDecimalNumber(value: 29.99 + Double(index) * 10)
            item.notes = "Quick note \(index + 1)"
            item.productText = "Product ref #\(index + 1)"
            item.productURL = nil
            item.imagePath = ""
            item.createdAt = now
            item.monthKey = currentKey
            item.statusRaw = ItemStatus.active.rawValue
        }

        let summary = MonthSummaryEntity(context: context)
        summary.id = UUID()
        summary.monthKey = lastMonthKey
        summary.totalSaved = NSDecimalNumber(value: 180.5)
        summary.itemCount = 4
        summary.winnerItemId = nil
        summary.closedAt = nil

        let settings = AppSettingsEntity(context: context)
        settings.id = UUID()
        settings.currencyCode = "USD"
        settings.weeklyReminderEnabled = true
        settings.monthlyReminderEnabled = true
        settings.passcodeEnabled = false
        settings.passcodeKeychainKey = nil

        try? context.save()
    }
}
