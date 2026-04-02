import SwiftUI

struct SettingsView: View {

    @EnvironmentObject var auth: AuthManager
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        List {
            Section {
                NavigationLink {
                    ProfileView()
                } label: {
                    settingRow(
                        icon: "person.crop.circle",
                        title: settings.t("settings.profile"),
                        subtitle: profileRowSubtitle
                    )
                }
                .accessibilityIdentifier("settings.profile")
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
                .accessibilityIdentifier("settings.theme")
            } header: {
                Text(settings.t("settings.section.appearance"))
            }

            Section {
                NavigationLink {
                    SecuritySettingsView()
                } label: {
                    settingRow(
                        icon: "lock.shield",
                        title: settings.securitySectionTitle,
                        subtitle: settings.language == .spanish
                        ? "Oculta montos y protege la app al volver del fondo"
                        : "Hide amounts and protect the app when returning from background"
                    )
                }
                .accessibilityIdentifier("settings.security")

                NavigationLink {
                    NotificationSettingsView()
                } label: {
                    settingRow(
                        icon: "bell.badge",
                        title: settings.t("settings.notifications"),
                        subtitle: settings.t("settings.notificationsSubtitle")
                    )
                }
                .accessibilityIdentifier("settings.notifications")

                NavigationLink {
                    LanguageSettingsView()
                } label: {
                    settingRow(
                        icon: "globe",
                        title: settings.t("settings.language"),
                        subtitle: settings.language.title
                    )
                }
                .accessibilityIdentifier("settings.language")

                NavigationLink {
                    RegionCurrencySettingsView()
                } label: {
                    settingRow(
                        icon: "dollarsign.arrow.circlepath",
                        title: settings.t("settings.regionCurrency"),
                        subtitle: "\(settings.country.flag) \(settings.country.title(for: settings.language)) · \(settings.effectiveCurrency.rawValue)"
                    )
                }
                .accessibilityIdentifier("settings.regionCurrency")

                NavigationLink {
                    ExchangeRateView()
                } label: {
                    settingRow(
                        icon: "chart.line.text.clipboard",
                        title: settings.t("settings.exchangeRate"),
                        subtitle: "\(settings.effectiveCurrency.rawValue) → \(settings.exchangeRateTargetCurrency.rawValue)"
                    )
                }
                .accessibilityIdentifier("settings.exchangeRate")
            } header: {
                Text(settings.t("settings.section.app"))
            }

            Section {
                NavigationLink {
                    BackupRestoreView()
                } label: {
                    settingRow(
                        icon: "externaldrive.badge.icloud",
                        title: settings.language == .spanish ? "Respaldo y restauración" : "Backup & restore",
                        subtitle: settings.language == .spanish
                        ? "Exporta o recupera un JSON completo de tu cuenta"
                        : "Export or recover a full JSON snapshot of your account"
                    )
                }
                .accessibilityIdentifier("settings.backup")
            } header: {
                Text(settings.language == .spanish ? "Datos" : "Data")
            }

            Section {
                NavigationLink {
                    PrivacyPolicyView()
                } label: {
                    settingRow(
                        icon: "hand.raised",
                        title: settings.t("settings.privacyPolicy"),
                        subtitle: settings.language == .spanish
                        ? "Datos locales, permisos y privacidad"
                        : "Local data, permissions and privacy"
                    )
                }
                .accessibilityIdentifier("settings.privacy")

                NavigationLink {
                    TermsView()
                } label: {
                    settingRow(
                        icon: "doc.text",
                        title: settings.t("settings.terms"),
                        subtitle: settings.language == .spanish
                        ? "Uso, límites y responsabilidades"
                        : "Use, limits and responsibilities"
                    )
                }
                .accessibilityIdentifier("settings.terms")

                if let supportEmailURL = AppMetadata.supportEmailURL {
                    Link(destination: supportEmailURL) {
                        settingRow(
                            icon: "envelope",
                            title: settings.language == .spanish ? "Soporte" : "Support",
                            subtitle: AppMetadata.supportEmail
                        )
                    }
                    .accessibilityIdentifier("settings.support")
                }

                if let publicWebsiteURL = AppMetadata.publicWebsiteURL {
                    Link(destination: publicWebsiteURL) {
                        settingRow(
                            icon: "globe",
                            title: settings.language == .spanish ? "Sitio web" : "Website",
                            subtitle: publicWebsiteURL.absoluteString
                        )
                    }
                    .accessibilityIdentifier("settings.website")
                }
            } header: {
                Text(settings.language == .spanish ? "Legal y soporte" : "Legal and support")
            }

            Section {
                settingRow(
                    icon: "info.circle",
                    title: AppMetadata.displayName,
                    subtitle: AppMetadata.versionDescription(for: settings.language)
                )
                .accessibilityIdentifier("settings.version")
            } header: {
                Text(settings.language == .spanish ? "Acerca de" : "About")
            }
        }
        .accessibilityIdentifier("settings.screen")
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

    private var profileRowSubtitle: String {
        let savedName = DataManager.shared.loadProfileDisplayName(user: auth.currentUser) ?? ""

        if !savedName.isEmpty {
            return savedName
        }

        if auth.isUsingLocalMode {
            return settings.language == .spanish ? "Modo local" : "Local mode"
        }

        return auth.currentUser.isEmpty ? settings.t("settings.profileSubtitle") : auth.currentUser
    }
}
