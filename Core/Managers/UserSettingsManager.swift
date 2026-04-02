import Foundation

@available(*, deprecated, message: "Wrapper legado. Usa AppSettings directamente y elimina este archivo cuando ya no haya referencias.")
final class UserSettingsManager {

    static let shared = UserSettingsManager()

    private let languageKey = "app_language"
    private let notificationsKey = "notifications_enabled"

    private init() {}

    func saveLanguage(_ language: AppLanguage) {
        UserDefaults.standard.set(language.rawValue, forKey: languageKey)
    }

    func loadLanguage() -> AppLanguage {
        guard let value = UserDefaults.standard.string(forKey: languageKey),
              let language = AppLanguage(rawValue: value)
        else {
            return .english
        }

        return language
    }

    func saveNotificationsEnabled(_ value: Bool) {
        UserDefaults.standard.set(value, forKey: notificationsKey)
    }

    func loadNotificationsEnabled() -> Bool {
        UserDefaults.standard.bool(forKey: notificationsKey)
    }
}
