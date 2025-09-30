import CoreData

final class PersistenceController {
    static let shared = PersistenceController()
    static let preview: PersistenceController = {
        let controller = PersistenceController(inMemory: true)
        PreviewSeeder.seed(into: controller.container.viewContext)
        return controller
    }()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        let model = PersistenceController.makeModel()
        container = NSPersistentContainer(name: "SpendLaterModel", managedObjectModel: model)

        if inMemory {
            let description = NSPersistentStoreDescription()
            description.type = NSInMemoryStoreType
            container.persistentStoreDescriptions = [description]
        } else {
            let urls = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            let storeURL = urls[0].appendingPathComponent("SpendLater.sqlite")
            let description = NSPersistentStoreDescription(url: storeURL)
            description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
            container.persistentStoreDescriptions = [description]
        }

        container.loadPersistentStores { _, error in
            if let error {
                fatalError("Unresolved Core Data error: \(error)")
            }
        }

        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
}

private extension PersistenceController {
    static func makeModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()

        let wantedItem = NSEntityDescription()
        wantedItem.name = "WantedItem"
        wantedItem.managedObjectClassName = NSStringFromClass(WantedItemEntity.self)

        let monthSummary = NSEntityDescription()
        monthSummary.name = "MonthSummary"
        monthSummary.managedObjectClassName = NSStringFromClass(MonthSummaryEntity.self)

        let appSettings = NSEntityDescription()
        appSettings.name = "AppSettings"
        appSettings.managedObjectClassName = NSStringFromClass(AppSettingsEntity.self)

        let wantedItemProps = makeWantedItemAttributes()
        let monthSummaryProps = makeMonthSummaryAttributes()
        let relationshipPair = makeRelationships(wantedItem: wantedItem, monthSummary: monthSummary)

        wantedItem.properties = wantedItemProps + [relationshipPair.inverse]
        monthSummary.properties = monthSummaryProps + [relationshipPair.forward]
        appSettings.properties = makeAppSettingsAttributes()

        model.entities = [wantedItem, monthSummary, appSettings]
        return model
    }

    static func makeWantedItemAttributes() -> [NSPropertyDescription] {
        var properties: [NSPropertyDescription] = []

        let id = NSAttributeDescription()
        id.name = "id"
        id.attributeType = .UUIDAttributeType
        id.isOptional = false
        properties.append(id)

        let title = NSAttributeDescription()
        title.name = "title"
        title.attributeType = .stringAttributeType
        title.isOptional = false
        properties.append(title)

        let price = NSAttributeDescription()
        price.name = "price"
        price.attributeType = .decimalAttributeType
        price.isOptional = false
        properties.append(price)

        let notes = NSAttributeDescription()
        notes.name = "notes"
        notes.attributeType = .stringAttributeType
        notes.isOptional = true
        properties.append(notes)

        let productText = NSAttributeDescription()
        productText.name = "productText"
        productText.attributeType = .stringAttributeType
        productText.isOptional = true
        properties.append(productText)

        let imagePath = NSAttributeDescription()
        imagePath.name = "imagePath"
        imagePath.attributeType = .stringAttributeType
        imagePath.isOptional = false
        properties.append(imagePath)

        let createdAt = NSAttributeDescription()
        createdAt.name = "createdAt"
        createdAt.attributeType = .dateAttributeType
        createdAt.isOptional = false
        properties.append(createdAt)

        let monthKey = NSAttributeDescription()
        monthKey.name = "monthKey"
        monthKey.attributeType = .stringAttributeType
        monthKey.isOptional = false
        properties.append(monthKey)

        let statusRaw = NSAttributeDescription()
        statusRaw.name = "statusRaw"
        statusRaw.attributeType = .stringAttributeType
        statusRaw.isOptional = false
        statusRaw.defaultValue = ItemStatus.active.rawValue
        properties.append(statusRaw)

        return properties
    }

    static func makeMonthSummaryAttributes() -> [NSPropertyDescription] {
        var properties: [NSPropertyDescription] = []

        let id = NSAttributeDescription()
        id.name = "id"
        id.attributeType = .UUIDAttributeType
        id.isOptional = false
        properties.append(id)

        let monthKey = NSAttributeDescription()
        monthKey.name = "monthKey"
        monthKey.attributeType = .stringAttributeType
        monthKey.isOptional = false
        properties.append(monthKey)

        let totalSaved = NSAttributeDescription()
        totalSaved.name = "totalSaved"
        totalSaved.attributeType = .decimalAttributeType
        totalSaved.isOptional = false
        totalSaved.defaultValue = NSDecimalNumber.zero
        properties.append(totalSaved)

        let itemCount = NSAttributeDescription()
        itemCount.name = "itemCount"
        itemCount.attributeType = .integer32AttributeType
        itemCount.isOptional = false
        itemCount.defaultValue = 0
        properties.append(itemCount)

        let winnerItemId = NSAttributeDescription()
        winnerItemId.name = "winnerItemId"
        winnerItemId.attributeType = .UUIDAttributeType
        winnerItemId.isOptional = true
        properties.append(winnerItemId)

        let closedAt = NSAttributeDescription()
        closedAt.name = "closedAt"
        closedAt.attributeType = .dateAttributeType
        closedAt.isOptional = true
        properties.append(closedAt)

        return properties
    }

    static func makeRelationships(wantedItem: NSEntityDescription, monthSummary: NSEntityDescription) -> (forward: NSRelationshipDescription, inverse: NSRelationshipDescription) {
        let forward = NSRelationshipDescription()
        forward.name = "items"
        forward.destinationEntity = wantedItem
        forward.minCount = 0
        forward.maxCount = 0
        forward.deleteRule = .nullifyDeleteRule
        forward.isOrdered = false

        let inverse = NSRelationshipDescription()
        inverse.name = "summary"
        inverse.destinationEntity = monthSummary
        inverse.minCount = 0
        inverse.maxCount = 1
        inverse.deleteRule = .nullifyDeleteRule

        forward.inverseRelationship = inverse
        inverse.inverseRelationship = forward

        return (forward, inverse)
    }

    static func makeAppSettingsAttributes() -> [NSPropertyDescription] {
        var properties: [NSPropertyDescription] = []

        let id = NSAttributeDescription()
        id.name = "id"
        id.attributeType = .UUIDAttributeType
        id.isOptional = false
        properties.append(id)

        let currencyCode = NSAttributeDescription()
        currencyCode.name = "currencyCode"
        currencyCode.attributeType = .stringAttributeType
        currencyCode.isOptional = false
        currencyCode.defaultValue = "USD"
        properties.append(currencyCode)

        let weeklyReminderEnabled = NSAttributeDescription()
        weeklyReminderEnabled.name = "weeklyReminderEnabled"
        weeklyReminderEnabled.attributeType = .booleanAttributeType
        weeklyReminderEnabled.isOptional = false
        weeklyReminderEnabled.defaultValue = true
        properties.append(weeklyReminderEnabled)

        let monthlyReminderEnabled = NSAttributeDescription()
        monthlyReminderEnabled.name = "monthlyReminderEnabled"
        monthlyReminderEnabled.attributeType = .booleanAttributeType
        monthlyReminderEnabled.isOptional = false
        monthlyReminderEnabled.defaultValue = true
        properties.append(monthlyReminderEnabled)

        let passcodeEnabled = NSAttributeDescription()
        passcodeEnabled.name = "passcodeEnabled"
        passcodeEnabled.attributeType = .booleanAttributeType
        passcodeEnabled.isOptional = false
        passcodeEnabled.defaultValue = false
        properties.append(passcodeEnabled)

        let passcodeKeychainKey = NSAttributeDescription()
        passcodeKeychainKey.name = "passcodeKeychainKey"
        passcodeKeychainKey.attributeType = .stringAttributeType
        passcodeKeychainKey.isOptional = true
        properties.append(passcodeKeychainKey)

        return properties
    }
}
