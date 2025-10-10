import SwiftUI

@main
struct SpendLaterApp: App {
    @StateObject private var container = AppContainer()
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        // Suppress known iOS simulator debugging noise
        UserDefaults.standard.setValue(false, forKey: "_UIConstraintBasedLayoutLogUnsatisfiable")
    }

    var body: some Scene {
        WindowGroup {
            AppRootView(container: container)
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        // Only allow portrait orientation
        return .portrait
    }
}
