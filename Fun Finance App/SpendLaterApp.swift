import SwiftUI

@main
struct SpendLaterApp: App {
    @StateObject private var container = AppContainer()

    init() {
        // Suppress known iOS simulator debugging noise
        UserDefaults.standard.setValue(false, forKey: "_UIConstraintBasedLayoutLogUnsatisfiable")

        // Reduce console noise from iOS internals
        setenv("OS_ACTIVITY_MODE", "disable", 1)
    }

    var body: some Scene {
        WindowGroup {
            AppRootView(container: container)
        }
    }
}
