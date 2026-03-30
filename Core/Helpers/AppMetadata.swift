import Foundation

enum AppMetadata {
    static let displayName = "Nexora"
    static let supportEmail = "motwd44011@outlook.com"

    // Host this document at a public URL before App Store submission.
    // Use the same final URL here and in App Store Connect > App Privacy.
    static let privacyPolicyURLString = ""

    static var privacyPolicyURL: URL? {
        let trimmed = privacyPolicyURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return URL(string: trimmed)
    }
}
