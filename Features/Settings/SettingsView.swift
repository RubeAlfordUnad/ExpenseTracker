import SwiftUI

struct SettingsView: View {

    @EnvironmentObject var auth: AuthManager
    @EnvironmentObject var settings: AppSettings

    private let supportEmail = "motwd44011@outlook.com"

    var body: some View {
        List {
            Section {
                NavigationLink {
                    ProfileView()
                } label: {
                    settingRow(
                        icon: "person.crop.circle",
                        title: settings.t("settings.profile"),
                        subtitle: auth.isUsingLocalMode
                        ? (settings.language == .spanish ? "Modo local" : "Local mode")
                        : (auth.currentUser.isEmpty ? settings.t("settings.profileSubtitle") : auth.currentUser)
                    )
                }
            } header: {
                Text(settings.t("settings.section.profile"))
            }

            Section {
                NavigationLink {
                    ThemeSettingsView()
                } label: {
                    settingRow(
                        icon: "circle.lefthalf.filled",
                        title: settings.t("settings.theme"),
                        subtitle: settings.theme.title(for: settings.language)
                    )
                }
            } header: {
                Text(settings.t("settings.section.appearance"))
            }

            Section {
                NavigationLink {
                    NotificationSettingsView()
                } label: {
                    settingRow(
                        icon: "bell.badge",
                        title: settings.t("settings.notifications"),
                        subtitle: settings.t("settings.notificationsSubtitle")
                    )
                }

                NavigationLink {
                    LanguageSettingsView()
                } label: {
                    settingRow(
                        icon: "globe",
                        title: settings.t("settings.language"),
                        subtitle: settings.language.title
                    )
                }

                NavigationLink {
                    RegionCurrencySettingsView()
                } label: {
                    settingRow(
                        icon: "dollarsign.arrow.circlepath",
                        title: settings.t("settings.regionCurrency"),
                        subtitle: "\(settings.country.flag) \(settings.country.title(for: settings.language)) · \(settings.effectiveCurrency.rawValue)"
                    )
                }

                NavigationLink {
                    ExchangeRateView()
                } label: {
                    settingRow(
                        icon: "chart.line.text.clipboard",
                        title: settings.t("settings.exchangeRate"),
                        subtitle: "\(settings.effectiveCurrency.rawValue) → \(settings.exchangeRateTargetCurrency.rawValue)"
                    )
                }
            } header: {
                Text(settings.t("settings.section.app"))
            }

            Section {
                NavigationLink {
                    PrivacyPolicyView()
                } label: {
                    settingRow(
                        icon: "hand.raised",
                        title: settings.t("settings.privacyPolicy"),
                        subtitle: settings.language == .spanish ? "Datos locales y privacidad" : "Local data and privacy"
                    )
                }

                NavigationLink {
                    TermsView()
                } label: {
                    settingRow(
                        icon: "doc.text",
                        title: settings.t("settings.terms"),
                        subtitle: settings.language == .spanish ? "Uso y responsabilidades" : "Use and responsibilities"
                    )
                }

                Link(destination: URL(string: "mailto:\(supportEmail)")!) {
                    settingRow(
                        icon: "envelope",
                        title: settings.language == .spanish ? "Soporte" : "Support",
                        subtitle: supportEmail
                    )
                }
            } header: {
                Text(settings.language == .spanish ? "Legal y soporte" : "Legal and support")
            }
        }
        .navigationTitle(settings.t("settings.title"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func settingRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .foregroundColor(BrandPalette.primary)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .foregroundColor(.primary)

                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
