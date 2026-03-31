import SwiftUI
import PhotosUI

struct ProfileView: View {

    @EnvironmentObject var auth: AuthManager
    @EnvironmentObject var settings: AppSettings

    @State private var selectedPhoto: PhotosPickerItem?
    @State private var profileImage: Image?
    @State private var displayNameInput = ""
    @State private var savedDisplayName = ""

    @State private var showDeleteAccountAlert = false
    @State private var showDeleteErrorAlert = false
    @State private var deleteErrorMessage = ""

    private let profileImageChangedNotification = Notification.Name("profileImageDidChange")
    private let profileDisplayNameChangedNotification = Notification.Name("profileDisplayNameDidChange")
    private let displayNameLimit = 24

    private var normalizedDisplayName: String {
        String(displayNameInput
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .prefix(displayNameLimit))
    }

    private var canSaveDisplayName: Bool {
        normalizedDisplayName != savedDisplayName
    }

    private var accountLabel: String {
        auth.isUsingLocalMode
        ? (settings.language == .spanish ? "Modo local" : "Local mode")
        : auth.currentUser
    }

    private var accountHelper: String {
        auth.isUsingLocalMode
        ? (settings.language == .spanish
           ? "Estás usando la app sin cuenta. Tus datos siguen guardados localmente en este dispositivo."
           : "You are using the app without an account. Your data is still stored locally on this device.")
        : (settings.language == .spanish
           ? "Estás usando una cuenta local protegida en este dispositivo."
           : "You are using a local account protected on this device.")
    }

    private var displayNameSectionTitle: String {
        settings.language == .spanish ? "Nombre visible en el dashboard" : "Dashboard display name"
    }

    private var displayNameSectionSubtitle: String {
        settings.language == .spanish
        ? "Este nombre se usará en el saludo y en el avatar del inicio. Si lo dejas vacío, la app usará tu usuario actual."
        : "This name will be used in the greeting and avatar on the home screen. Leave it empty to use your current username."
    }

    private var displayNamePlaceholder: String {
        settings.language == .spanish ? "Ej: Rubén" : "Example: Ruben"
    }

    private var displayNameSaveTitle: String {
        settings.language == .spanish ? "Guardar nombre" : "Save name"
    }

    private var displayNameResetTitle: String {
        settings.language == .spanish ? "Usar usuario actual" : "Use current username"
    }

    private var displayNamePreviewLabel: String {
        settings.language == .spanish ? "Vista previa en el dashboard" : "Dashboard preview"
    }

    private var displayNameCountLabel: String {
        settings.language == .spanish ? "Máximo 24 caracteres" : "Maximum 24 characters"
    }

    private var dashboardNamePreview: String {
        if !normalizedDisplayName.isEmpty {
            return normalizedDisplayName
        }

        if !savedDisplayName.isEmpty {
            return savedDisplayName
        }

        return auth.isUsingLocalMode
        ? (settings.language == .spanish ? "local" : "local")
        : auth.currentUser
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 10) {
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        ZStack(alignment: .bottomTrailing) {
                            avatarView

                            Circle()
                                .fill(Color.blue)
                                .frame(width: 34, height: 34)
                                .overlay(
                                    Image(systemName: "camera.fill")
                                        .foregroundColor(.white)
                                )
                        }
                    }
                    .buttonStyle(.plain)

                    Text(accountLabel)
                        .font(.headline)

                    Text(accountHelper)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                VStack(alignment: .leading, spacing: 14) {
                    Text(displayNameSectionTitle)
                        .font(.headline)

                    Text(displayNameSectionSubtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    TextField(displayNamePlaceholder, text: $displayNameInput)
                        .textInputAutocapitalization(.words)
                        .disableAutocorrection(true)
                        .padding(12)
                        .background(BrandPalette.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(BrandPalette.stroke, lineWidth: 1)
                        )

                    HStack {
                        Text(displayNameCountLabel)
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Spacer()

                        Text("\(normalizedDisplayName.count)/\(displayNameLimit)")
                            .font(.caption.monospacedDigit())
                            .foregroundColor(.secondary)
                    }

                    HStack(spacing: 12) {
                        Button(displayNameSaveTitle) {
                            saveDisplayName()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!canSaveDisplayName)

                        if !savedDisplayName.isEmpty {
                            Button(displayNameResetTitle) {
                                resetDisplayName()
                            }
                            .buttonStyle(.bordered)
                        }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text(displayNamePreviewLabel)
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text(dashboardNamePreview)
                            .font(.subheadline.weight(.semibold))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(BrandPalette.surface)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(BrandPalette.stroke, lineWidth: 1)
                )

                Text(settings.t("profile.changePhoto"))
                    .font(.subheadline.weight(.semibold))

                Text(settings.t("profile.helper"))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                if profileImage != nil {
                    Button(role: .destructive) {
                        removePhoto()
                    } label: {
                        Text(settings.t("profile.removePhoto"))
                    }
                }

                Divider()
                    .padding(.top, 8)

                VStack(alignment: .leading, spacing: 12) {
                    Text(settings.t("profile.dangerZone"))
                        .font(.headline)
                        .foregroundColor(.red)

                    Text(
                        auth.isUsingLocalMode
                        ? (settings.language == .spanish
                           ? "Puedes borrar todos los datos locales del modo actual desde aquí."
                           : "You can erase all local data from the current mode here.")
                        : settings.t("profile.deleteAccountHelper")
                    )
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                    Button(role: .destructive) {
                        showDeleteAccountAlert = true
                    } label: {
                        Text(
                            auth.isUsingLocalMode
                            ? (settings.language == .spanish ? "Borrar datos locales" : "Erase local data")
                            : settings.t("profile.deleteAccount")
                        )
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Spacer(minLength: 24)
            }
            .padding()
        }
        .navigationTitle(settings.t("profile.title"))
        .onAppear {
            loadSavedPhoto()
            loadSavedDisplayName()
        }
        .onChange(of: selectedPhoto) { _, newItem in
            Task {
                guard let newItem,
                      let data = try? await newItem.loadTransferable(type: Data.self),
                      let uiImage = UIImage(data: data) else { return }

                profileImage = Image(uiImage: uiImage)
                DataManager.shared.saveProfileImageData(data, user: auth.currentUser)
                NotificationCenter.default.post(name: profileImageChangedNotification, object: nil)
            }
        }
        .onChange(of: displayNameInput) { _, newValue in
            let limited = String(newValue.prefix(displayNameLimit))
            if limited != newValue {
                displayNameInput = limited
            }
        }
        .alert(
            auth.isUsingLocalMode
            ? (settings.language == .spanish ? "Borrar datos locales" : "Erase local data")
            : settings.t("profile.deleteAccountTitle"),
            isPresented: $showDeleteAccountAlert
        ) {
            Button(settings.t("common.cancel"), role: .cancel) { }

            Button(
                auth.isUsingLocalMode
                ? (settings.language == .spanish ? "Borrar" : "Erase")
                : settings.t("profile.deleteAccountConfirm"),
                role: .destructive
            ) {
                deleteAccount()
            }
        } message: {
            Text(
                auth.isUsingLocalMode
                ? (settings.language == .spanish
                   ? "Se borrarán los datos locales de este dispositivo para el modo actual."
                   : "Local data for the current mode will be erased from this device.")
                : settings.t("profile.deleteAccountMessage")
            )
        }
        .alert(settings.t("profile.deleteAccountErrorTitle"), isPresented: $showDeleteErrorAlert) {
            Button(settings.t("common.done")) { }
        } message: {
            Text(deleteErrorMessage)
        }
    }

    private var avatarView: some View {
        Group {
            if let profileImage {
                profileImage
                    .resizable()
                    .scaledToFill()
                    .frame(width: 130, height: 130)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color(uiColor: .separator).opacity(0.18), lineWidth: 1)
                    )
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .frame(width: 130, height: 130)
                    .foregroundColor(.gray)
            }
        }
    }

    private func loadSavedPhoto() {
        guard let data = DataManager.shared.loadProfileImageData(user: auth.currentUser),
              let uiImage = UIImage(data: data) else {
            profileImage = nil
            return
        }

        profileImage = Image(uiImage: uiImage)
    }

    private func loadSavedDisplayName() {
        let saved = DataManager.shared.loadProfileDisplayName(user: auth.currentUser) ?? ""
        savedDisplayName = saved
        displayNameInput = saved
    }

    private func saveDisplayName() {
        let valueToSave = normalizedDisplayName.isEmpty ? nil : normalizedDisplayName
        DataManager.shared.saveProfileDisplayName(valueToSave, user: auth.currentUser)
        savedDisplayName = valueToSave ?? ""
        displayNameInput = savedDisplayName
        NotificationCenter.default.post(name: profileDisplayNameChangedNotification, object: nil)
    }

    private func resetDisplayName() {
        displayNameInput = ""
        saveDisplayName()
    }

    private func removePhoto() {
        profileImage = nil
        DataManager.shared.saveProfileImageData(nil, user: auth.currentUser)
        NotificationCenter.default.post(name: profileImageChangedNotification, object: nil)
    }

    private func deleteAccount() {
        let wasDeleted = auth.deleteCurrentAccount()

        if !wasDeleted {
            deleteErrorMessage = settings.t("profile.deleteAccountErrorMessage")
            showDeleteErrorAlert = true
        }
    }
}
