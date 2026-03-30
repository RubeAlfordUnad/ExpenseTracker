//
//  TestSupport.swift
//  ExpenseTracker
//
//  Created by Ruben Alford on 23/03/26.
//

import Foundation
@testable import ExpenseTracker

func makeUniqueUsername(_ prefix: String = "test") -> String {
    "\(prefix)_\(UUID().uuidString)"
}

func makeDate(year: Int, month: Int, day: Int) -> Date {
    var components = DateComponents()
    components.year = year
    components.month = month
    components.day = day
    components.calendar = Calendar(identifier: .gregorian)
    return components.date ?? Date(timeIntervalSince1970: 0)
}

func clearAppStorage(for usernames: [String] = []) {
    let defaults = UserDefaults.standard

    let globalKeys = [
        "users_key",
        "registered_usernames_key",
        "session_key",
        "auth_migrated_to_keychain_v1",
        "app_theme",
        "app_language",
        "app_country",
        "use_automatic_currency",
        "manual_currency",
        "exchange_target_currency"
    ]

    globalKeys.forEach { defaults.removeObject(forKey: $0) }

    for user in usernames {
        DataManager.shared.deleteAllLocalData(for: user)
        _ = KeychainManager.shared.deletePassword(for: user)

        let scopedKeys = [
            "profileImage_\(user)",
            "expenses_\(user)",
            "debts_\(user)",
            "recurringPayments_\(user)",
            "monthlyBudget_\(user)",
            "notificationPreferences_\(user)",
            "budgetAlertState_\(user)",
            "swiftDataFinancialMigration_v1_\(user)"
        ]

        scopedKeys.forEach { defaults.removeObject(forKey: $0) }
    }
}
