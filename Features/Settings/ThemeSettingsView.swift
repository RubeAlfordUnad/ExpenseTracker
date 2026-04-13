import SwiftUI

struct ThemeSettingsView: View {

    @EnvironmentObject var settings: AppSettings

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                SettingsHeroCard(
                    title: settings.t("theme.title"),
                    subtitle: heroSubtitle,
                    icon: "circle.lefthalf.filled",
                    chips: [settings.theme.title(for: settings.language)]
                )

                SettingsSectionTitleView(title: settings.language == .spanish ? "Opciones" : "Options")
                SettingsCard {
                    ForEach(Array(AppTheme.allCases.enumerated()), id: \.element.id) { index, theme in
                        Button {
                            settings.theme = theme
                        } label: {
                            SettingsChoiceTile(
                                icon: icon(for: theme),
                                title: theme.title(for: settings.language),
                                subtitle: subtitle(for: theme),
                                isSelected: settings.theme == theme
                            )
                        }
                        .buttonStyle(.plain)

                        if index < AppTheme.allCases.count - 1 {
                            SettingsDivider()
                        }
                    }
                }
            }
            .padding(20)
            .padding(.bottom, 32)
        }
        .background(Color(.systemBackground))
        .navigationTitle(settings.t("theme.title"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var heroSubtitle: String {
        settings.language == .spanish
        ? "Elige cómo quieres que se vea la app en tu dispositivo."
        : "Choose how you want the app to look on your device."
    }

    private func icon(for theme: AppTheme) -> String {
        switch theme {
        case .system: return "iphone"
        case .light: return "sun.max"
        case .dark: return "moon"
        }
    }

    private func subtitle(for theme: AppTheme) -> String {
        switch (theme, settings.language) {
        case (.system, .spanish): return "Usa automáticamente el modo del sistema"
        case (.light, .spanish): return "Mantiene la app en modo claro"
        case (.dark, .spanish): return "Mantiene la app en modo oscuro"
        case (.system, .english): return "Follow the system appearance automatically"
        case (.light, .english): return "Keep the app in light mode"
        case (.dark, .english): return "Keep the app in dark mode"
        }
    }
}
