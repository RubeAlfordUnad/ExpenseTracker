import SwiftUI

struct RootView: View {

    @EnvironmentObject var auth: AuthManager
    @EnvironmentObject var settings: AppSettings
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false

    @State private var showLaunchSplash = true
    @State private var splashLogoVisible = false
    @State private var showPersistenceAlert = false
    @State private var hasScheduledPersistenceAlert = false

    private var persistenceState: PersistenceStartupState {
        PersistenceController.shared.startupState
    }

    var body: some View {
        ZStack {
            Group {
                if !hasSeenOnboarding {
                    OnboardingView()
                } else if auth.isLoggedIn {
                    MainTabView()
                } else {
                    LoginView()
                }
            }
            .opacity(showLaunchSplash ? 0 : 1)
            .animation(.easeOut(duration: 0.22), value: showLaunchSplash)

            if showLaunchSplash {
                launchSplashView
                    .transition(.opacity)
                    .zIndex(10)
            }
        }
        .onAppear {
            splashLogoVisible = false

            withAnimation(.easeOut(duration: 0.35)) {
                splashLogoVisible = true
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                withAnimation(.easeInOut(duration: 0.28)) {
                    showLaunchSplash = false
                }
            }

            guard !hasScheduledPersistenceAlert else { return }
            guard persistenceState == .inMemoryFallback else { return }

            hasScheduledPersistenceAlert = true

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.15) {
                showPersistenceAlert = true
            }
        }
        .alert(persistenceAlertTitle, isPresented: $showPersistenceAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(persistenceAlertMessage)
        }
    }

    private var persistenceAlertTitle: String {
        switch settings.language {
        case .spanish:
            return "Modo de almacenamiento temporal"
        case .english:
            return "Temporary storage mode"
        }
    }

    private var persistenceAlertMessage: String {
        switch settings.language {
        case .spanish:
            return "No se pudo abrir el almacenamiento local principal. La app seguirá funcionando con almacenamiento temporal en memoria, así que algunos cambios podrían perderse al cerrar la app. Reinicia la app y, si el problema sigue, reinstala y restaura un respaldo."
        case .english:
            return "The main local storage could not be opened. The app will keep running with temporary in-memory storage, so some changes may be lost when the app closes. Restart the app and, if the issue continues, reinstall and restore from a backup."
        }
    }

    private var launchSplashView: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            Group {
                if UIImage(named: "LoginLogo") != nil {
                    Image("LoginLogo")
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                        .frame(width: 118, height: 118)
                        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 30, style: .continuous)
                            .fill(Color.white.opacity(0.08))
                            .frame(width: 118, height: 118)

                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 40, weight: .bold))
                            .foregroundColor(BrandPalette.primary)
                    }
                }
            }
            .scaleEffect(splashLogoVisible ? 1.0 : 0.88)
            .opacity(splashLogoVisible ? 1.0 : 0.0)
        }
    }
}
