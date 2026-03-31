import SwiftUI

struct SecuritySettingsView: View {

    @EnvironmentObject var settings: AppSettings

    @State private var lockToggleDraft = false
    @State private var showAvailabilityAlert = false
    @State private var availabilityMessage = ""
    @State private var isCheckingAccess = false

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
        }
        .navigationTitle(settings.securityScreenTitle)
        .navigationBarTitleDisplayMode(.inline)
        .alert(settings.language == .spanish ? "Acceso no disponible" : "Access unavailable", isPresented: $showAvailabilityAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(availabilityMessage)
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
        }
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
