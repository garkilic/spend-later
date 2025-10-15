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

            // Check if we need to reset due to schema upgrade
            // This should ONLY happen when migrating from old v5 schema, not on every reinstall
            let schemaVersionKey = "CoreDataSchemaVersion"
            let currentSchemaVersion = "v6_imagePath_only"
            let savedSchemaVersion = UserDefaults.standard.string(forKey: schemaVersionKey)
            let localStoreExists = FileManager.default.fileExists(atPath: storeURL.path)

            // Only reset if:
            // 1. We have a saved version that's different from current (upgrading from old version)
            // 2. AND local store exists (we have old data to clean up)
            // Do NOT reset on fresh installs (savedSchemaVersion == nil && !localStoreExists)
            if savedSchemaVersion != currentSchemaVersion && localStoreExists {
                print("🔄 Schema version changed from \(savedSchemaVersion ?? "unknown") to \(currentSchemaVersion)")
                print("🔄 Local store exists - migrating old data")
                print("🗑️ Resetting local store and CloudKit data to prevent conflicts...")

                // Delete local SQLite files
                let fileManager = FileManager.default
                try? fileManager.removeItem(at: storeURL)
                try? fileManager.removeItem(at: storeURL.appendingPathExtension("sqlite-shm"))
                try? fileManager.removeItem(at: storeURL.appendingPathExtension("sqlite-wal"))
                print("✅ Deleted old SQLite store")

                // Schedule CloudKit zone reset after store loads
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                    self?.resetCloudKitZone()
                }

                print("✅ Local store reset complete")
            } else if savedSchemaVersion != currentSchemaVersion && !localStoreExists {
                // Fresh install - no local store, so just mark schema as current
                // CloudKit data (if any) will sync down normally
                print("ℹ️ Fresh install detected - skipping reset, will sync from CloudKit")
            }

            // Always update schema version marker
            UserDefaults.standard.set(currentSchemaVersion, forKey: schemaVersionKey)

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

                // Detect CloudKit environment
                #if DEBUG
                print("🔧 CloudKit Environment: DEVELOPMENT (Debug build)")
                #else
                print("🚀 CloudKit Environment: PRODUCTION (Release/TestFlight build)")
                print("⚠️ IMPORTANT: Production CloudKit must have v6 schema deployed!")
                print("⚠️ If sync fails, deploy schema from Development to Production in CloudKit Dashboard")
                #endif

                // TEMPORARY: Uncomment below to use Development environment in TestFlight for testing
                // let options = NSPersistentCloudKitContainerOptions(containerIdentifier: "iCloud.com.funfinance.spendlater")
                // options.databaseScope = .private
                // print("⚠️ FORCING DEVELOPMENT ENVIRONMENT - FOR TESTING ONLY!")
                // description.cloudKitContainerOptions = options

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
                print("   Store URL: \(description.url?.path ?? "unknown")")
                if description.cloudKitContainerOptions != nil {
                    print("✅ CloudKit sync is enabled")
                    print("   Container: \(description.cloudKitContainerOptions?.containerIdentifier ?? "unknown")")
                } else {
                    print("ℹ️ CloudKit sync is disabled (local storage only)")
                }
            }
        }

        if let loadError {
            print("❌ Core Data load error: \(loadError)")
            print("❌ Error details: \(loadError.localizedDescription)")
            let nsError = loadError as NSError
            print("❌ Error domain: \(nsError.domain)")
            print("❌ Error code: \(nsError.code)")
            print("❌ Error userInfo: \(nsError.userInfo)")

            // Check if this is a CloudKit-specific error that we can work around
            if nsError.domain == "NSCloudKitErrorDomain" || nsError.code == 134400 || nsError.code == 134060 {
                print("⚠️ CloudKit Configuration Issue - attempting LOCAL-ONLY fallback")
                print("⚠️ Data will be stored locally but NOT sync to iCloud")
                print("⚠️ Fix: Deploy v6 schema to Production CloudKit")

                // Retry without CloudKit - recalculate store URL
                let urls = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
                let fallbackStoreURL = urls[0].appendingPathComponent("SpendLater.sqlite")
                let description = NSPersistentStoreDescription(url: fallbackStoreURL)
                description.cloudKitContainerOptions = nil // Disable CloudKit
                description.shouldMigrateStoreAutomatically = true
                description.shouldInferMappingModelAutomatically = true
                container.persistentStoreDescriptions = [description]

                var retryError: Error?
                container.loadPersistentStores { description, error in
                    if let error {
                        retryError = error
                    } else {
                        print("✅ Persistent store loaded in LOCAL-ONLY mode")
                        print("⚠️ CloudKit sync is DISABLED due to schema mismatch")
                    }
                }

                if retryError != nil {
                    fatalError("Core Data failed even in local-only mode: \(retryError!.localizedDescription)")
                }
            } else {
                fatalError("Core Data failed to load: \(loadError.localizedDescription)")
            }
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
            print("📥 CloudKit: Remote changes detected")
            // Refresh all objects to pick up remote changes - already on main queue
            self.container.viewContext.refreshAllObjects()
        }

        // Watch for CloudKit sync events to debug upload/download issues
        NotificationCenter.default.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification,
            object: container,
            queue: OperationQueue.main
        ) { notification in
            if let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey] as? NSPersistentCloudKitContainer.Event {
                let eventType = event.type == .setup ? "Setup" : event.type == .import ? "Import" : event.type == .export ? "Export" : "Unknown"

                if let error = event.error {
                    print("❌ CloudKit \(eventType) error: \(error.localizedDescription)")
                    if let nsError = error as NSError? {
                        print("   Domain: \(nsError.domain), Code: \(nsError.code)")
                        print("   UserInfo: \(nsError.userInfo)")

                        // Check for schema mismatch errors
                        if nsError.code == 134060 || nsError.domain == "CKErrorDomain" {
                            print("   ⚠️ This may be a SCHEMA MISMATCH error!")
                            print("   ⚠️ The CloudKit Production schema may not match the app's model")
                            print("   ⚠️ ACTION REQUIRED: Deploy schema from Development to Production")
                            print("   ⚠️ Go to: https://icloud.developer.apple.com/dashboard/")
                        }
                    }
                } else if event.endDate != nil {
                    print("✅ CloudKit \(eventType) completed successfully")
                } else {
                    print("🔄 CloudKit \(eventType) in progress...")
                }
            }
        }
    }

    /// Resets CloudKit zone by deleting all records to resolve conflicts from old schema
    func resetCloudKitZone() {
        print("🗑️ Starting CloudKit zone reset...")

        Task {
            do {
                let container = CKContainer(identifier: "iCloud.com.funfinance.spendlater")
                let database = container.privateCloudDatabase

                // Fetch and delete all record types
                let recordTypes = ["CD_WantedItem", "CD_MonthSummary", "CD_AppSettings"]

                for recordType in recordTypes {
                    print("🔍 Fetching \(recordType) records...")
                    let query = CKQuery(recordType: recordType, predicate: NSPredicate(value: true))

                    do {
                        let (matchResults, _) = try await database.records(matching: query)

                        var recordIDsToDelete: [CKRecord.ID] = []
                        for (recordID, result) in matchResults {
                            switch result {
                            case .success:
                                recordIDsToDelete.append(recordID)
                            case .failure(let error):
                                print("⚠️ Error fetching record \(recordID): \(error)")
                            }
                        }

                        if !recordIDsToDelete.isEmpty {
                            print("🗑️ Deleting \(recordIDsToDelete.count) \(recordType) records...")
                            let (deleteResults, _) = try await database.modifyRecords(saving: [], deleting: recordIDsToDelete)

                            var deletedCount = 0
                            for (recordID, result) in deleteResults {
                                switch result {
                                case .success:
                                    deletedCount += 1
                                case .failure(let error):
                                    print("⚠️ Error deleting record \(recordID): \(error)")
                                }
                            }
                            print("✅ Deleted \(deletedCount) \(recordType) records")
                        } else {
                            print("ℹ️ No \(recordType) records to delete")
                        }
                    } catch {
                        print("⚠️ Error processing \(recordType): \(error)")
                    }
                }

                print("✅ CloudKit zone reset complete - ready for fresh sync")
            } catch {
                print("❌ CloudKit reset failed: \(error)")
            }
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

    static var current: ModelVersion {
        // Use v6 in all environments - includes imageData for CloudKit image sync
        // The v6 schema has been deployed to both Development and Production
        return .v6
    }
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

        // imageData removed from v6 - causes CloudKit sync failures
        // Images are now local-only via imagePath (which syncs the filename)
        // Actual image files don't sync, but all item data does

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
