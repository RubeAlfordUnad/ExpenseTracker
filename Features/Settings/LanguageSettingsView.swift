import SwiftUI

struct LanguageSettingsView: View {

    @EnvironmentObject var settings: AppSettings

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                SettingsHeroCard(
                    title: settings.t("language.title"),
                    subtitle: heroSubtitle,
                    icon: "globe",
                    chips: [settings.language.title]
                )

                SettingsSectionTitleView(title: settings.language == .spanish ? "Opciones" : "Options")
                SettingsCard {
                    ForEach(Array(AppLanguage.allCases.enumerated()), id: \.element.id) { index, language in
                        Button {
                            settings.language = language
                        } label: {
                            SettingsChoiceTile(
                                icon: language == .spanish ? "text.bubble" : "captions.bubble",
                                title: language.title,
                                subtitle: subtitle(for: language),
                                isSelected: settings.language == language
                            )
                        }
                        .buttonStyle(.plain)

                        if index < AppLanguage.allCases.count - 1 {
                            SettingsDivider()
                        }
                    }
                }
            }
            .padding(20)
            .padding(.bottom, 32)
        }
        .background(Color(.systemBackground))
        .navigationTitle(settings.t("language.title"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var heroSubtitle: String {
        settings.language == .spanish
        ? "Cambia el idioma de la app y de los textos principales."
        : "Change the app language and the main interface text."
    }

    private func subtitle(for language: AppLanguage) -> String {
        switch language {
        case .spanish:
            return settings.language == .spanish ? "Interfaz completa en español" : "Full interface in Spanish"
        case .english:
            return settings.language == .spanish ? "Interfaz completa en inglés" : "Full interface in English"
        }
    }
}
