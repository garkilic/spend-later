import Foundation
import CoreData
import Combine

@MainActor
final class CloudKitSyncMonitor: ObservableObject {
    @Published private(set) var syncStatus: SyncStatus = .unknown
    @Published private(set) var lastError: Error?
    @Published private(set) var isCloudKitAvailable: Bool = false

    enum SyncStatus {
        case unknown
        case syncing
        case synced
        case error
        case notSignedIn
    }

    private let container: NSPersistentCloudKitContainer
    private var cancellables = Set<AnyCancellable>()

    init(container: NSPersistentCloudKitContainer) {
        self.container = container
        checkCloudKitAvailability()
        observeSyncEvents()
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
            syncStatus = .error
            lastError = error

            // Log detailed error information
            let nsError = error as NSError
            print("⚠️ CloudKit sync error: \(error.localizedDescription)")
            print("   Error domain: \(nsError.domain), code: \(nsError.code)")

            // Common CloudKit errors and what they mean:
            // 134400 = Validation error (schema issue or not signed in)
            // 134060 = Model constraint violation
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
}
