import SwiftUI

@main
struct ExpenseTrackerApp: App {

    @StateObject private var auth: AuthManager
    @StateObject private var settings: AppSettings

    init() {
        UITestResetManager.applyIfNeeded()
        _ = PersistenceController.shared

        _auth = StateObject(wrappedValue: AuthManager())
        _settings = StateObject(wrappedValue: AppSettings())
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(auth)
                .environmentObject(settings)
                .environment(\.locale, settings.appLocale)
                .preferredColorScheme(settings.theme.colorScheme)
                .onAppear {
                    NotificationManager.shared.configure()
                }
        }
    }
}
