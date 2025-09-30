import Foundation

enum PreviewSupport {
    static let container: AppContainer = {
        let controller = PersistenceController.preview
        return AppContainer(persistenceController: controller)
    }()
}
