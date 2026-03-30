//
//  UserSettingsManager.swift
//  ExpenseTracker
//
//  Created by Ruben Alford on 17/03/26.
//

import SwiftUI

class UserSettingsManager {

    static let shared = UserSettingsManager()

    private let languageKey = "app_language"
    private let notificationsKey = "notifications_enabled"
    private let profileImageKey = "profile_image"

    // MARK: LANGUAGE

    func saveLanguage(_ language: AppLanguage) {
        UserDefaults.standard.set(language.rawValue, forKey: languageKey)
    }

    func loadLanguage() -> AppLanguage {
        guard let value = UserDefaults.standard.string(forKey: languageKey),
              let language = AppLanguage(rawValue: value)
        else { return .english }

        return language
    }

    // MARK: NOTIFICATIONS

    func saveNotificationsEnabled(_ value: Bool) {
        UserDefaults.standard.set(value, forKey: notificationsKey)
    }

    func loadNotificationsEnabled() -> Bool {
        UserDefaults.standard.bool(forKey: notificationsKey)
    }

}
