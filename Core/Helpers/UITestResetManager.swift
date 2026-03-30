import Foundation

enum UITestResetManager {

    static var isRunningUITests: Bool {
        ProcessInfo.processInfo.arguments.contains("-ui-testing")
    }

    static func applyIfNeeded() {
        let arguments = ProcessInfo.processInfo.arguments

        guard arguments.contains("-ui-testing") else { return }

        if arguments.contains("-reset-app-state") {
            clearUserDefaults()
        }
    }

    private static func clearUserDefaults() {
        let defaults = UserDefaults.standard

        let globalKeys = [
            "session_key",
            "hasSeenOnboarding",
            "app_theme",
            "app_language",
            "app_country",
            "use_automatic_currency",
            "manual_currency",
            "exchange_target_currency"
        ]

        globalKeys.forEach { defaults.removeObject(forKey: $0) }
    }
}
