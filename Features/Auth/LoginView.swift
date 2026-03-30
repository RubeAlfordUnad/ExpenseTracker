import SwiftUI
import UIKit

struct LoginView: View {

    @EnvironmentObject var auth: AuthManager
    @EnvironmentObject var settings: AppSettings
    @Environment(\.colorScheme) var colorScheme

    @State private var username = ""
    @State private var password = ""
    @State private var isRegister = false
    @State private var errorMsg = ""
    @State private var logoVisible = false

    @FocusState private var isInputActive: Bool

    var body: some View {
        ZStack {
            LinearGradient(
                colors: colorScheme == .dark ?
                [
                    Color.black,
                    Color.black.opacity(0.94),
                    BrandPalette.primary.opacity(0.10),
                    BrandPalette.secondary.opacity(0.05)
                ]
                :
                [
                    Color.white,
                    Color(.systemGray6),
                    BrandPalette.primary.opacity(0.08),
                    BrandPalette.secondary.opacity(0.06)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 26) {
                Spacer(minLength: 28)
                    .onAppear {
                        logoVisible = true
                    }

                headerBrand

                VStack(spacing: 16) {
                    Button {
                        isInputActive = false
                        errorMsg = ""
                        auth.continueLocally()
                    } label: {
                        HStack {
                            Image(systemName: "iphone")
                            Text(settings.language == .spanish ? "Entrar sin cuenta" : "Continue without account")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(BrandPalette.primary)
                        .foregroundColor(.black)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .shadow(
                            color: BrandPalette.primary.opacity(0.22),
                            radius: 10,
                            x: 0,
                            y: 5
                        )
                    }
                    .accessibilityIdentifier("auth.continue.local")

                    Text(
                        settings.language == .spanish
                        ? "Tus datos siguen guardándose localmente."
                        : "Your data will still be stored locally."
                    )
                    .font(.caption)
                    .foregroundColor(
                        colorScheme == .dark
                        ? .white.opacity(0.58)
                        : .black.opacity(0.58)
                    )
                    .multilineTextAlignment(.center)

                    HStack {
                        Rectangle()
                            .fill((colorScheme == .dark ? Color.white : Color.black).opacity(0.12))
                            .frame(height: 1)

                        Text(settings.language == .spanish ? "o usa una cuenta local" : "or use a local account")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fixedSize()

                        Rectangle()
                            .fill((colorScheme == .dark ? Color.white : Color.black).opacity(0.12))
                            .frame(height: 1)
                    }
                    .padding(.vertical, 4)

                    HStack(spacing: 12) {
                        authModeButton(
                            title: settings.t("login.mode.login"),
                            isActive: !isRegister,
                            activeColor: BrandPalette.secondary
                        ) {
                            isRegister = false
                            errorMsg = ""
                            isInputActive = false
                        }

                        authModeButton(
                            title: settings.t("login.mode.register"),
                            isActive: isRegister,
                            activeColor: BrandPalette.primary
                        ) {
                            isRegister = true
                            errorMsg = ""
                            isInputActive = false
                        }
                    }

                    VStack(spacing: 14) {
                        inputField(
                            icon: "person.fill",
                            placeholder: settings.t("login.username"),
                            text: $username
                        )

                        secureInputField(
                            icon: "lock.fill",
                            placeholder: settings.t("login.password"),
                            text: $password
                        )
                    }

                    if !errorMsg.isEmpty {
                        Text(errorMsg)
                            .font(.caption)
                            .foregroundColor(BrandPalette.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Button {
                        isInputActive = false
                        handleAction()
                    } label: {
                        Text(isRegister ? settings.t("login.action.create") : settings.t("login.action.enter"))
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(isRegister ? BrandPalette.primary : BrandPalette.secondary)
                            .foregroundColor(.black)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .shadow(
                                color: (isRegister ? BrandPalette.primary : BrandPalette.secondary)
                                    .opacity(0.22),
                                radius: 10,
                                x: 0,
                                y: 5
                            )
                            .accessibilityIdentifier("auth.submit")
                    }

                    Text(isRegister ? settings.t("login.footer.register") : settings.t("login.footer.login"))
                        .font(.caption)
                        .foregroundColor(
                            colorScheme == .dark
                            ? .white.opacity(0.58)
                            : .black.opacity(0.58)
                        )
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)
                }
                .padding(24)
                .background(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(
                            colorScheme == .dark
                            ? Color.white.opacity(0.06)
                            : Color.white.opacity(0.92)
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(
                            colorScheme == .dark
                            ? Color.white.opacity(0.08)
                            : Color.black.opacity(0.08),
                            lineWidth: 1
                        )
                )
                .shadow(
                    color: .black.opacity(0.25),
                    radius: 18,
                    x: 0,
                    y: 10
                )
                .padding(.horizontal, 24)

                Spacer()

                VStack(spacing: 4) {
                    Divider()
                        .background(
                            colorScheme == .dark
                            ? Color.white.opacity(0.15)
                            : Color.black.opacity(0.15)
                        )
                        .padding(.horizontal, 60)

                    Text("Ruben Alford · 2026")
                        .font(.caption2)
                        .foregroundColor(
                            colorScheme == .dark
                            ? .white.opacity(0.35)
                            : .black.opacity(0.45)
                        )

                    Text(settings.t("login.appName"))
                        .font(.caption2)
                        .foregroundColor(
                            colorScheme == .dark
                            ? .white.opacity(0.25)
                            : .black.opacity(0.35)
                        )
                }
                .padding(.bottom, 10)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            isInputActive = false
            hideKeyboard()
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button(settings.t("common.done")) {
                    isInputActive = false
                    hideKeyboard()
                }
            }
        }
    }

    private var headerBrand: some View {
        VStack(spacing: 14) {
            Group {
                if UIImage(named: "LoginLogo") != nil {
                    Image("LoginLogo")
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                        .frame(width: 104, height: 104)
                        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 28, style: .continuous)
                                .stroke(BrandPalette.stroke, lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.20), radius: 10, x: 0, y: 6)
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .fill(BrandPalette.surface)
                            .frame(width: 104, height: 104)

                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(BrandPalette.secondary)
                    }
                }
            }

            Text(settings.t("login.appName"))
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundColor(colorScheme == .dark ? .white : .black)

            Text(settings.t("login.subtitle"))
                .font(.subheadline)
                .foregroundColor(
                    colorScheme == .dark
                    ? .white.opacity(0.68)
                    : .black.opacity(0.65)
                )
        }
        .scaleEffect(logoVisible ? 1 : 0.7)
        .opacity(logoVisible ? 1 : 0)
        .animation(.spring(response: 0.7, dampingFraction: 0.8), value: logoVisible)
    }

    private func handleAction() {
        guard !username.isEmpty, !password.isEmpty else {
            errorMsg = settings.t("login.error.complete")
            return
        }

        if isRegister {
            if auth.register(username: username, password: password) {
                errorMsg = settings.t("login.error.created")
                isRegister = false
                password = ""
            } else {
                errorMsg = settings.t("login.error.exists")
            }
        } else {
            if !auth.login(username: username, password: password) {
                errorMsg = settings.t("login.error.invalid")
            }
        }
    }

    private func authModeButton(title: String, isActive: Bool, activeColor: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    isActive
                    ? activeColor
                    : (colorScheme == .dark
                       ? Color.white.opacity(0.05)
                       : Color.gray.opacity(0.15))
                )
                .foregroundColor(isActive ? .black : (colorScheme == .dark ? .white : .black))
                .cornerRadius(14)
        }
        .accessibilityIdentifier(
            title == settings.t("login.mode.login")
            ? "auth.mode.login"
            : "auth.mode.register"
        )
    }

    private func inputField(icon: String, placeholder: String, text: Binding<String>) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(BrandPalette.secondary)
                .frame(width: 18)

            TextField(placeholder, text: text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .foregroundColor(colorScheme == .dark ? .white : .black)
                .focused($isInputActive)
                .accessibilityIdentifier("auth.username")
        }
        .padding()
        .background(
            colorScheme == .dark
            ? Color.white.opacity(0.07)
            : Color.gray.opacity(0.10)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func secureInputField(icon: String, placeholder: String, text: Binding<String>) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(BrandPalette.primary)
                .frame(width: 18)

            SecureField(placeholder, text: text)
                .foregroundColor(colorScheme == .dark ? .white : .black)
                .focused($isInputActive)
                .accessibilityIdentifier("auth.password")
        }
        .padding()
        .background(
            colorScheme == .dark
            ? Color.white.opacity(0.07)
            : Color.gray.opacity(0.10)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}   
