import SwiftUI

@main
struct SpendLaterApp: App {
    @StateObject private var container = AppContainer()

    init() {
        // Suppress known iOS keyboard Auto Layout warnings
        UserDefaults.standard.setValue(false, forKey: "_UIConstraintBasedLayoutLogUnsatisfiable")
    }

    var body: some Scene {
        WindowGroup {
            AppRootView(container: container)
        }
    }
}
