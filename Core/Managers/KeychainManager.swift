//
//  KeychainManager.swift
//  ExpenseTracker
//
//  Created by Ruben Alford on 21/03/26.
//

import Foundation
import Security

final class KeychainManager {

    static let shared = KeychainManager()

    private init() {}

    private let service = Bundle.main.bundleIdentifier ?? "com.nexora.auth"

    func savePassword(_ password: String, for username: String) -> Bool {
        let account = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !account.isEmpty else { return false }

        let data = Data(password.utf8)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        SecItemDelete(query as CFDictionary)

        let attributes: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data
        ]

        let status = SecItemAdd(attributes as CFDictionary, nil)
        return status == errSecSuccess
    }

    func readPassword(for username: String) -> String? {
        let account = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !account.isEmpty else { return nil }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let password = String(data: data, encoding: .utf8) else {
            return nil
        }

        return password
    }

    func deletePassword(for username: String) -> Bool {
        let account = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !account.isEmpty else { return false }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}
