import SwiftUI

struct ChangePasswordView: View {

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var auth: AuthManager
    @EnvironmentObject var settings: AppSettings

    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""

    @State private var showResultAlert = false
    @State private var resultTitle = ""
    @State private var resultMessage = ""
    @State private var shouldDismissAfterAlert = false

    var body: some View {
        Form {
            Section {
                SecureField(currentPasswordTitle, text: $currentPassword)
                    .accessibilityIdentifier("changePassword.current")
            } header: {
                Text(settings.language == .spanish ? "Verificación" : "Verification")
            }

            Section {
                SecureField(newPasswordTitle, text: $newPassword)
                    .accessibilityIdentifier("changePassword.new")

                SecureField(confirmPasswordTitle, text: $confirmPassword)
                    .accessibilityIdentifier("changePassword.confirm")
            } header: {
                Text(settings.language == .spanish ? "Nueva contraseña" : "New password")
            }

            Section {
                Button {
                    changePassword()
                } label: {
                    Text(submitTitle)
                        .frame(maxWidth: .infinity)
                }
                .accessibilityIdentifier("changePassword.submit")
            }
        }
        .navigationTitle(screenTitle)
        .navigationBarTitleDisplayMode(.inline)
        .alert(resultTitle, isPresented: $showResultAlert) {
            Button("OK") {
                if shouldDismissAfterAlert {
                    dismiss()
                }
            }
        } message: {
            Text(resultMessage)
        }
    }

    private func changePassword() {
        let cleanCurrent = currentPassword.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanNew = newPassword.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanConfirm = confirmPassword.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanCurrent.isEmpty, !cleanNew.isEmpty, !cleanConfirm.isEmpty else {
            presentResult(
                title: settings.language == .spanish ? "Faltan datos" : "Missing information",
                message: settings.language == .spanish
                ? "Completa todos los campos antes de continuar."
                : "Complete all fields before continuing."
            )
            return
        }

        guard cleanNew == cleanConfirm else {
            presentResult(
                title: settings.language == .spanish ? "Las contraseñas no coinciden" : "Passwords do not match",
                message: settings.language == .spanish
                ? "Confirma la nueva contraseña exactamente igual."
                : "Confirm the new password exactly the same."
            )
            return
        }

        switch auth.changePassword(currentPassword: cleanCurrent, newPassword: cleanNew) {
        case .success:
            shouldDismissAfterAlert = true
            presentResult(
                title: settings.language == .spanish ? "Contraseña actualizada" : "Password updated",
                message: settings.language == .spanish
                ? "Tu contraseña local fue cambiada correctamente."
                : "Your local password was changed successfully."
            )

        case .notAvailable:
            presentResult(
                title: settings.language == .spanish ? "No disponible" : "Unavailable",
                message: settings.language == .spanish
                ? "Esta opción solo aplica a cuentas locales registradas."
                : "This option only applies to registered local accounts."
            )

        case .invalidCurrentPassword:
            presentResult(
                title: settings.language == .spanish ? "Contraseña actual incorrecta" : "Incorrect current password",
                message: settings.language == .spanish
                ? "La contraseña actual no coincide."
                : "The current password does not match."
            )

        case .invalidNewPassword:
            presentResult(
                title: settings.language == .spanish ? "Nueva contraseña inválida" : "Invalid new password",
                message: settings.language == .spanish
                ? "Escribe una nueva contraseña válida."
                : "Enter a valid new password."
            )

        case .samePassword:
            presentResult(
                title: settings.language == .spanish ? "Sin cambios" : "No changes",
                message: settings.language == .spanish
                ? "La nueva contraseña debe ser distinta a la actual."
                : "The new password must be different from the current one."
            )

        case .saveFailed:
            presentResult(
                title: settings.language == .spanish ? "No se pudo guardar" : "Could not save",
                message: settings.language == .spanish
                ? "La contraseña no se pudo actualizar en este dispositivo."
                : "The password could not be updated on this device."
            )
        }
    }

    private func presentResult(title: String, message: String) {
        resultTitle = title
        resultMessage = message
        showResultAlert = true
    }

    private var screenTitle: String {
        settings.language == .spanish ? "Cambiar contraseña" : "Change password"
    }

    private var currentPasswordTitle: String {
        settings.language == .spanish ? "Contraseña actual" : "Current password"
    }

    private var newPasswordTitle: String {
        settings.language == .spanish ? "Nueva contraseña" : "New password"
    }

    private var confirmPasswordTitle: String {
        settings.language == .spanish ? "Confirmar nueva contraseña" : "Confirm new password"
    }

    private var submitTitle: String {
        settings.language == .spanish ? "Actualizar contraseña" : "Update password"
    }
}
