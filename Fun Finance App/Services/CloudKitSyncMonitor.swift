import Foundation
import CoreData
import Combine

@MainActor
final class CloudKitSyncMonitor: ObservableObject {
    @Published private(set) var syncStatus: SyncStatus = .unknown
    @Published private(set) var lastError: Error?
    @Published private(set) var isCloudKitAvailable: Bool = false
    @Published private(set) var accountDidChange: Bool = false

    enum SyncStatus {
        case unknown
        case syncing
        case synced
        case error
        case notSignedIn
        case accountChanged // New status for account changes
    }

    private let container: NSPersistentCloudKitContainer
    private var cancellables = Set<AnyCancellable>()
    private let accountChangeKey = "LastKnownCloudKitIdentity"

    init(container: NSPersistentCloudKitContainer) {
        self.container = container
        checkCloudKitAvailability()
        observeSyncEvents()
        observeAccountChanges()
    }

    private func checkCloudKitAvailability() {
        // Check if user is signed into iCloud
        isCloudKitAvailable = FileManager.default.ubiquityIdentityToken != nil

        if !isCloudKitAvailable {
            syncStatus = .notSignedIn
        }
    }

    private func observeSyncEvents() {
        // Monitor CloudKit import events
        NotificationCenter.default.publisher(for: NSPersistentCloudKitContainer.eventChangedNotification)
            .sink { [weak self] notification in
                guard let self else { return }

                if let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey] as? NSPersistentCloudKitContainer.Event {
                    Task { @MainActor in
                        self.handleSyncEvent(event)
                    }
                }
            }
            .store(in: &cancellables)

        // Monitor store remote change notifications
        NotificationCenter.default.publisher(for: .NSPersistentStoreRemoteChange)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.syncStatus = .syncing
                }
            }
            .store(in: &cancellables)
    }

    private func handleSyncEvent(_ event: NSPersistentCloudKitContainer.Event) {
        if let error = event.error {
            let nsError = error as NSError

            // Don't treat account changes as errors - they're handled separately
            if nsError.code == 134405 {
                // Account change - handled by observeAccountChanges
                return
            }

            syncStatus = .error
            lastError = error

            // Log detailed error information
            print("⚠️ CloudKit sync error: \(error.localizedDescription)")
            print("   Error domain: \(nsError.domain), code: \(nsError.code)")

            // Common CloudKit errors and what they mean:
            // 134400 = Validation error (schema issue or not signed in)
            // 134060 = Model constraint violation
            // 134405 = Account change (handled separately)
            if nsError.code == 134400 {
                print("   This usually means: Not signed into iCloud, or CloudKit schema needs to be created")
                print("   The app will continue working with local storage only")
            }
        } else if event.endDate != nil {
            // Event completed successfully
            syncStatus = .synced
            lastError = nil
        } else {
            // Event is in progress
            syncStatus = .syncing
        }
    }

    func refreshCloudKitStatus() {
        checkCloudKitAvailability()
    }

    private func observeAccountChanges() {
        // Store current identity for future comparison
        if let currentIdentity = FileManager.default.ubiquityIdentityToken as? NSData {
            let identityString = currentIdentity.base64EncodedString()
            UserDefaults.standard.set(identityString, forKey: accountChangeKey)
        }
    }

    private func handleAccountChange() {
        print("⚠️ iCloud account changed - CloudKit will re-initialize sync")
        syncStatus = .accountChanged
        accountDidChange = true

        // Update stored identity
        if let newIdentity = FileManager.default.ubiquityIdentityToken as? NSData {
            let identityString = newIdentity.base64EncodedString()
            UserDefaults.standard.set(identityString, forKey: accountChangeKey)
        }

        // After account change, CloudKit will automatically reset and re-sync
        // The sync status will update through normal event notifications
    }

    func acknowledgeAccountChange() {
        accountDidChange = false
        syncStatus = .unknown
        checkCloudKitAvailability()
    }
}
