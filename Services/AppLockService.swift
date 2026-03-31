import Foundation
import LocalAuthentication

struct AppLockAvailability {
    let isAvailable: Bool
    let biometryType: LABiometryType
    let message: String?
}

final class AppLockService {

    static let shared = AppLockService()

    private init() {}

    func availability() -> AppLockAvailability {
        let context = LAContext()
        var error: NSError?

        let isAvailable = context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error)
        return AppLockAvailability(
            isAvailable: isAvailable,
            biometryType: context.biometryType,
            message: error?.localizedDescription
        )
    }

    func unlockButtonTitle(language: AppLanguage) -> String {
        let availability = availability()

        switch availability.biometryType {
        case .faceID:
            return language == .spanish ? "Desbloquear con Face ID" : "Unlock with Face ID"
        case .touchID:
            return language == .spanish ? "Desbloquear con Touch ID" : "Unlock with Touch ID"
        default:
            return language == .spanish ? "Desbloquear" : "Unlock"
        }
    }

    func accessMethodDescription(language: AppLanguage) -> String {
        let availability = availability()

        switch availability.biometryType {
        case .faceID:
            return language == .spanish ? "Face ID disponible" : "Face ID available"
        case .touchID:
            return language == .spanish ? "Touch ID disponible" : "Touch ID available"
        default:
            return language == .spanish
            ? "Usará biometría o el código del dispositivo si está disponible"
            : "It will use biometrics or the device passcode when available"
        }
    }

    func authenticate(language: AppLanguage) async -> Bool {
        let context = LAContext()
        context.localizedCancelTitle = language == .spanish ? "Cancelar" : "Cancel"
        context.localizedFallbackTitle = language == .spanish ? "Usar código" : "Use passcode"

        let reason = language == .spanish
        ? "Desbloquea Nexora para ver tus datos financieros."
        : "Unlock Nexora to view your financial data."

        return await withCheckedContinuation { continuation in
            var error: NSError?
            guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
                continuation.resume(returning: false)
                return
            }

            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, _ in
                continuation.resume(returning: success)
            }
        }
    }
}
