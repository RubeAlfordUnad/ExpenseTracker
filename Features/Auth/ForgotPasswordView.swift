import SwiftUI

struct ForgotPasswordView: View {

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var auth: AuthManager
    @EnvironmentObject var settings: AppSettings

    @State private var username = ""
    @State private var recoveryCode = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""

    @State private var showResultAlert = false
    @State private var resultTitle = ""
    @State private var resultMessage = ""
    @State private var shouldDismissAfterAlert = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(loginUsernameTitle, text: $username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .accessibilityIdentifier("forgot.username")

                    TextField(recoveryCodeTitle, text: $recoveryCode)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .accessibilityIdentifier("forgot.recoveryCode")
                } header: {
                    Text(identitySectionTitle)
                } footer: {
                    Text(identitySectionFooter)
                }

                Section {
                    SecureField(newPasswordTitle, text: $newPassword)
                        .accessibilityIdentifier("forgot.newPassword")

                    SecureField(confirmPasswordTitle, text: $confirmPassword)
                        .accessibilityIdentifier("forgot.confirmPassword")
                } header: {
                    Text(settings.language == .spanish ? "Nueva contraseña" : "New password")
                }

                Section {
                    Button {
                        resetPassword()
                    } label: {
                        Text(submitTitle)
                            .frame(maxWidth: .infinity)
                    }
                    .accessibilityIdentifier("forgot.submit")
                }
            }
            .navigationTitle(screenTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(settings.t("common.cancel")) {
                        dismiss()
                    }
                }
            }
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
        .accessibilityIdentifier("forgot.screen")
    }

    private func resetPassword() {
        let cleanUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanRecoveryCode = recoveryCode.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanNewPassword = newPassword.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanConfirmPassword = confirmPassword.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanUsername.isEmpty,
              !cleanRecoveryCode.isEmpty,
              !cleanNewPassword.isEmpty,
              !cleanConfirmPassword.isEmpty else {
            presentResult(
                title: settings.language == .spanish ? "Faltan datos" : "Missing information",
                message: settings.language == .spanish
                ? "Completa usuario, código de recuperación y nueva contraseña."
                : "Enter username, recovery code, and the new password."
            )
            return
        }

        guard cleanNewPassword == cleanConfirmPassword else {
            presentResult(
                title: settings.language == .spanish ? "Las contraseñas no coinciden" : "Passwords do not match",
                message: settings.language == .spanish
                ? "Confirma la nueva contraseña exactamente igual."
                : "Confirm the new password exactly the same."
            )
            return
        }

        switch auth.recoverPassword(
            username: cleanUsername,
            recoveryCode: cleanRecoveryCode,
            newPassword: cleanNewPassword
        ) {
        case .success:
            shouldDismissAfterAlert = true
            presentResult(
                title: settings.language == .spanish ? "Contraseña restablecida" : "Password reset",
                message: settings.language == .spanish
                ? "Ya puedes volver e iniciar sesión con tu nueva contraseña."
                : "You can now go back and sign in with your new password."
            )

        case .invalidInput:
            presentResult(
                title: settings.language == .spanish ? "Datos inválidos" : "Invalid input",
                message: settings.language == .spanish
                ? "Revisa los datos ingresados."
                : "Please review the entered data."
            )

        case .unknownUser:
            presentResult(
                title: settings.language == .spanish ? "Usuario no encontrado" : "User not found",
                message: settings.language == .spanish
                ? "No existe una cuenta local con ese nombre."
                : "There is no local account with that username."
            )

        case .missingRecoveryCode:
            presentResult(
                title: settings.language == .spanish ? "Sin código configurado" : "No recovery code configured",
                message: settings.language == .spanish
                ? "Esa cuenta todavía no tiene un código de recuperación guardado."
                : "That account does not have a saved recovery code yet."
            )

        case .invalidRecoveryCode:
            presentResult(
                title: settings.language == .spanish ? "Código incorrecto" : "Invalid recovery code",
                message: settings.language == .spanish
                ? "El código de recuperación no coincide."
                : "The recovery code does not match."
            )

        case .saveFailed:
            presentResult(
                title: settings.language == .spanish ? "No se pudo actualizar" : "Could not update",
                message: settings.language == .spanish
                ? "La contraseña no se pudo guardar en este dispositivo."
                : "The password could not be saved on this device."
            )
        }
    }

    private func presentResult(title: String, message: String) {
        resultTitle = title
        resultMessage = message
        showResultAlert = true
    }

    private var screenTitle: String {
        settings.language == .spanish ? "Recuperar contraseña" : "Recover password"
    }

    private var identitySectionTitle: String {
        settings.language == .spanish ? "Verificación local" : "Local verification"
    }

    private var identitySectionFooter: String {
        settings.language == .spanish
        ? "Usa el nombre de usuario de la cuenta y el código de recuperación que guardaste fuera de la app."
        : "Use the account username and the recovery code you saved outside the app."
    }

    private var loginUsernameTitle: String {
        settings.t("login.username")
    }

    private var recoveryCodeTitle: String {
        settings.language == .spanish ? "Código de recuperación" : "Recovery code"
    }

    private var newPasswordTitle: String {
        settings.language == .spanish ? "Nueva contraseña" : "New password"
    }

    private var confirmPasswordTitle: String {
        settings.language == .spanish ? "Confirmar nueva contraseña" : "Confirm new password"
    }

    private var submitTitle: String {
        settings.language == .spanish ? "Restablecer contraseña" : "Reset password"
    }
}
