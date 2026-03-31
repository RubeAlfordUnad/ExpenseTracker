import Foundation
import SwiftUI
import Combine

private enum SecuritySettingKeys {
    static let hideSensitiveAmounts = "hide_sensitive_amounts"
    static let biometricLockEnabled = "biometric_lock_enabled"
}

extension AppSettings {

    var hideSensitiveAmounts: Bool {
        get {
            UserDefaults.standard.object(forKey: SecuritySettingKeys.hideSensitiveAmounts) as? Bool ?? false
        }
        set {
            objectWillChange.send()
            UserDefaults.standard.set(newValue, forKey: SecuritySettingKeys.hideSensitiveAmounts)
        }
    }

    var biometricLockEnabled: Bool {
        get {
            UserDefaults.standard.object(forKey: SecuritySettingKeys.biometricLockEnabled) as? Bool ?? false
        }
        set {
            objectWillChange.send()
            UserDefaults.standard.set(newValue, forKey: SecuritySettingKeys.biometricLockEnabled)
        }
    }

    var hiddenAmountPlaceholder: String {
        "••••"
    }

    func secureCurrency(_ value: Double, decimals: Int = 0) -> String {
        hideSensitiveAmounts
        ? hiddenAmountPlaceholder
        : formatCurrency(value, decimals: decimals)
    }

    func secureCurrency(_ value: Double, currency: AppCurrency, decimals: Int = 0) -> String {
        hideSensitiveAmounts
        ? hiddenAmountPlaceholder
        : formatCurrency(value, currency: currency, decimals: decimals)
    }

    func secureText(_ value: String) -> String {
        hideSensitiveAmounts ? hiddenAmountPlaceholder : value
    }

    var securitySectionTitle: String {
        language == .spanish ? "Seguridad" : "Security"
    }

    var securityLockTitle: String {
        language == .spanish ? "Bloqueo de acceso" : "App lock"
    }

    var securityLockSubtitle: String {
        language == .spanish
        ? "Protege la app con Face ID, Touch ID o el código del dispositivo"
        : "Protect the app with Face ID, Touch ID or the device passcode"
    }

    var securityHideAmountsTitle: String {
        language == .spanish ? "Ocultar montos" : "Hide amounts"
    }

    var securityHideAmountsSubtitle: String {
        language == .spanish
        ? "Esconde saldos y cantidades en el dashboard y vistas principales"
        : "Hide balances and amounts across the dashboard and main finance views"
    }

    var securityScreenTitle: String {
        language == .spanish ? "Seguridad visual y acceso" : "Visual security & access"
    }

    var securityFootnote: String {
        language == .spanish
        ? "El bloqueo se activará al volver a la app después de pasar a segundo plano."
        : "The lock will be required again after the app returns from the background."
    }
}
