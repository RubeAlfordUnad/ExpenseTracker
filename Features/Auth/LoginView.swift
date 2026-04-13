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
    @State private var showForgotPassword = false
    @State private var showRecoveryCodeSheet = false
    @State private var generatedRecoveryCode = ""

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

                        if !isRegister {
                            HStack {
                                Spacer()

                                Button {
                                    isInputActive = false
                                    showForgotPassword = true
                                } label: {
                                    Text(settings.language == .spanish ? "¿Olvidaste tu contraseña?" : "Forgot your password?")
                                        .font(.caption.weight(.semibold))
                                        .foregroundColor(BrandPalette.primary)
                                }
                                .accessibilityIdentifier("auth.forgotPassword")
                            }
                        }
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

                footerSignature
                    .padding(.top, 12)
                    .padding(.bottom, 10)

                Spacer(minLength: 8)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            isInputActive = false
            hideKeyboard()
        }
        .sheet(isPresented: $showForgotPassword) {
            ForgotPasswordView()
                .environmentObject(auth)
                .environmentObject(settings)
        }
        .sheet(isPresented: $showRecoveryCodeSheet) {
            RecoveryCodeDisplayView(
                code: generatedRecoveryCode,
                context: .afterRegistration
            )
            .environmentObject(settings)
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

    
    private var footerSignature: some View {
        VStack(spacing: 8) {
            Capsule()
                .fill(
                    colorScheme == .dark
                    ? Color.white.opacity(0.10)
                    : Color.black.opacity(0.10)
                )
                .frame(width: 120, height: 1)

            Text("Ruben Alford · 2026")
                .font(.caption2.weight(.medium))
                .foregroundColor(
                    colorScheme == .dark
                    ? .white.opacity(0.34)
                    : .black.opacity(0.42)
                )
        }
        .frame(maxWidth: .infinity)
        .background(Color.clear)
    }
    
    private func handleAction() {
        guard !username.isEmpty, !password.isEmpty else {
            errorMsg = settings.t("login.error.complete")
            return
        }

        if isRegister {
            switch auth.registerWithRecoveryCode(username: username, password: password) {
            case .success(let recoveryCode):
                generatedRecoveryCode = recoveryCode
                showRecoveryCodeSheet = true
                errorMsg = settings.language == .spanish
                    ? "Cuenta creada. Guarda tu código de recuperación y luego inicia sesión."
                    : "Account created. Save your recovery code and then sign in."
                isRegister = false
                password = ""

            case .invalidInput:
                errorMsg = settings.t("login.error.complete")

            case .usernameExists:
                errorMsg = settings.t("login.error.exists")

            case .credentialStoreFailure, .recoveryCodeStoreFailure:
                errorMsg = settings.language == .spanish
                    ? "No se pudo crear la cuenta de forma segura en este dispositivo."
                    : "The account could not be created securely on this device."
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
