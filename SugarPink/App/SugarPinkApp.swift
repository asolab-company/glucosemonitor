import SwiftUI

@main
struct SugarPinkApp: App {
    @UIApplicationDelegateAdaptor(AppsFlyerAppDelegate.self)
    private var appsFlyerAppDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
