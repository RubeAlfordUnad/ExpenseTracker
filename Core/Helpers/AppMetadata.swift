import Foundation

enum AppMetadata {
    static let displayName = "Nexora"
    static let supportEmail = "motwd44011@outlook.com"

    // Reemplaza estas URLs por las reales antes de publicar.
    static let publicWebsiteURLString = "https://nexoraweb-seven.vercel.app/"
    static let privacyPolicyURLString = "https://nexoraweb-seven.vercel.app/privacy-policy"

    static let legalLastUpdatedSpanish = "abril de 2026"
    static let legalLastUpdatedEnglish = "April 2026"

    static var supportEmailURL: URL? {
        let trimmed = supportEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return URL(string: "mailto:\(trimmed)")
    }

    static var publicWebsiteURL: URL? {
        validatedPublicURL(from: publicWebsiteURLString)
    }

    static var privacyPolicyURL: URL? {
        validatedPublicURL(from: privacyPolicyURLString)
    }

    static func legalLastUpdatedLine(for language: AppLanguage) -> String {
        switch language {
        case .spanish:
            return "Última actualización: \(legalLastUpdatedSpanish)"
        case .english:
            return "Last updated: \(legalLastUpdatedEnglish)"
        }
    }

    static func versionDescription(for language: AppLanguage) -> String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"

        switch language {
        case .spanish:
            return "Versión \(version) (\(build))"
        case .english:
            return "Version \(version) (\(build))"
        }
    }

    private static func validatedPublicURL(from rawValue: String) -> URL? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let lowered = trimmed.lowercased()
        let blockedPlaceholders = [
            "tu-dominio",
            "example.com",
            "your-domain"
        ]

        guard blockedPlaceholders.allSatisfy({ !lowered.contains($0) }) else {
            return nil
        }

        guard let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme) else {
            return nil
        }

        return url
    }
}
