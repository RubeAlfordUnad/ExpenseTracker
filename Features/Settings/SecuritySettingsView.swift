import SwiftUI

struct SecuritySettingsView: View {

    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var auth: AuthManager

    @State private var lockToggleDraft = false
    @State private var showAvailabilityAlert = false
    @State private var availabilityMessage = ""
    @State private var isCheckingAccess = false

    @State private var hasRecoveryCode = false
    @State private var latestRecoveryCode = ""
    @State private var showRecoveryCodeSheet = false
    @State private var showRecoveryErrorAlert = false
    @State private var recoveryErrorMessage = ""

    var body: some View {
        List {
            Section {
                Toggle(isOn: $lockToggleDraft) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(settings.securityLockTitle)
                        Text(settings.securityLockSubtitle)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .disabled(isCheckingAccess)
                .onChange(of: lockToggleDraft) { _, enabled in
                    handleLockToggleChange(enabled)
                }

                HStack(spacing: 12) {
                    Image(systemName: "faceid")
                        .foregroundColor(BrandPalette.primary)
                        .frame(width: 22)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(settings.language == .spanish ? "Método de desbloqueo" : "Unlock method")
                        Text(AppLockService.shared.accessMethodDescription(language: settings.language))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            } header: {
                Text(settings.language == .spanish ? "Acceso" : "Access")
            } footer: {
                Text(settings.securityFootnote)
            }

            Section {
                Toggle(isOn: Binding(
                    get: { settings.hideSensitiveAmounts },
                    set: { settings.hideSensitiveAmounts = $0 }
                )) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(settings.securityHideAmountsTitle)
                        Text(settings.securityHideAmountsSubtitle)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                HStack(spacing: 12) {
                    Image(systemName: settings.hideSensitiveAmounts ? "eye.slash.fill" : "eye.fill")
                        .foregroundColor(BrandPalette.primary)
                        .frame(width: 22)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(settings.language == .spanish ? "Vista previa" : "Preview")
                        Text(
                            settings.hideSensitiveAmounts
                            ? settings.hiddenAmountPlaceholder
                            : settings.formatCurrency(2450000)
                        )
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                    }
                }
            } header: {
                Text(settings.language == .spanish ? "Privacidad visual" : "Visual privacy")
            }

            if !auth.isUsingLocalMode {
                Section {
                    NavigationLink {
                        ChangePasswordView()
                            .environmentObject(auth)
                            .environmentObject(settings)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(settings.language == .spanish ? "Cambiar contraseña" : "Change password")
                            Text(
                                settings.language == .spanish
                                ? "Actualiza la contraseña local usando tu contraseña actual."
                                : "Update your local password using the current password."
                            )
                            .font(.caption)
                            .foregroundColor(.secondary)
                        }
                    }

                    Button {
                        generateRecoveryCode()
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(
                                hasRecoveryCode
                                ? (settings.language == .spanish ? "Regenerar código de recuperación" : "Regenerate recovery code")
                                : (settings.language == .spanish ? "Crear código de recuperación" : "Create recovery code")
                            )
                            Text(
                                hasRecoveryCode
                                ? (settings.language == .spanish
                                   ? "El código anterior dejará de servir cuando generes uno nuevo."
                                   : "The previous code will stop working once you generate a new one.")
                                : (settings.language == .spanish
                                   ? "Configura un código local para recuperar la contraseña si la olvidas."
                                   : "Set up a local code to recover the password if you forget it.")
                            )
                            .font(.caption)
                            .foregroundColor(.secondary)
                        }
                    }

                    HStack(spacing: 12) {
                        Image(systemName: hasRecoveryCode ? "checkmark.shield.fill" : "shield.slash")
                            .foregroundColor(hasRecoveryCode ? .green : BrandPalette.secondary)
                            .frame(width: 22)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(settings.language == .spanish ? "Estado del código de recuperación" : "Recovery code status")
                            Text(
                                hasRecoveryCode
                                ? (settings.language == .spanish ? "Ya tienes un código configurado en este dispositivo." : "A recovery code is already configured on this device.")
                                : (settings.language == .spanish ? "Todavía no has generado un código de recuperación." : "You have not generated a recovery code yet.")
                            )
                            .font(.caption)
                            .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text(settings.language == .spanish ? "Contraseña y recuperación" : "Password and recovery")
                } footer: {
                    Text(
                        settings.language == .spanish
                        ? "Guarda el código de recuperación fuera de la app. Sin él, no existe recuperación no destructiva."
                        : "Store the recovery code outside the app. Without it, there is no non-destructive recovery."
                    )
                }
            } else {
                Section {
                    Text(
                        settings.language == .spanish
                        ? "Estás usando la app sin cuenta. Las opciones de contraseña y recuperación no aplican en este modo."
                        : "You are using the app without an account. Password and recovery options do not apply in this mode."
                    )
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                } header: {
                    Text(settings.language == .spanish ? "Cuenta local" : "Local account")
                }
            }
        }
        .navigationTitle(settings.securityScreenTitle)
        .navigationBarTitleDisplayMode(.inline)
        .alert(settings.language == .spanish ? "Acceso no disponible" : "Access unavailable", isPresented: $showAvailabilityAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(availabilityMessage)
        }
        .alert(settings.language == .spanish ? "No se pudo generar" : "Could not generate", isPresented: $showRecoveryErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(recoveryErrorMessage)
        }
        .sheet(isPresented: $showRecoveryCodeSheet, onDismiss: {
            refreshRecoveryState()
        }) {
            RecoveryCodeDisplayView(
                code: latestRecoveryCode,
                context: .regenerated
            )
            .environmentObject(settings)
        }
        .overlay {
            if isCheckingAccess {
                ProgressView(settings.language == .spanish ? "Verificando acceso..." : "Checking access...")
                    .padding(20)
                    .background(BrandPalette.surfaceRaised)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
        .onAppear {
            lockToggleDraft = settings.biometricLockEnabled
            refreshRecoveryState()
        }
    }

    private func refreshRecoveryState() {
        hasRecoveryCode = auth.hasRecoveryCodeForCurrentUser
    }

    private func generateRecoveryCode() {
        guard let code = auth.generateRecoveryCodeForCurrentUser() else {
            recoveryErrorMessage = settings.language == .spanish
                ? "No se pudo generar un nuevo código de recuperación para esta cuenta."
                : "A new recovery code could not be generated for this account."
            showRecoveryErrorAlert = true
            return
        }

        latestRecoveryCode = code
        showRecoveryCodeSheet = true
    }

    private func handleLockToggleChange(_ enabled: Bool) {
        if !enabled {
            settings.biometricLockEnabled = false
            return
        }

        let availability = AppLockService.shared.availability()
        guard availability.isAvailable else {
            lockToggleDraft = false
            availabilityMessage = availability.message ?? (
                settings.language == .spanish
                ? "Este dispositivo no tiene autenticación del sistema disponible."
                : "This device does not have system authentication available."
            )
            showAvailabilityAlert = true
            return
        }

        Task {
            await MainActor.run {
                isCheckingAccess = true
            }

            let success = await AppLockService.shared.authenticate(language: settings.language)

            await MainActor.run {
                isCheckingAccess = false
                settings.biometricLockEnabled = success
                lockToggleDraft = success
            }
        }
    }
}
