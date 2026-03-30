import SwiftUI
import PhotosUI

struct ProfileView: View {

    @EnvironmentObject var auth: AuthManager
    @EnvironmentObject var settings: AppSettings

    @State private var selectedPhoto: PhotosPickerItem?
    @State private var profileImage: Image?

    @State private var showDeleteAccountAlert = false
    @State private var showDeleteErrorAlert = false
    @State private var deleteErrorMessage = ""

    private let profileImageChangedNotification = Notification.Name("profileImageDidChange")

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

                    Text(auth.isUsingLocalMode
                         ? (settings.language == .spanish ? "Modo local" : "Local mode")
                         : auth.currentUser
                    )
                    .font(.headline)

                    Text(
                        auth.isUsingLocalMode
                        ? (settings.language == .spanish
                           ? "Estás usando la app sin cuenta. Tus datos siguen guardados localmente en este dispositivo."
                           : "You are using the app without an account. Your data is still stored locally on this device.")
                        : (settings.language == .spanish
                           ? "Estás usando una cuenta local protegida en este dispositivo."
                           : "You are using a local account protected on this device.")
                    )
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                }

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
