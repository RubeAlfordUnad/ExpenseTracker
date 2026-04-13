import Foundation
import Combine

struct User: Codable {
    let username: String
}

private struct LegacyStoredUser: Codable {
    let username: String
    let password: String
}

enum AuthRegistrationResult: Equatable {
    case success(recoveryCode: String)
    case invalidInput
    case usernameExists
    case credentialStoreFailure
    case recoveryCodeStoreFailure
}

enum AuthPasswordChangeResult: Equatable {
    case success
    case notAvailable
    case invalidCurrentPassword
    case invalidNewPassword
    case samePassword
    case saveFailed
}

enum AuthPasswordRecoveryResult: Equatable {
    case success
    case invalidInput
    case unknownUser
    case missingRecoveryCode
    case invalidRecoveryCode
    case saveFailed
}

final class AuthManager: ObservableObject {

    @Published var isLoggedIn = false
    @Published var currentUser: String = ""

    let localModeUserKey = "__local_device__"

    private let usernamesKey = "registered_usernames_key"
    private let legacyUsersKey = "users_key"
    private let sessionKey = "session_key"
    private let migrationFlagKey = "auth_migrated_to_keychain_v1"

    init() {
        migrateLegacyUsersToKeychainIfNeeded()
        loadSession()
    }

    var isUsingLocalMode: Bool {
        currentUser == localModeUserKey
    }

    var displayName: String {
        isUsingLocalMode ? "Local" : currentUser
    }

    var hasRecoveryCodeForCurrentUser: Bool {
        let username = sanitizeUsername(currentUser)
        guard !username.isEmpty, !isUsingLocalMode else { return false }
        return KeychainManager.shared.hasRecoveryCode(for: username)
    }

    @discardableResult
    func continueLocally() -> Bool {
        currentUser = localModeUserKey
        isLoggedIn = true
        UserDefaults.standard.set(localModeUserKey, forKey: sessionKey)
        NotificationManager.shared.syncRecurringPaymentNotifications(for: localModeUserKey)
        return true
    }

    @discardableResult
    func register(username: String, password: String) -> Bool {
        if case .success = registerWithRecoveryCode(username: username, password: password) {
            return true
        }
        return false
    }

    func registerWithRecoveryCode(username: String, password: String) -> AuthRegistrationResult {
        let cleanUsername = sanitizeUsername(username)
        let cleanPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanUsername.isEmpty, !cleanPassword.isEmpty else {
            return .invalidInput
        }

        var usernames = loadUsernames()

        if usernames.contains(cleanUsername) {
            return .usernameExists
        }

        guard KeychainManager.shared.savePassword(cleanPassword, for: cleanUsername) else {
            return .credentialStoreFailure
        }

        let recoveryCode = RecoveryCodeManager.shared.generateCode()
        let recoveryHash = RecoveryCodeManager.shared.hash(recoveryCode)

        guard KeychainManager.shared.saveRecoveryCodeHash(recoveryHash, for: cleanUsername) else {
            _ = KeychainManager.shared.deletePassword(for: cleanUsername)
            return .recoveryCodeStoreFailure
        }

        usernames.append(cleanUsername)
        saveUsernames(usernames)
        return .success(recoveryCode: recoveryCode)
    }

    func login(username: String, password: String) -> Bool {
        let cleanUsername = sanitizeUsername(username)
        guard !cleanUsername.isEmpty, !password.isEmpty else {
            return false
        }

        let usernames = loadUsernames()
        guard usernames.contains(cleanUsername) else {
            return false
        }

        guard let savedPassword = KeychainManager.shared.readPassword(for: cleanUsername),
              savedPassword == password else {
            return false
        }

        currentUser = cleanUsername
        isLoggedIn = true
        UserDefaults.standard.set(cleanUsername, forKey: sessionKey)
        NotificationManager.shared.syncRecurringPaymentNotifications(for: cleanUsername)
        return true
    }

    func changePassword(currentPassword: String, newPassword: String) -> AuthPasswordChangeResult {
        let username = sanitizeUsername(currentUser)
        guard !username.isEmpty, !isUsingLocalMode else {
            return .notAvailable
        }

        let cleanCurrentPassword = currentPassword.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanNewPassword = newPassword.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanCurrentPassword.isEmpty, !cleanNewPassword.isEmpty else {
            return .invalidNewPassword
        }

        guard let savedPassword = KeychainManager.shared.readPassword(for: username),
              savedPassword == cleanCurrentPassword else {
            return .invalidCurrentPassword
        }

        guard cleanNewPassword != savedPassword else {
            return .samePassword
        }

        guard KeychainManager.shared.savePassword(cleanNewPassword, for: username) else {
            return .saveFailed
        }

        return .success
    }

    func recoverPassword(username: String, recoveryCode: String, newPassword: String) -> AuthPasswordRecoveryResult {
        let cleanUsername = sanitizeUsername(username)
        let cleanRecoveryCode = recoveryCode.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanNewPassword = newPassword.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanUsername.isEmpty, !cleanRecoveryCode.isEmpty, !cleanNewPassword.isEmpty else {
            return .invalidInput
        }

        let usernames = loadUsernames()
        guard usernames.contains(cleanUsername) else {
            return .unknownUser
        }

        guard let storedHash = KeychainManager.shared.readRecoveryCodeHash(for: cleanUsername) else {
            return .missingRecoveryCode
        }

        guard RecoveryCodeManager.shared.matches(cleanRecoveryCode, storedHash: storedHash) else {
            return .invalidRecoveryCode
        }

        guard KeychainManager.shared.savePassword(cleanNewPassword, for: cleanUsername) else {
            return .saveFailed
        }

        return .success
    }

    func generateRecoveryCodeForCurrentUser() -> String? {
        let username = sanitizeUsername(currentUser)
        guard !username.isEmpty, !isUsingLocalMode else { return nil }
        return generateRecoveryCode(for: username)
    }

    func logout() {
        let username = sanitizeUsername(currentUser)

        if !username.isEmpty {
            let recurringPayments = DataManager.shared.loadRecurringPayments(user: username)
            NotificationManager.shared.cancelNotifications(for: recurringPayments)
            NotificationManager.shared.cancelBudgetNotifications()
        }

        currentUser = ""
        isLoggedIn = false
        UserDefaults.standard.removeObject(forKey: sessionKey)
    }

    @discardableResult
    func deleteCurrentAccount() -> Bool {
        let username = sanitizeUsername(currentUser)
        guard !username.isEmpty else {
            return false
        }

        let recurringPayments = DataManager.shared.loadRecurringPayments(user: username)
        NotificationManager.shared.cancelNotifications(for: recurringPayments)
        NotificationManager.shared.cancelBudgetNotifications()

        DataManager.shared.deleteAllLocalData(for: username)

        if !isUsingLocalMode {
            _ = KeychainManager.shared.deletePassword(for: username)
            _ = KeychainManager.shared.deleteRecoveryCodeHash(for: username)

            var usernames = loadUsernames()
            usernames.removeAll { $0 == username }
            saveUsernames(usernames)
        }

        logout()
        return true
    }

    private func generateRecoveryCode(for username: String) -> String? {
        let cleanUsername = sanitizeUsername(username)
        guard !cleanUsername.isEmpty else { return nil }

        let recoveryCode = RecoveryCodeManager.shared.generateCode()
        let recoveryHash = RecoveryCodeManager.shared.hash(recoveryCode)

        guard KeychainManager.shared.saveRecoveryCodeHash(recoveryHash, for: cleanUsername) else {
            return nil
        }

        return recoveryCode
    }

    private func loadUsernames() -> [String] {
        UserDefaults.standard.stringArray(forKey: usernamesKey) ?? []
    }

    private func saveUsernames(_ usernames: [String]) {
        var seen = Set<String>()
        let uniqueUsernames = usernames.filter { seen.insert($0).inserted }
        UserDefaults.standard.set(uniqueUsernames, forKey: usernamesKey)
    }

    private func loadSession() {
        if let savedUser = UserDefaults.standard.string(forKey: sessionKey),
           !savedUser.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            currentUser = savedUser
            isLoggedIn = true
            NotificationManager.shared.syncRecurringPaymentNotifications(for: savedUser)
        }
    }

    private func sanitizeUsername(_ username: String) -> String {
        username.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func migrateLegacyUsersToKeychainIfNeeded() {
        let defaults = UserDefaults.standard

        if defaults.bool(forKey: migrationFlagKey) {
            return
        }

        guard let data = defaults.data(forKey: legacyUsersKey),
              let legacyUsers = try? JSONDecoder().decode([LegacyStoredUser].self, from: data) else {
            defaults.set(true, forKey: migrationFlagKey)
            return
        }

        var usernames = loadUsernames()
        var allSucceeded = true

        for legacyUser in legacyUsers {
            let username = sanitizeUsername(legacyUser.username)
            guard !username.isEmpty else { continue }

            if usernames.contains(username) {
                continue
            }

            let didSave = KeychainManager.shared.savePassword(legacyUser.password, for: username)

            if didSave {
                usernames.append(username)
            } else {
                allSucceeded = false
            }
        }

        saveUsernames(usernames)

        if allSucceeded {
            defaults.removeObject(forKey: legacyUsersKey)
            defaults.set(true, forKey: migrationFlagKey)
        }
    }
}
