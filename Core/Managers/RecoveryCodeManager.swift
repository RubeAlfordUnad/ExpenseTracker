import Foundation
import CryptoKit

final class RecoveryCodeManager {

    static let shared = RecoveryCodeManager()

    private init() {}

    private let alphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")

    func generateCode() -> String {
        let raw = String((0..<16).map { _ in
            alphabet.randomElement() ?? "A"
        })

        return stride(from: 0, to: raw.count, by: 4).map { start in
            let startIndex = raw.index(raw.startIndex, offsetBy: start)
            let endIndex = raw.index(startIndex, offsetBy: 4, limitedBy: raw.endIndex) ?? raw.endIndex
            return String(raw[startIndex..<endIndex])
        }
        .joined(separator: "-")
    }

    func normalize(_ code: String) -> String {
        code
            .uppercased()
            .filter { $0.isLetter || $0.isNumber }
    }

    func hash(_ code: String) -> String {
        let normalized = normalize(code)
        let digest = SHA256.hash(data: Data(normalized.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    func matches(_ input: String, storedHash: String) -> Bool {
        hash(input) == storedHash
    }
}
