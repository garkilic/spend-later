import CoreData
import CloudKit

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

    let container: NSPersistentCloudKitContainer

    init(inMemory: Bool = false) {
        container = NSPersistentCloudKitContainer(name: "SpendLaterModel", managedObjectModel: Self.cachedModel)

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

            // Check if user is signed into iCloud
            let isSignedIntoiCloud = FileManager.default.ubiquityIdentityToken != nil

            if isSignedIntoiCloud {
                print("✅ iCloud account detected - enabling CloudKit sync")
                print("📦 CloudKit Container: iCloud.com.funfinance.spendlater")

                // Enable CloudKit sync
                description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
                    containerIdentifier: "iCloud.com.funfinance.spendlater"
                )

                // Enable persistent history tracking - required for CloudKit sync
                description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)

                // Enable remote change notifications
                description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
            } else {
                print("⚠️ No iCloud account detected")
                print("⚠️ CloudKit sync is DISABLED - data will be LOCAL ONLY")
                print("⚠️ User should sign in to iCloud in Settings to enable data sync")
                // CloudKit will be disabled, app will work with local storage only
            }

            description.shouldMigrateStoreAutomatically = true
            description.shouldInferMappingModelAutomatically = true
            container.persistentStoreDescriptions = [description]
        }

        // Load store synchronously - must block to ensure database is ready
        var loadError: Error?
        container.loadPersistentStores { description, error in
            if let error {
                loadError = error
            } else {
                print("✅ Persistent store loaded successfully")
                if description.cloudKitContainerOptions != nil {
                    print("✅ CloudKit sync is enabled")
                } else {
                    print("ℹ️ CloudKit sync is disabled (local storage only)")
                }
            }
        }

        if let loadError {
            print("❌ Core Data load error: \(loadError)")
            print("❌ Error details: \(loadError.localizedDescription)")
            if let nsError = loadError as NSError? {
                print("❌ Error domain: \(nsError.domain)")
                print("❌ Error code: \(nsError.code)")
                print("❌ Error userInfo: \(nsError.userInfo)")

                // Provide specific guidance for CloudKit errors
                if nsError.domain == "NSCloudKitErrorDomain" || nsError.code == 134400 {
                    print("⚠️ CloudKit Configuration Issue:")
                    print("   - Verify iCloud capability is enabled in Xcode")
                    print("   - Ensure CloudKit container 'iCloud.com.funfinance.spendlater' exists")
                    print("   - Check that the device is signed into iCloud")
                    print("   - The app will attempt to continue with local storage only")
                }
            }
            fatalError("Core Data failed to load: \(loadError.localizedDescription)")
        }

        // Configure view context for CloudKit sync (view context is on main queue by default)
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        container.viewContext.automaticallyMergesChangesFromParent = true // Required for CloudKit sync
        container.viewContext.undoManager = nil
        container.viewContext.shouldDeleteInaccessibleFaults = true

        // Watch for remote changes from CloudKit - explicitly on main queue
        NotificationCenter.default.addObserver(
            forName: .NSPersistentStoreRemoteChange,
            object: container.persistentStoreCoordinator,
            queue: OperationQueue.main // Explicitly use main queue
        ) { [weak self] _ in
            guard let self else { return }
            // Refresh all objects to pick up remote changes - already on main queue
            self.container.viewContext.refreshAllObjects()
        }
    }
}

private enum ModelVersion: String {
    case v1 = "SpendLaterModelV1"
    case v2 = "SpendLaterModelV2"
    case v3 = "SpendLaterModelV3"
    case v4 = "SpendLaterModelV4"
    case v5 = "SpendLaterModelV5" // CloudKit-compatible model
    case v6 = "SpendLaterModelV6" // Added imageData for CloudKit image sync

    static var current: ModelVersion { .v6 }
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
        id.isOptional = true // CloudKit requires optional or default value
        properties.append(id)

        let title = NSAttributeDescription()
        title.name = "title"
        title.attributeType = .stringAttributeType
        title.isOptional = false
        title.defaultValue = "" // CloudKit requires default for non-optional
        properties.append(title)

        let price = NSAttributeDescription()
        price.name = "price"
        price.attributeType = .decimalAttributeType
        price.isOptional = false
        price.defaultValue = NSDecimalNumber.zero // CloudKit requires default for non-optional
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

        if version != .v1 { // v2, v3, v4, v5 all have productURL
            let productURL = NSAttributeDescription()
            productURL.name = "productURL"
            productURL.attributeType = .stringAttributeType
            productURL.isOptional = true
            properties.append(productURL)
        }

        if version == .v3 || version == .v4 || version == .v5 || version == .v6 {
            let tagsRaw = NSAttributeDescription()
            tagsRaw.name = "tagsRaw"
            tagsRaw.attributeType = .stringAttributeType
            tagsRaw.isOptional = true
            properties.append(tagsRaw)
        }

        if version == .v4 || version == .v5 || version == .v6 {
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
        imagePath.defaultValue = "" // CloudKit requires default for non-optional
        properties.append(imagePath)

        // v6 adds imageData for CloudKit sync
        if version == .v6 {
            let imageData = NSAttributeDescription()
            imageData.name = "imageData"
            imageData.attributeType = .binaryDataAttributeType
            imageData.isOptional = true
            imageData.allowsExternalBinaryDataStorage = true // Store large images externally
            properties.append(imageData)
        }

        let createdAt = NSAttributeDescription()
        createdAt.name = "createdAt"
        createdAt.attributeType = .dateAttributeType
        createdAt.isOptional = false
        createdAt.defaultValue = Date() // CloudKit requires default for non-optional
        properties.append(createdAt)

        let monthKey = NSAttributeDescription()
        monthKey.name = "monthKey"
        monthKey.attributeType = .stringAttributeType
        monthKey.isOptional = false
        monthKey.defaultValue = "" // CloudKit requires default for non-optional
        properties.append(monthKey)

        let statusRaw = NSAttributeDescription()
        statusRaw.name = "statusRaw"
        statusRaw.attributeType = .stringAttributeType
        statusRaw.isOptional = false
        statusRaw.defaultValue = ItemStatus.saved.rawValue
        properties.append(statusRaw)

        return properties
    }

    static func makeMonthSummaryAttributes() -> [NSPropertyDescription] {
        var properties: [NSPropertyDescription] = []

        let id = NSAttributeDescription()
        id.name = "id"
        id.attributeType = .UUIDAttributeType
        id.isOptional = true // CloudKit requires optional or default value
        properties.append(id)

        let monthKey = NSAttributeDescription()
        monthKey.name = "monthKey"
        monthKey.attributeType = .stringAttributeType
        monthKey.isOptional = false
        monthKey.defaultValue = "" // CloudKit requires default for non-optional
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
        id.isOptional = true // CloudKit requires optional or default value
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

        let onboardingCompleted = NSAttributeDescription()
        onboardingCompleted.name = "onboardingCompleted"
        onboardingCompleted.attributeType = .booleanAttributeType
        onboardingCompleted.isOptional = false
        onboardingCompleted.defaultValue = false
        properties.append(onboardingCompleted)

        return properties
    }
}
