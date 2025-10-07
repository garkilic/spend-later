import CoreData

final class PersistenceController {
    static let shared = PersistenceController()
    static let preview: PersistenceController = {
        let controller = PersistenceController(inMemory: true)
        PreviewSeeder.seed(into: controller.container.viewContext)
        return controller
    }()

    // Cache the model to avoid rebuilding on every init
    private static let cachedModel: NSManagedObjectModel = {
        return makeModel(for: ModelVersion.current)
    }()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "SpendLaterModel", managedObjectModel: Self.cachedModel)

        if inMemory {
            let description = NSPersistentStoreDescription()
            description.type = NSInMemoryStoreType
            description.shouldMigrateStoreAutomatically = true
            description.shouldInferMappingModelAutomatically = true
            container.persistentStoreDescriptions = [description]
        } else {
            let urls = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            let storeURL = urls[0].appendingPathComponent("SpendLater.sqlite")

            // Ensure directory exists
            let storeDirectory = storeURL.deletingLastPathComponent()
            if !FileManager.default.fileExists(atPath: storeDirectory.path) {
                try? FileManager.default.createDirectory(at: storeDirectory, withIntermediateDirectories: true, attributes: nil)
            }

            let description = NSPersistentStoreDescription(url: storeURL)

            // One-time migration: Remove persistent history tracking to fix read-only mode
            let migrationKey = "didMigratePersistentHistory_v1"
            let needsMigration = !UserDefaults.standard.bool(forKey: migrationKey) &&
                                 FileManager.default.fileExists(atPath: storeURL.path)

            if needsMigration {
                print("CoreData: Migrating store to remove persistent history tracking...")
                // Remove old store files to start fresh
                try? FileManager.default.removeItem(at: storeURL)
                try? FileManager.default.removeItem(at: storeURL.deletingPathExtension().appendingPathExtension("sqlite-shm"))
                try? FileManager.default.removeItem(at: storeURL.deletingPathExtension().appendingPathExtension("sqlite-wal"))
                UserDefaults.standard.set(true, forKey: migrationKey)
            }

            // Disable persistent history tracking for better performance (single-device app)
            description.setOption(false as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            description.shouldMigrateStoreAutomatically = true
            description.shouldInferMappingModelAutomatically = true
            container.persistentStoreDescriptions = [description]
        }

        // Load store (blocking but necessary for Core Data initialization)
        var loadError: Error?
        container.loadPersistentStores { description, error in
            if let error {
                loadError = error
            }
        }

        if let loadError {
            fatalError("Core Data failed to load: \(loadError.localizedDescription)")
        }

        // Optimize view context for performance - especially on device
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        container.viewContext.automaticallyMergesChangesFromParent = false // Reduce overhead
        container.viewContext.undoManager = nil
        container.viewContext.shouldDeleteInaccessibleFaults = true
        container.viewContext.stalenessInterval = -1 // No automatic refreshing
    }
}

private enum ModelVersion: String {
    case v1 = "SpendLaterModelV1"
    case v2 = "SpendLaterModelV2"
    case v3 = "SpendLaterModelV3"
    case v4 = "SpendLaterModelV4"

    static var current: ModelVersion { .v4 }
}

private extension PersistenceController {
    static func makeModel(for version: ModelVersion) -> NSManagedObjectModel {
        let model = NSManagedObjectModel()
        model.versionIdentifiers = [version.rawValue]

        let wantedItem = NSEntityDescription()
        wantedItem.name = "WantedItem"
        wantedItem.managedObjectClassName = NSStringFromClass(WantedItemEntity.self)

        let monthSummary = NSEntityDescription()
        monthSummary.name = "MonthSummary"
        monthSummary.managedObjectClassName = NSStringFromClass(MonthSummaryEntity.self)

        let appSettings = NSEntityDescription()
        appSettings.name = "AppSettings"
        appSettings.managedObjectClassName = NSStringFromClass(AppSettingsEntity.self)

        let wantedItemProps = makeWantedItemAttributes(for: version)
        let monthSummaryProps = makeMonthSummaryAttributes()
        let relationshipPair = makeRelationships(wantedItem: wantedItem, monthSummary: monthSummary)

        wantedItem.properties = wantedItemProps + [relationshipPair.inverse]
        monthSummary.properties = monthSummaryProps + [relationshipPair.forward]
        appSettings.properties = makeAppSettingsAttributes()

        model.entities = [wantedItem, monthSummary, appSettings]
        return model
    }

    static func makeWantedItemAttributes(for version: ModelVersion) -> [NSPropertyDescription] {
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

        if version != .v1 {
            let productURL = NSAttributeDescription()
            productURL.name = "productURL"
            productURL.attributeType = .stringAttributeType
            productURL.isOptional = true
            properties.append(productURL)
        }

        if version == .v3 || version == .v4 {
            let tagsRaw = NSAttributeDescription()
            tagsRaw.name = "tagsRaw"
            tagsRaw.attributeType = .stringAttributeType
            tagsRaw.isOptional = true
            properties.append(tagsRaw)
        }

        if version == .v4 {
            let actuallyPurchased = NSAttributeDescription()
            actuallyPurchased.name = "actuallyPurchased"
            actuallyPurchased.attributeType = .booleanAttributeType
            actuallyPurchased.isOptional = false
            actuallyPurchased.defaultValue = false
            properties.append(actuallyPurchased)
        }

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

        let taxRate = NSAttributeDescription()
        taxRate.name = "taxRate"
        taxRate.attributeType = .decimalAttributeType
        taxRate.isOptional = false
        taxRate.defaultValue = NSDecimalNumber.zero
        properties.append(taxRate)

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
