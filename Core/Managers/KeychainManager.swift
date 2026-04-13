import Foundation
import Security

final class KeychainManager {

    static let shared = KeychainManager()

    private init() {}

    private let service = Bundle.main.bundleIdentifier ?? "com.nexora.auth"

    func savePassword(_ password: String, for username: String) -> Bool {
        saveString(password, account: passwordAccount(for: username))
    }

    func readPassword(for username: String) -> String? {
        readString(account: passwordAccount(for: username))
    }

    func deletePassword(for username: String) -> Bool {
        deleteString(account: passwordAccount(for: username))
    }

    func saveRecoveryCodeHash(_ hash: String, for username: String) -> Bool {
        saveString(hash, account: recoveryCodeAccount(for: username))
    }

    func readRecoveryCodeHash(for username: String) -> String? {
        readString(account: recoveryCodeAccount(for: username))
    }

    func deleteRecoveryCodeHash(for username: String) -> Bool {
        deleteString(account: recoveryCodeAccount(for: username))
    }

    func hasRecoveryCode(for username: String) -> Bool {
        readRecoveryCodeHash(for: username) != nil
    }

    private func passwordAccount(for username: String) -> String {
        username.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func recoveryCodeAccount(for username: String) -> String {
        "\(username.trimmingCharacters(in: .whitespacesAndNewlines))__recovery_code_hash"
    }

    private func saveString(_ value: String, account: String) -> Bool {
        let cleanAccount = account.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanAccount.isEmpty else { return false }

        let data = Data(value.utf8)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: cleanAccount
        ]

        SecItemDelete(query as CFDictionary)

        let attributes: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: cleanAccount,
            kSecValueData as String: data
        ]

        let status = SecItemAdd(attributes as CFDictionary, nil)
        return status == errSecSuccess
    }

    private func readString(account: String) -> String? {
        let cleanAccount = account.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanAccount.isEmpty else { return nil }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: cleanAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }

        return value
    }

    private func deleteString(account: String) -> Bool {
        let cleanAccount = account.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanAccount.isEmpty else { return false }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: cleanAccount
        ]

        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}
